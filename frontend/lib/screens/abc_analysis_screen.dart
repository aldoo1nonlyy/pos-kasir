import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pos_provider.dart';

class AbcAnalysisScreen extends StatefulWidget {
  const AbcAnalysisScreen({super.key});

  @override
  State<AbcAnalysisScreen> createState() => _AbcAnalysisScreenState();
}

class _AbcAnalysisScreenState extends State<AbcAnalysisScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  int? selectedPeriodDays = 30; // default 30 hari

  // Filter & Sort State
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'ALL'; // ALL, A, B, C
  String _sortOrder = 'revenue_desc'; // revenue_desc, revenue_asc, qty_desc, qty_asc, title_asc, title_desc

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<PosProvider>(context, listen: false);
      provider.fetchAbcAnalysis(days: selectedPeriodDays);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getProcessedBooks(List<dynamic> rawList) {
    final query = _searchQuery.trim().toLowerCase();

    var list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).where((b) {
      final newClass = (b['new_class'] ?? b['abc_class'] ?? 'C').toString().toUpperCase();
      if (_selectedCategory != 'ALL' && newClass != _selectedCategory) {
        return false;
      }
      if (query.isNotEmpty) {
        final title = (b['title']?.toString() ?? '').toLowerCase();
        final barcode = (b['barcode']?.toString() ?? '').toLowerCase();
        if (!title.contains(query) && !barcode.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) {
      final revA = ((a['revenue'] ?? a['total_omset']) as num?)?.toDouble() ?? 0.0;
      final revB = ((b['revenue'] ?? b['total_omset']) as num?)?.toDouble() ?? 0.0;
      final qtyA = ((a['qty_sold'] ?? a['total_qty_sold'] ?? a['qty']) as num?)?.toInt() ?? 0;
      final qtyB = ((b['qty_sold'] ?? b['total_qty_sold'] ?? b['qty']) as num?)?.toInt() ?? 0;
      final titleA = (a['title']?.toString() ?? '').toLowerCase();
      final titleB = (b['title']?.toString() ?? '').toLowerCase();

      switch (_sortOrder) {
        case 'revenue_asc':
          return revA.compareTo(revB);
        case 'qty_desc':
          return qtyB.compareTo(qtyA);
        case 'qty_asc':
          return qtyA.compareTo(qtyB);
        case 'title_asc':
          return titleA.compareTo(titleB);
        case 'title_desc':
          return titleB.compareTo(titleA);
        case 'revenue_desc':
        default:
          return revB.compareTo(revA);
      }
    });

    return list;
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchCtrl.clear();
      _selectedCategory = 'ALL';
      _sortOrder = 'revenue_desc';
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final analysis = provider.abcAnalysisData;

    final totalRevenue = ((analysis?['total_revenue'] ?? analysis?['total_omset']) as num?)?.toDouble() ?? 0.0;
    final totalBooks = (analysis?['total_books_analyzed'] as num?)?.toInt() ?? 0;
    final dist = analysis?['class_distribution'] as Map? ?? {};

    int parseCount(dynamic val) {
      if (val is Map) return (val['count'] as num?)?.toInt() ?? 0;
      if (val is num) return val.toInt();
      return 0;
    }

    double parsePct(dynamic val, int count) {
      if (val is Map && val['percentage'] != null) {
        return (val['percentage'] as num?)?.toDouble() ?? 0.0;
      }
      if (totalBooks > 0) return (count / totalBooks * 100);
      return 0.0;
    }

    final countA = parseCount(dist['A']);
    final countB = parseCount(dist['B']);
    final countC = parseCount(dist['C']);
    final pctA = parsePct(dist['A'], countA);
    final pctB = parsePct(dist['B'], countB);
    final pctC = parsePct(dist['C'], countC);

    final booksDetails = ((analysis?['books'] ?? analysis?['updated_books']) as List?) ?? [];
    final processedBooks = _getProcessedBooks(booksDetails);
    final isFilterActive = _searchQuery.isNotEmpty || _selectedCategory != 'ALL' || _sortOrder != 'revenue_desc';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peringkat Buku Terlaris (Analisis ABC)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pengelompokan otomatis berdasarkan porsi omzet penjualan (Prinsip Pareto 80/20) untuk optimasi stok.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  // Period Selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: selectedPeriodDays,
                        items: const [
                          DropdownMenuItem(value: 7, child: Text('7 Hari Terakhir')),
                          DropdownMenuItem(value: 30, child: Text('30 Hari Terakhir')),
                          DropdownMenuItem(value: 90, child: Text('90 Hari Terakhir')),
                          DropdownMenuItem(value: null, child: Text('Semua Periode Penjualan')),
                        ],
                        onChanged: (days) {
                          setState(() => selectedPeriodDays = days);
                          provider.fetchAbcAnalysis(days: days);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Run Analysis Button (Admin only)
                  if (provider.isAdmin)
                    ElevatedButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  title: const Text('Terapkan Hasil Analisis ke Database?'),
                                  content: const Text(
                                    'Status peringkat (Kelas A, B, atau C) dan jadwal cek fisik pada setiap buku di database akan otomatis diperbarui sesuai omzet riil terbaru.',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                      child: const Text('Ya, Simpan Perubahan'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && context.mounted) {
                                final res = await provider.runAbcAnalysis(days: selectedPeriodDays);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? 'Analisis berhasil diterapkan!'),
                                      backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.flash_on, size: 16),
                      label: const Text('Terapkan ke Sistem'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Summary Cards (Interactive Filter)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCategoryCard(
                  categoryKey: 'A',
                  categoryLetter: 'A',
                  categoryLabel: 'Paling Laris',
                  revenueShare: 'Menyumbang 80% Penjualan',
                  bookCount: countA,
                  bookPct: pctA,
                  checkCycle: 'Cek fisik tiap 7 hari | Butuh PIN batal',
                  color: const Color(0xFFB45309),
                  bg: const Color(0xFFFEF3C7),
                  border: const Color(0xFFFDE68A),
                  isSelected: _selectedCategory == 'A',
                ),
                const SizedBox(width: 12),
                _buildCategoryCard(
                  categoryKey: 'B',
                  categoryLetter: 'B',
                  categoryLabel: 'Laris Sedang',
                  revenueShare: 'Menyumbang 15% Penjualan',
                  bookCount: countB,
                  bookPct: pctB,
                  checkCycle: 'Cek fisik tiap 30 hari',
                  color: const Color(0xFF1D4ED8),
                  bg: const Color(0xFFEFF6FF),
                  border: const Color(0xFFBFDBFE),
                  isSelected: _selectedCategory == 'B',
                ),
                const SizedBox(width: 12),
                _buildCategoryCard(
                  categoryKey: 'C',
                  categoryLetter: 'C',
                  categoryLabel: 'Kurang Laris',
                  revenueShare: 'Menyumbang 5% Penjualan',
                  bookCount: countC,
                  bookPct: pctC,
                  checkCycle: 'Cek fisik tiap 90 hari',
                  color: const Color(0xFF475569),
                  bg: const Color(0xFFF1F5F9),
                  border: const Color(0xFFCBD5E1),
                  isSelected: _selectedCategory == 'C',
                ),
                const SizedBox(width: 12),
                _buildTotalRevenueCard(totalRevenue, totalBooks, isSelected: _selectedCategory == 'ALL'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filter and Sort Bar
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
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
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
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Filter Kategori Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Semua Kategori', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'A', child: Text('Kelas A (80% Omzet)', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'B', child: Text('Kelas B (15% Omzet)', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'C', child: Text('Kelas C (5% Omzet)', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) => setState(() => _selectedCategory = val ?? 'ALL'),
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
                            DropdownMenuItem(
                              value: 'revenue_desc',
                              child: Text('Urutkan: Omzet Terbanyak (Pareto)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'revenue_asc',
                              child: Text('Urutkan: Omzet Terendah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'qty_desc',
                              child: Text('Urutkan: Qty Terjual Terbanyak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'qty_asc',
                              child: Text('Urutkan: Qty Terjual Tersedikit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'title_asc',
                              child: Text('Urutkan: Judul (A - Z)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'title_desc',
                              child: Text('Urutkan: Judul (Z - A)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          onChanged: (val) => setState(() => _sortOrder = val ?? 'revenue_desc'),
                        ),
                      ),
                    ),

                    if (isFilterActive) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFDC2626)),
                        tooltip: 'Reset Filter',
                        onPressed: _resetFilters,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menampilkan ${processedBooks.length} dari ${booksDetails.length} judul buku yang dianalisis',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Total Omzet Terfilter: ${currencyFormat.format(processedBooks.fold(0.0, (sum, b) => sum + (((b['revenue'] ?? b['total_omset']) as num?)?.toDouble() ?? 0.0)))}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Analysis Details Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('Judul Buku & Barcode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(flex: 1, child: Text('Terjual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('Total Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('Porsi Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('Akumulasi Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(flex: 1, child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: provider.isLoading && analysis == null
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : processedBooks.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFFCBD5E1)),
                                    const SizedBox(height: 12),
                                    Text(
                                      booksDetails.isEmpty
                                          ? 'Belum ada data penjualan pada rentang waktu yang dipilih.'
                                          : 'Tidak ada buku yang sesuai dengan filter.',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    if (isFilterActive)
                                      TextButton.icon(
                                        onPressed: _resetFilters,
                                        icon: const Icon(Icons.restart_alt, size: 16),
                                        label: const Text('Reset Filter & Tampilkan Semua'),
                                      ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: processedBooks.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                                itemBuilder: (context, index) {
                                  final item = processedBooks[index];
                                  final rev = ((item['revenue'] ?? item['total_omset']) as num?)?.toDouble() ?? 0.0;
                                  final revPct = (item['revenue_percentage'] as num?)?.toDouble() ?? 0.0;
                                  final cumPct = (item['cumulative_percentage'] as num?)?.toDouble() ?? 0.0;
                                  final newClass = (item['new_class'] ?? item['abc_class'] ?? 'C').toString().toUpperCase();
                                  final qty = ((item['qty_sold'] ?? item['total_qty_sold'] ?? item['qty']) as num?)?.toInt() ?? 0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['title'] ?? 'Tanpa Judul',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Barcode: ${item['barcode'] ?? '-'}',
                                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text('$qty buku', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            currencyFormat.format(rev),
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text('${revPct.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    minHeight: 6,
                                                    value: (cumPct / 100).clamp(0.0, 1.0),
                                                    backgroundColor: const Color(0xFFE2E8F0),
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      cumPct <= 80 ? const Color(0xFFF59E0B) : (cumPct <= 95 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text('${cumPct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: newClass == 'A'
                                                  ? const Color(0xFFFEF3C7)
                                                  : (newClass == 'B' ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9)),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Kategori $newClass',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: newClass == 'A'
                                                    ? const Color(0xFFB45309)
                                                    : (newClass == 'B' ? const Color(0xFF0369A1) : const Color(0xFF475569)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String categoryKey,
    required String categoryLetter,
    required String categoryLabel,
    required String revenueShare,
    required int bookCount,
    required double bookPct,
    required String checkCycle,
    required Color color,
    required Color bg,
    required Color border,
    bool isSelected = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = _selectedCategory == categoryKey ? 'ALL' : categoryKey;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? bg : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : border,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kategori $categoryLetter',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      categoryLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                revenueShare,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$bookCount',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Judul (${bookPct.toStringAsFixed(1)}% buku)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  checkCycle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRevenueCard(double totalRevenue, int totalBooks, {bool isSelected = false}) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = 'ALL';
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: Colors.white70, width: 2.0) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics_outlined, size: 16, color: Color(0xFFF59E0B)),
                      SizedBox(width: 8),
                      Text(
                        'Total Penjualan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Semua Buku',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Omzet Akumulasi Terdaftar',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  currencyFormat.format(totalRevenue),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '100% dari $totalBooks Judul Buku',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
