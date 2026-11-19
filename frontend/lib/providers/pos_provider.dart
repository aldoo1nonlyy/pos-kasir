import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class PosProvider with ChangeNotifier {
  final ApiService api = ApiService();

  // Role: 'kasir' (default Desktop) or 'admin'
  String _role = 'kasir';
  String get role => _role;
  bool get isAdmin => _role == 'admin';

  // State
  bool isLoading = false;
  String? errorMessage;
  bool isBackendConnected = false;

  // Data
  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> transactions = [];
  Map<String, dynamic> opnameAlerts = {
    'total_alerts': 0,
    'counts_by_class': {'A': 0, 'B': 0, 'C': 0},
    'overdue_books': <Map<String, dynamic>>[],
  };
  Map<String, dynamic>? abcAnalysisData;

  // Search & Filter
  String searchQuery = '';
  String selectedAbcFilter = 'ALL'; // 'ALL', 'A', 'B', 'C'

  // Cart: [{'book': Map, 'qty': int}]
  List<Map<String, dynamic>> cart = [];

  // Payment calculator
  double cashGiven = 0.0;

  PosProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _role = prefs.getString('user_role') ?? 'kasir';
    await refreshAll();
  }

  void setRole(String newRole) async {
    _role = newRole;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', newRole);
    notifyListeners();
  }

  void _setLoading(bool val) {
    isLoading = val;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    await api.setBaseUrl(url);
    await refreshAll();
  }

  String get baseUrl => api.baseUrl;

  Future<void> refreshAll() async {
    _setLoading(true);
    isBackendConnected = await api.checkHealth();
    await Future.wait([
      fetchBooks(),
      fetchTransactions(),
      fetchOpnameAlerts(),
      fetchAbcAnalysis(),
    ]);
    _setLoading(false);
  }

  // --- Books Management ---
  Future<void> fetchBooks() async {
    try {
      books = await api.getBooks(
        search: searchQuery.isNotEmpty ? searchQuery : null,
        abcClass: selectedAbcFilter != 'ALL' ? selectedAbcFilter : null,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetchBooks: $e');
    }
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    fetchBooks();
  }

  void setAbcFilter(String filter) {
    selectedAbcFilter = filter;
    fetchBooks();
  }

  // --- Fast Barcode Scanner Zero-Delay Logic ---
  Future<String?> scanAndAddToCart(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;

    // Check locally in loaded books first for immediate zero-delay response
    final localIndex = books.indexWhere((b) => b['barcode'] == trimmed);
    if (localIndex != -1) {
      final book = books[localIndex];
      return addToCart(book);
    }

    // Otherwise lookup via backend API
    final book = await api.getBookByBarcode(trimmed);
    if (book != null) {
      return addToCart(book);
    }

    return "Buku dengan barcode '$trimmed' tidak ditemukan.";
  }

  // --- Cart Operations ---
  String? addToCart(Map<String, dynamic> book, {int quantity = 1}) {
    final bookId = book['id'];
    final stock = (book['stock'] as num?)?.toInt() ?? 0;

    final index = cart.indexWhere((item) => item['book']['id'] == bookId);

    if (index != -1) {
      final currentQty = (cart[index]['qty'] as num?)?.toInt() ?? 1;
      if (currentQty + quantity > stock) {
        return "Stok tidak mencukupi untuk '${book['title']}' (Tersedia: $stock)";
      }
      cart[index]['qty'] = currentQty + quantity;
    } else {
      if (stock < quantity) {
        return "Stok '${book['title']}' habis (Tersedia: $stock)";
      }
      cart.add({
        'book': Map<String, dynamic>.from(book),
        'qty': quantity,
      });
    }

    notifyListeners();
    return null; // Success
  }

  void updateCartQty(int bookId, int newQty) {
    final index = cart.indexWhere((item) => item['book']['id'] == bookId);
    if (index != -1) {
      if (newQty <= 0) {
        cart.removeAt(index);
      } else {
        final stock = (cart[index]['book']['stock'] as num?)?.toInt() ?? 0;
        if (newQty <= stock) {
          cart[index]['qty'] = newQty;
        }
      }
      notifyListeners();
    }
  }

  void removeFromCart(int bookId) {
    cart.removeWhere((item) => item['book']['id'] == bookId);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    cashGiven = 0.0;
    notifyListeners();
  }

  double get cartTotal {
    return cart.fold<double>(0.0, (sum, item) {
      final price = (item['book']['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      return sum + (price * qty);
    });
  }

  int get cartTotalItems {
    return cart.fold<int>(0, (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 0));
  }

  double get changeDue {
    if (cashGiven >= cartTotal) {
      return cashGiven - cartTotal;
    }
    return 0.0;
  }

  void setCashGiven(double amount) {
    cashGiven = amount;
    notifyListeners();
  }

  // --- Checkout Operation ---
  Future<Map<String, dynamic>> processCheckout() async {
    if (cart.isEmpty) {
      return {'success': false, 'error': 'Keranjang belanja masih kosong.'};
    }

    _setLoading(true);

    final payloadItems = cart.map((item) => {
      'book_id': item['book']['id'],
      'qty': item['qty'],
    }).toList();

    final result = await api.checkout(payloadItems);

    if (result['success'] == true) {
      clearCart();
      await fetchBooks();
      await fetchTransactions();
      await fetchOpnameAlerts();
    }

    _setLoading(false);
    return result;
  }

  // --- Transactions & Void ---
  Future<void> fetchTransactions({
    String? status,
    String? startDate,
    String? endDate,
    String? sort,
  }) async {
    try {
      transactions = await api.getTransactions(
        status: status,
        startDate: startDate,
        endDate: endDate,
        sort: sort,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetchTransactions: $e');
    }
  }

  Future<Map<String, dynamic>> voidTransaction(int transactionId, {String? adminPin}) async {
    _setLoading(true);
    final result = await api.voidTransaction(transactionId, adminPin: adminPin);
    if (result['success'] == true) {
      await fetchBooks();
      await fetchTransactions();
      await fetchOpnameAlerts();
    }
    _setLoading(false);
    return result;
  }

  // --- Opname Alerts & Record ---
  Future<void> fetchOpnameAlerts() async {
    try {
      final res = await api.getOpnameAlerts();
      opnameAlerts = res;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetchOpnameAlerts: $e');
    }
  }

  int get totalOpnameAlerts => (opnameAlerts['total_alerts'] as num?)?.toInt() ?? 0;
  int get classAOverdueCount {
    final counts = opnameAlerts['counts_by_class'] as Map?;
    return (counts?['A'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> recordOpname({
    required int bookId,
    int? actualStock,
    String? notes,
  }) async {
    _setLoading(true);
    final result = await api.recordOpname(
      bookId: bookId,
      actualStock: actualStock,
      notes: notes,
    );
    if (result['success'] == true) {
      await fetchBooks();
      await fetchOpnameAlerts();
    }
    _setLoading(false);
    return result;
  }

  // --- Dynamic ABC Analysis ---
  Future<void> fetchAbcAnalysis({int? days}) async {
    try {
      abcAnalysisData = await api.getAbcAnalysis(days: days);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetchAbcAnalysis: $e');
    }
  }

  Future<Map<String, dynamic>> runAbcAnalysis({int? days, bool apply = true}) async {
    _setLoading(true);
    final result = await api.runAbcAnalysis(days: days, apply: apply);
    if (result['success'] == true) {
      await fetchBooks();
      await fetchAbcAnalysis(days: days);
      await fetchOpnameAlerts();
    }
    _setLoading(false);
    return result;
  }

  // --- Book Management (Create / Edit / Delete) ---
  Future<Map<String, dynamic>> createBook(Map<String, dynamic> data) async {
    _setLoading(true);
    final result = await api.createBook(data);
    if (result['success'] == true) {
      await fetchBooks();
      await fetchOpnameAlerts();
    }
    _setLoading(false);
    return result;
  }

  Future<Map<String, dynamic>> updateBook(int id, Map<String, dynamic> data) async {
    _setLoading(true);
    final result = await api.updateBook(id, data);
    if (result['success'] == true) {
      await fetchBooks();
      await fetchOpnameAlerts();
    }
    _setLoading(false);
    return result;
  }

  Future<Map<String, dynamic>> deleteBook(int id) async {
    _setLoading(true);
    final result = await api.deleteBook(id);
    if (result['success'] == true) {
      await fetchBooks();
      await fetchOpnameAlerts();
    }
    _setLoading(false);
    return result;
  }
}
