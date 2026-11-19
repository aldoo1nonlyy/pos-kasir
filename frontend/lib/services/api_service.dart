import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  String _baseUrl = 'http://127.0.0.1:5000/api';

  ApiService() {
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('base_url') ?? 'http://127.0.0.1:5000/api';
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim();
    if (_baseUrl.endsWith('/')) {
      _baseUrl = _baseUrl.substring(0, _baseUrl.length - 1);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', _baseUrl);
  }

  String get baseUrl => _baseUrl;


  // --- Health Check ---
  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Books CRUD APIs ---
  Future<List<Map<String, dynamic>>> getBooks({String? search, String? abcClass}) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (abcClass != null && abcClass.trim().isNotEmpty) {
        queryParams['abc_class'] = abcClass.trim();
      }

      final uri = Uri.parse('$_baseUrl/books').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error getBooks: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getBookByBarcode(String barcode) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/books/barcode/${Uri.encodeComponent(barcode.trim())}'));
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(res.body) as Map);
      }
    } catch (e) {
      debugPrint('Error getBookByBarcode: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> createBook(Map<String, dynamic> bookData) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/books'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bookData),
      );
      final body = json.decode(res.body);
      return {
        'success': res.statusCode == 201,
        'status': res.statusCode,
        'data': body is Map ? Map<String, dynamic>.from(body) : null,
        'error': res.statusCode != 201 ? (body['error'] ?? 'Gagal menambah buku') : null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Kesalahan jaringan: $e'};
    }
  }

  Future<Map<String, dynamic>> updateBook(int id, Map<String, dynamic> bookData) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/books/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bookData),
      );
      final body = json.decode(res.body);
      return {
        'success': res.statusCode == 200,
        'status': res.statusCode,
        'data': body is Map ? Map<String, dynamic>.from(body) : null,
        'error': res.statusCode != 200 ? (body['error'] ?? 'Gagal memperbarui buku') : null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Kesalahan jaringan: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteBook(int id) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/books/$id'));
      final body = json.decode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body is Map ? (body['message'] ?? 'Buku berhasil dihapus') : 'Buku berhasil dihapus',
        'error': res.statusCode != 200 ? (body['error'] ?? 'Gagal menghapus buku') : null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Kesalahan jaringan: $e'};
    }
  }

  // --- Checkout API ---
  Future<Map<String, dynamic>> checkout(List<Map<String, dynamic>> items) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'items': items}),
      );
      final body = json.decode(res.body);
      return {
        'success': res.statusCode == 201,
        'status': res.statusCode,
        'transaction': res.statusCode == 201 && body is Map ? Map<String, dynamic>.from(body) : null,
        'error': res.statusCode != 201 ? (body['error'] ?? 'Gagal memproses transaksi') : null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Kesalahan koneksi saat checkout: $e'};
    }
  }

  // --- Transactions API ---
  Future<List<Map<String, dynamic>>> getTransactions({
    String? status,
    String? startDate,
    String? endDate,
    String? sort,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'ALL') {
        queryParams['status'] = status;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }
      if (sort != null && sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }

      final baseUri = Uri.parse('$_baseUrl/transactions');
      final uri = queryParams.isNotEmpty
          ? baseUri.replace(queryParameters: queryParams)
          : baseUri;

      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error getTransactions: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getTransaction(int id) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/transactions/$id'));
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(res.body) as Map);
      }
    } catch (e) {
      debugPrint('Error getTransaction: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> voidTransaction(int transactionId, {String? adminPin}) async {
    try {
      final bodyData = <String, dynamic>{};
      if (adminPin != null && adminPin.trim().isNotEmpty) {
        bodyData['admin_pin'] = adminPin.trim();
      }

      final res = await http.post(
        Uri.parse('$_baseUrl/transactions/$transactionId/void'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bodyData),
      );
      final body = json.decode(res.body);

      return {
        'success': res.statusCode == 200,
        'status': res.statusCode,
        'requires_admin_pin': body is Map && body['requires_admin_pin'] == true,
        'message': body is Map ? body['message'] : null,
        'error': res.statusCode != 200 ? (body['error'] ?? 'Gagal membatalkan transaksi') : null,
        'transaction': body is Map && body['transaction'] != null
            ? Map<String, dynamic>.from(body['transaction'] as Map)
            : null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Kesalahan koneksi saat void transaksi: $e'};
    }
  }

  // --- Dynamic ABC Inventory Analysis ---
  Future<Map<String, dynamic>> getAbcAnalysis({int? days, bool apply = false}) async {
    try {
      final params = <String, String>{};
      if (days != null) params['days'] = days.toString();
      if (apply) params['apply'] = 'true';

      final uri = Uri.parse('$_baseUrl/abc-analysis').replace(queryParameters: params.isEmpty ? null : params);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(res.body) as Map);
      }
    } catch (e) {
      debugPrint('Error getAbcAnalysis: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> runAbcAnalysis({int? days, bool apply = true}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/abc-analysis/run'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'days': days, 'apply': apply}),
      );
      if (res.statusCode == 200) {
        return {
          'success': true,
          'data': Map<String, dynamic>.from(json.decode(res.body) as Map),
        };
      }
      return {'success': false, 'error': 'Gagal memperbarui kategori buku'};
    } catch (e) {
      return {'success': false, 'error': 'Kesalahan koneksi: $e'};
    }
  }

  // --- Stock Opname Alerts & Records ---
  Future<Map<String, dynamic>> getOpnameAlerts({String? abcClass, bool all = false}) async {
    try {
      final params = <String, String>{};
      if (abcClass != null && abcClass.trim().isNotEmpty) {
        params['abc_class'] = abcClass.trim();
      }
      if (all) params['all'] = 'true';

      // Endpoint mounted at /api/opname-alerts and /opname-alerts
      final uri = Uri.parse('$_baseUrl/opname-alerts').replace(queryParameters: params.isEmpty ? null : params);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(res.body) as Map);
      }
    } catch (e) {
      debugPrint('Error getOpnameAlerts: $e');
    }
    return {
      'total_alerts': 0,
      'counts_by_class': {'A': 0, 'B': 0, 'C': 0},
      'overdue_books': []
    };
  }

  Future<Map<String, dynamic>> recordOpname({
    required int bookId,
    int? actualStock,
    String? notes,
  }) async {
    try {
      final payload = <String, dynamic>{
        'book_id': bookId,
      };
      if (actualStock != null) payload['actual_stock'] = actualStock;
      if (notes != null && notes.isNotEmpty) payload['notes'] = notes;

      final res = await http.post(
        Uri.parse('$_baseUrl/opname'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final body = json.decode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body is Map ? body['message'] : null,
        'error': res.statusCode != 200 ? (body['error'] ?? 'Gagal mencatat cek stok') : null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Kesalahan koneksi saat cek stok: $e'};
    }
  }

  // --- Settings API ---
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/settings'));
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(res.body) as Map);
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> updateAdminPin({required String newPin, required String currentPin}) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/settings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'admin_pin': newPin, 'current_pin': currentPin}),
      );
      final body = json.decode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': body is Map ? body['message'] : null,
        'error': res.statusCode != 200 ? (body['error'] ?? 'Gagal memperbarui PIN') : null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Kesalahan koneksi: $e'};
    }
  }
}
