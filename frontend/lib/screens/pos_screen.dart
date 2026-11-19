import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pos_provider.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  final _cashCtrl = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  String _sortOrder = 'default';
  String _stockFilter = 'ALL';

  List<Map<String, dynamic>> _getProcessedBooks(List<Map<String, dynamic>> rawList) {
    var list = rawList.where((b) {
      final stock = (b['stock'] as num?)?.toInt() ?? 0;
      if (_stockFilter == 'available' && stock <= 0) return false;
      if (_stockFilter == 'low' && (stock <= 0 || stock >= 5)) return false;
      if (_stockFilter == 'empty' && stock > 0) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sortOrder) {
        case 'title_asc':
          return (a['title']?.toString() ?? '').toLowerCase().compareTo((b['title']?.toString() ?? '').toLowerCase());
        case 'title_desc':
          return (b['title']?.toString() ?? '').toLowerCase().compareTo((a['title']?.toString() ?? '').toLowerCase());
        case 'price_asc':
          return ((a['price'] as num?)?.toDouble() ?? 0).compareTo((b['price'] as num?)?.toDouble() ?? 0);
        case 'price_desc':
          return ((b['price'] as num?)?.toDouble() ?? 0).compareTo((a['price'] as num?)?.toDouble() ?? 0);
        case 'stock_desc':
          return ((b['stock'] as num?)?.toInt() ?? 0).compareTo((a['stock'] as num?)?.toInt() ?? 0);
        case 'stock_asc':
          return ((a['stock'] as num?)?.toInt() ?? 0).compareTo((b['stock'] as num?)?.toInt() ?? 0);
        case 'default':
        default:
          return ((a['id'] as num?)?.toInt() ?? 0).compareTo((b['id'] as num?)?.toInt() ?? 0);
      }
    });

    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _barcodeFocusNode.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  void _handleBarcodeSubmit(String value, PosProvider provider) async {
    final barcode = value.trim();
    if (barcode.isEmpty) return;

    final error = await provider.scanAndAddToCart(barcode);
    _searchCtrl.clear();
    _barcodeFocusNode.requestFocus();

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);

    return Row(
      children: [
        // ==========================================
        // LEFT: Books Catalog & Scanner
        // ==========================================
        Expanded(
          flex: 64,
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Search & Barcode Scanner Field
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _barcodeFocusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (val) => _handleBarcodeSubmit(val, provider),
                          onChanged: (val) => provider.setSearchQuery(val),
                          decoration: InputDecoration(
                            hintText: 'Pindai barcode ISBN (Tekan Enter) atau cari judul buku...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: Container(
                              margin: const EdgeInsets.only(left: 12, right: 8),
                              child: const Icon(Icons.qr_code_scanner, color: Color(0xFF2563EB), size: 22),
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_searchCtrl.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.cancel, size: 18, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      provider.setSearchQuery('');
                                    },
                                  ),
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Text(
                                    'SCANNER AKTIF',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF059669),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF0F172A), size: 20),
                        tooltip: 'Muat Ulang Katalog',
                        onPressed: () => provider.fetchBooks(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category ABC Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill('ALL', 'Semua Koleksi (${provider.books.length})', provider),
                      const SizedBox(width: 8),
                      _buildFilterPill('A', 'Kategori A - Buku Terlaris (80% Penjualan)', provider, isA: true),
                      const SizedBox(width: 8),
                      _buildFilterPill('B', 'Kategori B - Laris Sedang (15% Penjualan)', provider, isB: true),
                      const SizedBox(width: 8),
                      _buildFilterPill('C', 'Kategori C - Kurang Laris (5% Penjualan)', provider, isC: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Sort & Stock Filter Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Filter Stok
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _stockFilter,
                              isDense: true,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('Semua Stok')),
                                DropdownMenuItem(value: 'available', child: Text('Tersedia (>0)')),
                                DropdownMenuItem(value: 'low', child: Text('Menipis (<5)')),
                                DropdownMenuItem(value: 'empty', child: Text('Habis (0)')),
                              ],
                              onChanged: (val) => setState(() => _stockFilter = val ?? 'ALL'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Sort
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortOrder,
                              isDense: true,
                              icon: const Icon(Icons.swap_vert, size: 16, color: Color(0xFF0F172A)),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 'default', child: Text('Urutkan: Default (ID)')),
                                DropdownMenuItem(value: 'title_asc', child: Text('Urutkan: Judul (A - Z)')),
                                DropdownMenuItem(value: 'title_desc', child: Text('Urutkan: Judul (Z - A)')),
                                DropdownMenuItem(value: 'price_asc', child: Text('Urutkan: Harga Termurah')),
                                DropdownMenuItem(value: 'price_desc', child: Text('Urutkan: Harga Termahal')),
                                DropdownMenuItem(value: 'stock_desc', child: Text('Urutkan: Stok Terbanyak')),
                                DropdownMenuItem(value: 'stock_asc', child: Text('Urutkan: Stok Tersedikit')),
                              ],
                              onChanged: (val) => setState(() => _sortOrder = val ?? 'default'),
                            ),
                          ),
                        ),

                        if (_stockFilter != 'ALL' || _sortOrder != 'default') ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 16, color: Color(0xFFDC2626)),
                            tooltip: 'Reset Filter',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() {
                              _stockFilter = 'ALL';
                              _sortOrder = 'default';
                            }),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      () {
                        final processed = _getProcessedBooks(provider.books);
                        return 'Menampilkan ${processed.length} buku';
                      }(),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Books Grid
                Expanded(
                  child: () {
                    final processedBooks = _getProcessedBooks(provider.books);
                    if (processedBooks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(Icons.menu_book, size: 48, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tidak ada buku ditemukan',
                              style: TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Periksa ejaan judul atau ubah filter kategori.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 1050
                            ? 4
                            : (constraints.maxWidth > 750 ? 3 : 2);

                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 1.15,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: processedBooks.length,
                          itemBuilder: (context, index) {
                            final book = processedBooks[index];
                            return _buildLuxuryBookCard(book, provider);
                          },
                        );
                      },
                    );
                  }(),
                ),
              ],
            ),
          ),
        ),

        // ==========================================
        // RIGHT: Cart Terminal & Payment Engine
        // ==========================================
        Expanded(
          flex: 36,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Column(
              children: [
                // Cart Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF2563EB), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TRANSAKSI KASIR',
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                '${provider.cartTotalItems} item dalam keranjang',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (provider.cart.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => provider.clearCart(),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                          label: const Text(
                            'Kosongkan',
                            style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),

                // Cart Line Items List
                Expanded(
                  child: provider.cart.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(Icons.shopping_cart_outlined, size: 44, color: Color(0xFFCBD5E1)),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Keranjang Siap Belanja',
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Pindai barcode buku menggunakan scanner atau klik buku di katalog sebelah kiri.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          itemCount: provider.cart.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = provider.cart[index];
                            final book = item['book'] as Map<String, dynamic>;
                            final qty = (item['qty'] as num).toInt();
                            final price = (book['price'] as num).toDouble();
                            final subtotal = price * qty;
                            final abcClass = book['abc_class'] ?? 'C';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Spine Icon / ABC Stamp
                                  _buildMiniAbcBadge(abcClass),
                                  const SizedBox(width: 12),
                                  // Title & Subtotal
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book['title'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${currencyFormat.format(price)} x $qty',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Stepper Controls
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => provider.updateCartQty(book['id'], qty - 1),
                                          borderRadius: BorderRadius.circular(8),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            child: Icon(Icons.remove, size: 14, color: Color(0xFF334155)),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => provider.updateCartQty(book['id'], qty + 1),
                                          borderRadius: BorderRadius.circular(8),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            child: Icon(Icons.add, size: 14, color: Color(0xFF334155)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Line Subtotal
                                  Text(
                                    currencyFormat.format(subtotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Hapus item',
                                    onPressed: () => provider.removeFromCart(book['id']),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // ==========================================
                // BOTTOM CHECKOUT CALCULATOR
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Total Belanja Display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL TAGIHAN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Sudah termasuk PPN 11%',
                                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          Text(
                            currencyFormat.format(provider.cartTotal),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Quick Cash Presets
                      if (provider.cart.isNotEmpty) ...[
                        Row(
                          children: [
                            _buildQuickCashPill('Uang Pas', provider.cartTotal, provider),
                            const SizedBox(width: 6),
                            _buildQuickCashPill('Rp 50rb', 50000, provider),
                            const SizedBox(width: 6),
                            _buildQuickCashPill('Rp 100rb', 100000, provider),
                            const SizedBox(width: 6),
                            _buildQuickCashPill('Rp 200rb', 200000, provider),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Cash Input & Change Display
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: TextField(
                                controller: _cashCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: const InputDecoration(
                                  labelText: 'Uang Tunai Diterima',
                                  prefixText: 'Rp ',
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  final numVal = double.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
                                  provider.setCashGiven(numVal);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: provider.changeDue > 0
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: provider.changeDue > 0
                                        ? const Color(0xFFA7F3D0)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Kembalian:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    Text(
                                      currencyFormat.format(provider.changeDue),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: provider.changeDue > 0
                                            ? const Color(0xFF047857)
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // PAY NOW BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: provider.cart.isEmpty ? null : () => _doCheckout(context, provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'BAYAR & CETAK STRUK',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SIMPLE & CLEAN BOOK CARD
  // ==========================================
  Widget _buildLuxuryBookCard(Map<String, dynamic> book, PosProvider provider) {
    final stock = (book['stock'] as num?)?.toInt() ?? 0;
    final isOutOfStock = stock <= 0;
    final abcClass = (book['abc_class'] ?? 'C').toString().toUpperCase();
    final price = (book['price'] as num?)?.toDouble() ?? 0.0;
    final title = book['title'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isOutOfStock
              ? null
              : () {
                  final error = provider.addToCart(book);
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error), backgroundColor: Colors.red),
                    );
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: ABC Badge & Stock Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAbcFoilBadge(abcClass),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? const Color(0xFFFEE2E2)
                            : (stock < 5 ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOutOfStock ? 'Stok Habis' : 'Stok: $stock',
                        style: TextStyle(
                          color: isOutOfStock
                              ? const Color(0xFF991B1B)
                              : (stock < 5 ? const Color(0xFF92400E) : const Color(0xFF166534)),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ISBN: ${book['barcode'] ?? '-'}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const Spacer(),

                // Price and Add button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currencyFormat.format(price),
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? const Color(0xFFF1F5F9) : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 14,
                            color: isOutOfStock ? const Color(0xFF94A3B8) : Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Tambah',
                            style: TextStyle(
                              color: isOutOfStock ? const Color(0xFF94A3B8) : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simple & Clean ABC Badge
  Widget _buildAbcFoilBadge(String abcClass) {
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);
    String label = 'KATEGORI C';

    if (abcClass == 'A') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFF92400E);
      label = 'KATEGORI A';
    } else if (abcClass == 'B') {
      bg = const Color(0xFFDBEAFE);
      text = const Color(0xFF1E40AF);
      label = 'KATEGORI B';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildMiniAbcBadge(String abcClass) {
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);

    if (abcClass == 'A') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
    } else if (abcClass == 'B') {
      bg = const Color(0xFFE0F2FE);
      text = const Color(0xFF0369A1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        abcClass,
        style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 10),
      ),
    );
  }

  Widget _buildFilterPill(String key, String label, PosProvider provider, {bool isA = false, bool isB = false, bool isC = false}) {
    final isSelected = provider.selectedAbcFilter == key;

    Color activeColor = const Color(0xFF0F172A);
    if (isA) activeColor = const Color(0xFFD97706);
    if (isB) activeColor = const Color(0xFF2563EB);
    if (isC) activeColor = const Color(0xFF64748B);

    return InkWell(
      onTap: () => provider.setAbcFilter(key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: activeColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashPill(String title, double amount, PosProvider provider) {
    return Expanded(
      child: InkWell(
        onTap: () {
          _cashCtrl.text = amount.toStringAsFixed(0);
          provider.setCashGiven(amount);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REALISTIC THERMAL RECEIPT MODAL
  // ==========================================
  void _doCheckout(BuildContext context, PosProvider provider) async {
    final result = await provider.processCheckout();

    if (!context.mounted) return;

    if (result['success'] == true) {
      _cashCtrl.clear();
      final trx = result['transaction'] as Map<String, dynamic>;
      final items = (trx['items'] as List?) ?? [];
      final total = (trx['total_amount'] as num?)?.toDouble() ?? 0.0;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Success Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 36, color: Color(0xFF059669)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Transaksi Berhasil!',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                ),
                const Text(
                  'Stok buku otomatis terpotong pada sistem',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
                const SizedBox(height: 16),

                // Simulated Thermal Paper Receipt
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'LIBRIS BOOKSTORE INDONESIA',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                      ),
                      const Text(
                        'JL. TAMAN BUKU NO. 42, JAKARTA',
                        style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                      ),
                      const Divider(height: 16, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TRX #${trx['id']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(trx['timestamp'] ?? '-', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                      const Divider(height: 16),
                      // Line Items Table
                      ...items.map((it) {
                        final book = it['book'] as Map<String, dynamic>?;
                        final qty = it['qty'];
                        final subtotal = (it['subtotal'] as num?)?.toDouble() ?? 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${book?['title'] ?? 'Buku'} x$qty',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Text(currencyFormat.format(subtotal), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL BAYAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          Text(
                            currencyFormat.format(total),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Barcode graphic
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Center(
                          child: Text(
                            '||| | ||||| || |||| |||||| || |',
                            style: TextStyle(
                              letterSpacing: 4,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'TERIMA KASIH ATAS KUNJUNGAN ANDA',
                        style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Tutup & Transaksi Baru'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Gagal memproses transaksi'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
