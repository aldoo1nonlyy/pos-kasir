import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pos_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'ALL'; // ALL, A, B, C
  String _sortOrder = 'overdue_desc'; // overdue_desc, overdue_asc, title_asc, title_desc, stock_asc, stock_desc

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getProcessedOverdueBooks(List<dynamic> rawList) {
    final query = _searchQuery.trim().toLowerCase();

    var list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).where((b) {
      final abc = (b['abc_class']?.toString() ?? 'C').toUpperCase();
      if (_selectedCategory != 'ALL' && abc != _selectedCategory) {
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
      switch (_sortOrder) {
        case 'overdue_asc':
          return ((a['days_overdue'] as num?)?.toInt() ?? 0)
              .compareTo((b['days_overdue'] as num?)?.toInt() ?? 0);
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
        case 'overdue_desc':
        default:
          return ((b['days_overdue'] as num?)?.toInt() ?? 0)
              .compareTo((a['days_overdue'] as num?)?.toInt() ?? 0);
      }
    });

    return list;
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchCtrl.clear();
      _selectedCategory = 'ALL';
      _sortOrder = 'overdue_desc';
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final alertsData = provider.opnameAlerts;
    final totalAlerts = (alertsData['total_alerts'] as num?)?.toInt() ?? 0;
    final counts = alertsData['counts_by_class'] as Map? ?? {};
    final overdueBooks = (alertsData['overdue_books'] as List?) ?? [];

    final countA = counts['A'] ?? 0;
    final countB = counts['B'] ?? 0;
    final countC = counts['C'] ?? 0;

    final processedList = _getProcessedOverdueBooks(overdueBooks);
    final isFilterActive = _searchQuery.isNotEmpty || _selectedCategory != 'ALL' || _sortOrder != 'overdue_desc';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peringatan Jadwal Cek Stok Fisik',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Jadwal Pengecekan Rutin: Buku Terlaris (Tiap 7 Hari), Penjualan Sedang (Tiap 30 Hari), Penjualan Rendah (Tiap 90 Hari)',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
                tooltip: 'Segarkan Data',
                onPressed: () => provider.fetchOpnameAlerts(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stat Cards Summary (Responsive & Clickable Filter)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 800;

              final cardA = _buildStatCard(
                categoryKey: 'A',
                title: 'Kelas A (Paling Laris)',
                count: countA,
                subtitle: 'Tiap 7 hari - 80% Penjualan',
                color: const Color(0xFFDC2626),
                bg: const Color(0xFFFEF2F2),
                border: const Color(0xFFFECACA),
                isSelected: _selectedCategory == 'A',
              );

              final cardB = _buildStatCard(
                categoryKey: 'B',
                title: 'Kelas B (Laris Sedang)',
                count: countB,
                subtitle: 'Tiap 30 hari - 15% Penjualan',
                color: const Color(0xFFD97706),
                bg: const Color(0xFFFFFBEB),
                border: const Color(0xFFFDE68A),
                isSelected: _selectedCategory == 'B',
              );

              final cardC = _buildStatCard(
                categoryKey: 'C',
                title: 'Kelas C (Kurang Laris)',
                count: countC,
                subtitle: 'Tiap 90 hari - 5% Penjualan',
                color: const Color(0xFF2563EB),
                bg: const Color(0xFFEFF6FF),
                border: const Color(0xFFBFDBFE),
                isSelected: _selectedCategory == 'C',
              );

              final cardTotal = _buildTotalAlertCard(totalAlerts, isSelected: _selectedCategory == 'ALL');

              if (isCompact) {
                return Column(
                  children: [
                    Row(children: [cardA, const SizedBox(width: 12), cardB]),
                    const SizedBox(height: 12),
                    Row(children: [cardC, const SizedBox(width: 12), cardTotal]),
                  ],
                );
              }

              return Row(
                children: [
                  cardA,
                  const SizedBox(width: 12),
                  cardB,
                  const SizedBox(width: 12),
                  cardC,
                  const SizedBox(width: 12),
                  cardTotal,
                ],
              );
            },
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
                            DropdownMenuItem(value: 'A', child: Text('Kelas A (Wajib 7 Hari)', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'B', child: Text('Kelas B (Wajib 30 Hari)', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'C', child: Text('Kelas C (Wajib 90 Hari)', style: TextStyle(fontSize: 12))),
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
                              value: 'overdue_desc',
                              child: Text('Urutkan: Keterlambatan Terlama (Default)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'overdue_asc',
                              child: Text('Urutkan: Keterlambatan Terpendek', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'title_asc',
                              child: Text('Urutkan: Judul (A - Z)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'title_desc',
                              child: Text('Urutkan: Judul (Z - A)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'stock_asc',
                              child: Text('Urutkan: Stok Tersedikit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'stock_desc',
                              child: Text('Urutkan: Stok Terbanyak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          onChanged: (val) => setState(() => _sortOrder = val ?? 'overdue_desc'),
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
                      'Menampilkan ${processedList.length} dari $totalAlerts buku yang jatuh tempo pemeriksaan fisik',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    if (_selectedCategory != 'ALL')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          'Filter Aktif: Kelas $_selectedCategory',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Overdue Books List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: processedList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              color: Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified, size: 48, color: Color(0xFF059669)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            overdueBooks.isEmpty
                                ? 'Semua Stok Sudah Selesai Diperiksa'
                                : 'Tidak ada buku yang sesuai dengan filter',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 6),
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
                      padding: const EdgeInsets.all(16),
                      itemCount: processedList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final book = processedList[index];
                        final abcClass = book['abc_class'] ?? 'C';
                        final daysOverdue = (book['days_overdue'] as num?)?.toInt() ?? 0;
                        final cycleDays = (book['cycle_days'] as num?)?.toInt() ?? 90;
                        final lastDate = book['last_opname_date'] != null
                            ? DateTime.tryParse(book['last_opname_date'])
                            : null;
                        final isClassA = abcClass == 'A';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isClassA ? const Color(0xFFFEF2F2).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isClassA ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                              width: isClassA ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Book Info
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isClassA ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Kelas $abcClass',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            book['title'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Barcode: ${book['barcode']} | Stok di Sistem: ${book['stock']} buku',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),

                              // Overdue Days Badge
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Terlambat $daysOverdue hari (Jadwal tiap $cycleDays hari)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: isClassA ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Terakhir dicek: ${lastDate != null ? DateFormat('dd MMM yyyy').format(lastDate) : 'Belum pernah'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),

                              // Selesaikan Opname Button
                              ElevatedButton(
                                onPressed: () => _showQuickOpnameDialog(context, provider, book),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                child: const Text('Catat Stok Fisik'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String categoryKey,
    required String title,
    required int count,
    required String subtitle,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAlertCard(int totalAlerts, {bool isSelected = false}) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = 'ALL';
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: Colors.white70, width: 2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Total Perlu Dicek',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalAlerts',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 2),
              const Text(
                'Jatuh tempo pemeriksaan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickOpnameDialog(BuildContext context, PosProvider provider, Map<String, dynamic> book) {
    final currentStock = (book['stock'] as num?)?.toInt() ?? 0;
    final stockCtrl = TextEditingController(text: currentStock.toString());
    final notesCtrl = TextEditingController(text: 'Penyesuaian stok fisik');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fact_check, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catat Stok Fisik (Opname)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    book['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kategori: Kelas ${book['abc_class']} | Jadwal Cek: Tiap ${book['cycle_days']} Hari'),
              const Divider(height: 20),
              Text('Stok saat ini di sistem: $currentStock buku', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Stok Sebenarnya di Rak',
                  border: OutlineInputBorder(),
                  helperText: 'Stok pada sistem akan disesuaikan dan tanggal cek diperbarui.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan Petugas',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(stockCtrl.text);
              if (newStock == null || newStock < 0) return;

              final res = await provider.recordOpname(
                bookId: book['book_id'] ?? book['id'],
                actualStock: newStock,
                notes: notesCtrl.text,
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Pemeriksaan stok berhasil disimpan!'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan Hasil Stok Fisik'),
          ),
        ],
      ),
    );
  }
}
