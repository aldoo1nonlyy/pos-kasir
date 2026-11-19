import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pos_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final TextEditingController _searchCtrl = TextEditingController();

  String _sortOrder = 'id_asc';
  String _stockFilter = 'ALL';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
          return (a['title']?.toString() ?? '')
              .toLowerCase()
              .compareTo((b['title']?.toString() ?? '').toLowerCase());
        case 'title_desc':
          return (b['title']?.toString() ?? '')
              .toLowerCase()
              .compareTo((a['title']?.toString() ?? '').toLowerCase());
        case 'stock_asc':
          return ((a['stock'] as num?)?.toInt() ?? 0)
              .compareTo((b['stock'] as num?)?.toInt() ?? 0);
        case 'stock_desc':
          return ((b['stock'] as num?)?.toInt() ?? 0)
              .compareTo((a['stock'] as num?)?.toInt() ?? 0);
        case 'price_asc':
          return ((a['price'] as num?)?.toDouble() ?? 0)
              .compareTo((b['price'] as num?)?.toDouble() ?? 0);
        case 'price_desc':
          return ((b['price'] as num?)?.toDouble() ?? 0)
              .compareTo((a['price'] as num?)?.toDouble() ?? 0);
        case 'opname_oldest':
          final dtA = DateTime.tryParse(a['last_opname_date'] ?? '') ?? DateTime(2000);
          final dtB = DateTime.tryParse(b['last_opname_date'] ?? '') ?? DateTime(2000);
          return dtA.compareTo(dtB);
        case 'opname_newest':
          final dtA = DateTime.tryParse(a['last_opname_date'] ?? '') ?? DateTime(2000);
          final dtB = DateTime.tryParse(b['last_opname_date'] ?? '') ?? DateTime(2000);
          return dtB.compareTo(dtA);
        case 'id_desc':
          return ((b['id'] as num?)?.toInt() ?? 0)
              .compareTo((a['id'] as num?)?.toInt() ?? 0);
        case 'id_asc':
        default:
          return ((a['id'] as num?)?.toInt() ?? 0)
              .compareTo((b['id'] as num?)?.toInt() ?? 0);
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Katalog & Stok Buku',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Daftar koleksi buku, jumlah stok, dan kategori tingkat penjualan (${provider.books.length} judul terdaftar)',
                    style:
                        const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
                    tooltip: 'Segarkan',
                    onPressed: () => provider.fetchBooks(),
                  ),
                  const SizedBox(width: 8),
                  if (provider.isAdmin)
                    ElevatedButton.icon(
                      onPressed: () => _showBookFormDialog(context, provider),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah Buku Baru'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Search Input
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Cari judul buku atau barcode ISBN...',
                          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                          suffixIcon: provider.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    provider.setSearchQuery('');
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        onChanged: (val) => provider.setSearchQuery(val),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Filter Kategori ABC
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: provider.selectedAbcFilter,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Semua Kategori', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'A', child: Text('Kelas A (Terlaris)', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'B', child: Text('Kelas B (Sedang)', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'C', child: Text('Kelas C (Rendah)', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) => provider.setAbcFilter(val ?? 'ALL'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Filter Status Stok
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _stockFilter,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Semua Stok', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'available', child: Text('Stok Tersedia (>0)', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'low', child: Text('Stok Menipis (<5)', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'empty', child: Text('Stok Habis (0)', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) => setState(() => _stockFilter = val ?? 'ALL'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Sort Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortOrder,
                          icon: const Icon(Icons.swap_vert, size: 18, color: Color(0xFF0F172A)),
                          items: const [
                            DropdownMenuItem(value: 'id_asc', child: Text('Urutkan: ID Buku (Default)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'title_asc', child: Text('Urutkan: Judul (A - Z)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'title_desc', child: Text('Urutkan: Judul (Z - A)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'stock_asc', child: Text('Urutkan: Stok Tersedikit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'stock_desc', child: Text('Urutkan: Stok Terbanyak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'price_asc', child: Text('Urutkan: Harga Termurah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'price_desc', child: Text('Urutkan: Harga Termahal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'opname_oldest', child: Text('Urutkan: Cek Fisik Terlama', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'opname_newest', child: Text('Urutkan: Cek Fisik Terbaru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) => setState(() => _sortOrder = val ?? 'id_asc'),
                        ),
                      ),
                    ),

                    if (provider.searchQuery.isNotEmpty || provider.selectedAbcFilter != 'ALL' || _stockFilter != 'ALL' || _sortOrder != 'id_asc') ...[
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFDC2626)),
                        tooltip: 'Reset Filter',
                        onPressed: () {
                          _searchCtrl.clear();
                          provider.setSearchQuery('');
                          provider.setAbcFilter('ALL');
                          setState(() {
                            _stockFilter = 'ALL';
                            _sortOrder = 'id_asc';
                          });
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      () {
                        final processed = _getProcessedBooks(provider.books);
                        return 'Menampilkan ${processed.length} dari ${provider.books.length} buku terdaftar';
                      }(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      () {
                        final processed = _getProcessedBooks(provider.books);
                        final totalUnits = processed.fold(0, (sum, b) => sum + ((b['stock'] as num?)?.toInt() ?? 0));
                        return 'Total Stok Tersedia: $totalUnits unit buku';
                      }(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Inventory Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: () {
                final processedBooks = _getProcessedBooks(provider.books);
                if (processedBooks.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada buku yang sesuai dengan filter.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.separated(
                  itemCount: processedBooks.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final book = processedBooks[index];
                    final stock = (book['stock'] as num?)?.toInt() ?? 0;
                    final price = (book['price'] as num?)?.toDouble() ?? 0.0;
                    final abcClass = book['abc_class'] ?? 'C';
                    final lastOpname = book['last_opname_date'] != null
                        ? DateTime.tryParse(book['last_opname_date'])
                        : null;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              // ABC Badge
                              _buildAbcBadge(abcClass),
                              const SizedBox(width: 16),
                              // Title & Barcode
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book['title'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Barcode / ISBN: ${book['barcode'] ?? '-'}',
                                      style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              // Price
                              Expanded(
                                flex: 2,
                                child: Text(
                                  currencyFormat.format(price),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A)),
                                ),
                              ),
                              // Stock Status
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: stock <= 0
                                        ? const Color(0xFFFEF2F2)
                                        : (stock < 5
                                            ? const Color(0xFFFFFBEB)
                                            : const Color(0xFFECFDF5)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Stok: $stock',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: stock <= 0
                                          ? const Color(0xFFDC2626)
                                          : (stock < 5
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFF059669)),
                                    ),
                                  ),
                                ),
                              ),
                              // Opname Info
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Opname Terakhir:',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                    Text(
                                      lastOpname != null
                                          ? DateFormat('dd MMM yyyy')
                                              .format(lastOpname)
                                          : 'Belum pernah',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF334155)),
                                    ),
                                  ],
                                ),
                              ),
                              // Actions
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Cek Stok Button (Accessible to Kasir & Admin)
                                  ElevatedButton.icon(
                                    onPressed: () => _showOpnameDialog(
                                        context, provider, book),
                                    icon: const Icon(Icons.rule, size: 14),
                                    label: const Text('Cek Stok',
                                        style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      foregroundColor: const Color(0xFF1D4ED8),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                  if (provider.isAdmin) ...[
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 18, color: Color(0xFF2563EB)),
                                      tooltip: 'Ubah Data Buku',
                                      onPressed: () => _showBookFormDialog(
                                          context, provider,
                                          existingBook: book),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Color(0xFFDC2626)),
                                      tooltip: 'Hapus Buku',
                                      onPressed: () => _confirmDelete(
                                          context, provider, book),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
              }(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbcBadge(String abcClass) {
    Color bg;
    Color text;
    String label;

    switch (abcClass.toUpperCase()) {
      case 'A':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFF92400E);
        label = 'Kategori A';
        break;
      case 'B':
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF075985);
        label = 'Kategori B';
        break;
      case 'C':
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        label = 'Kategori C';
        break;
    }

    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: text),
        ),
      ),
    );
  }

  void _showOpnameDialog(
      BuildContext context, PosProvider provider, Map<String, dynamic> book) {
    final currentStock = (book['stock'] as num?)?.toInt() ?? 0;
    final stockCtrl = TextEditingController(text: currentStock.toString());
    final notesCtrl =
        TextEditingController(text: 'Penghitungan berkala rak buku');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fact_check,
                  color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cek Stok: ${book['title']}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Barcode: ${book['barcode']} | Kelas: ${book['abc_class']}'),
              const Divider(height: 24),
              Text(
                'Stok saat ini di sistem: $currentStock buku',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Buku Sebenarnya di Rak',
                  border: OutlineInputBorder(),
                  helperText:
                      'Stok pada sistem akan diperbarui dan tanggal cek direset.',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan Cek Stok',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(stockCtrl.text);
              if (newStock == null || newStock < 0) return;

              final result = await provider.recordOpname(
                bookId: book['id'],
                actualStock: newStock,
                notes: notesCtrl.text,
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ??
                        'Pemeriksaan stok berhasil dicatat!'),
                    backgroundColor: result['success'] == true
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Simpan Cek Stok'),
          ),
        ],
      ),
    );
  }

  void _showBookFormDialog(BuildContext context, PosProvider provider,
      {Map<String, dynamic>? existingBook}) {
    final isEdit = existingBook != null;
    final barcodeCtrl =
        TextEditingController(text: existingBook?['barcode'] ?? '');
    final titleCtrl = TextEditingController(text: existingBook?['title'] ?? '');
    final priceCtrl = TextEditingController(
        text: existingBook != null ? existingBook['price'].toString() : '');
    final stockCtrl = TextEditingController(
        text: existingBook != null ? existingBook['stock'].toString() : '0');
    String selectedClass = existingBook?['abc_class'] ?? 'C';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(isEdit ? 'Ubah Data Buku' : 'Tambah Buku Baru'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: barcodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Barcode / ISBN (Wajib Unik)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Judul Buku',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga (Rp)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stok Awal',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedClass,
                  decoration: const InputDecoration(
                    labelText: 'Kategori Penjualan (Kelarisan)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'A',
                        child: Text('Kelas A (Paling Laris - 80% Penjualan)')),
                    DropdownMenuItem(
                        value: 'B',
                        child: Text('Kelas B (Laris Sedang - 15% Penjualan)')),
                    DropdownMenuItem(
                        value: 'C',
                        child: Text('Kelas C (Kurang Laris - 5% Penjualan)')),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => selectedClass = val ?? 'C'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceCtrl.text);
                final stock = int.tryParse(stockCtrl.text);

                if (barcodeCtrl.text.trim().isEmpty ||
                    titleCtrl.text.trim().isEmpty ||
                    price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Lengkapi barcode, judul, dan harga')),
                  );
                  return;
                }

                final payload = {
                  'barcode': barcodeCtrl.text.trim(),
                  'title': titleCtrl.text.trim(),
                  'price': price,
                  'stock': stock ?? 0,
                  'abc_class': selectedClass,
                };

                final res = isEdit
                    ? await provider.updateBook(existingBook['id'], payload)
                    : await provider.createBook(payload);

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['success'] == true
                          ? 'Data buku berhasil disimpan'
                          : (res['error'] ?? 'Gagal')),
                      backgroundColor: res['success'] == true
                          ? const Color(0xFF10B981)
                          : const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, PosProvider provider, Map<String, dynamic> book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Buku?'),
        content: Text(
            "Apakah Anda yakin ingin menghapus '${book['title']}' dari inventori?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await provider.deleteBook(book['id']);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? res['error'] ?? 'Selesai'),
                    backgroundColor: res['success'] == true
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
