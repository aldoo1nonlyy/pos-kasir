import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pos_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final TextEditingController _searchCtrl = TextEditingController();

  // Filter & Sort State
  String _searchQuery = '';
  String _dateFilterType = 'ALL'; // ALL, TODAY, LAST_7, LAST_30, THIS_MONTH, CUSTOM
  DateTimeRange? _customDateRange;
  String _sortOrder = 'desc'; // 'desc' (Terbaru) or 'asc' (Terlama)
  String _selectedStatus = 'ALL'; // ALL, completed, voided

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterAndSortTransactions(List<Map<String, dynamic>> rawList) {
    final now = DateTime.now();
    final query = _searchQuery.trim().toLowerCase();

    final filtered = rawList.where((trx) {
      // 1. Status Filter
      final status = (trx['status']?.toString() ?? '').toLowerCase();
      if (_selectedStatus != 'ALL' && status != _selectedStatus) {
        return false;
      }

      // 2. Parse Timestamp
      DateTime? dt;
      try {
        if (trx['timestamp'] != null) {
          dt = DateTime.parse(trx['timestamp'].toString().replaceFirst(' ', 'T'));
        }
      } catch (_) {}

      // 3. Date Filter
      if (dt != null) {
        if (_dateFilterType == 'TODAY') {
          if (dt.year != now.year || dt.month != now.month || dt.day != now.day) {
            return false;
          }
        } else if (_dateFilterType == 'LAST_7') {
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          if (dt.isBefore(sevenDaysAgo)) {
            return false;
          }
        } else if (_dateFilterType == 'LAST_30') {
          final thirtyDaysAgo = now.subtract(const Duration(days: 30));
          if (dt.isBefore(thirtyDaysAgo)) {
            return false;
          }
        } else if (_dateFilterType == 'THIS_MONTH') {
          if (dt.year != now.year || dt.month != now.month) {
            return false;
          }
        } else if (_dateFilterType == 'CUSTOM' && _customDateRange != null) {
          final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
          if (dt.isBefore(start) || dt.isAfter(end)) {
            return false;
          }
        }
      }

      // 4. Search Filter
      if (query.isNotEmpty) {
        final trxId = (trx['id']?.toString() ?? '').toLowerCase();
        if (trxId.contains(query) || '#$trxId'.contains(query)) {
          return true;
        }
        final items = (trx['items'] as List?) ?? [];
        final hasMatchedBook = items.any((it) {
          final book = it['book'] as Map<String, dynamic>?;
          final title = (book?['title']?.toString() ?? '').toLowerCase();
          final barcode = (book?['barcode']?.toString() ?? '').toLowerCase();
          return title.contains(query) || barcode.contains(query);
        });
        if (!hasMatchedBook) {
          return false;
        }
      }

      return true;
    }).toList();

    // 5. Date Sort
    filtered.sort((a, b) {
      DateTime? dtA;
      DateTime? dtB;
      try {
        if (a['timestamp'] != null) {
          dtA = DateTime.parse(a['timestamp'].toString().replaceFirst(' ', 'T'));
        }
      } catch (_) {}
      try {
        if (b['timestamp'] != null) {
          dtB = DateTime.parse(b['timestamp'].toString().replaceFirst(' ', 'T'));
        }
      } catch (_) {}

      final timeA = dtA ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = dtB ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (_sortOrder == 'asc') {
        return timeA.compareTo(timeB);
      } else {
        return timeB.compareTo(timeA);
      }
    });

    return filtered;
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchCtrl.clear();
      _dateFilterType = 'ALL';
      _customDateRange = null;
      _selectedStatus = 'ALL';
      _sortOrder = 'desc';
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final filteredTransactions = _filterAndSortTransactions(provider.transactions);

    final completedCount = filteredTransactions.where((t) => (t['status']?.toString() ?? '').toLowerCase() != 'voided').length;
    final voidedCount = filteredTransactions.where((t) => (t['status']?.toString() ?? '').toLowerCase() == 'voided').length;
    final totalOmzet = filteredTransactions
        .where((t) => (t['status']?.toString() ?? '').toLowerCase() != 'voided')
        .fold(0.0, (sum, t) => sum + ((t['total_amount'] as num?)?.toDouble() ?? 0.0));

    final isFilterActive = _searchQuery.isNotEmpty ||
        _dateFilterType != 'ALL' ||
        _selectedStatus != 'ALL' ||
        _sortOrder != 'desc';

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
                    'Riwayat Transaksi Penjualan',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Daftar transaksi penjualan, cetak struk, dan pembatalan transaksi dengan PIN untuk buku terlaris.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
                tooltip: 'Segarkan Data Transaksi',
                onPressed: () => provider.fetchTransactions(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Filter & Sorting Bar
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
                          hintText: 'Cari ID Transaksi (#123) atau Judul Buku...',
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

                    // Filter Tanggal Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _dateFilterType,
                          icon: const Icon(Icons.calendar_month, size: 18, color: Color(0xFF2563EB)),
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Semua Tanggal', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'TODAY', child: Text('Hari Ini', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'LAST_7', child: Text('7 Hari Terakhir', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'LAST_30', child: Text('30 Hari Terakhir', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'THIS_MONTH', child: Text('Bulan Ini', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'CUSTOM', child: Text('Pilih Rentang...', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) async {
                            if (val == 'CUSTOM') {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                                initialDateRange: _customDateRange ??
                                    DateTimeRange(
                                      start: DateTime(2026, 9, 1),
                                      end: DateTime(2026, 10, 31),
                                    ),
                              );
                              if (picked != null) {
                                setState(() {
                                  _customDateRange = picked;
                                  _dateFilterType = 'CUSTOM';
                                });
                              }
                            } else {
                              setState(() {
                                _dateFilterType = val ?? 'ALL';
                                if (val != 'CUSTOM') _customDateRange = null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Sort Tanggal Dropdown
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
                              value: 'desc',
                              child: Text('Tanggal: Terbaru ke Terlama', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            DropdownMenuItem(
                              value: 'asc',
                              child: Text('Tanggal: Terlama ke Terbaru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          onChanged: (val) => setState(() => _sortOrder = val ?? 'desc'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Status Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Semua Status', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'completed', child: Text('Lunas / Selesai', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'voided', child: Text('Dibatalkan', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) => setState(() => _selectedStatus = val ?? 'ALL'),
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

                // Active Custom Date Range Indicator & Summary
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (_dateFilterType == 'CUSTOM' && _customDateRange != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Rentang: ${DateFormat('dd MMM yyyy').format(_customDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_customDateRange!.end)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => setState(() {
                                    _dateFilterType = 'ALL';
                                    _customDateRange = null;
                                  }),
                                  child: const Icon(Icons.close, size: 14, color: Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          'Menampilkan ${filteredTransactions.length} transaksi ($completedCount Selesai, $voidedCount Dibatalkan)',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      'Total Omzet Terpilih: ${currencyFormat.format(totalOmzet)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Transaction Cards List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: filteredTransactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          const Text(
                            'Tidak ada transaksi yang sesuai dengan filter',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
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
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredTransactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final trx = filteredTransactions[index];
                        final isVoided = (trx['status']?.toString() ?? '').toLowerCase() == 'voided';
                        final totalAmount = (trx['total_amount'] as num?)?.toDouble() ?? 0.0;
                        final items = (trx['items'] as List?) ?? [];
                        final hasClassA = items.any((it) => it['book']?['abc_class'] == 'A');

                        DateTime? dt;
                        try {
                          if (trx['timestamp'] != null) {
                            dt = DateTime.parse(trx['timestamp'].toString().replaceFirst(' ', 'T'));
                          }
                        } catch (_) {}
                        final dateStr = dt != null
                            ? DateFormat('dd MMM yyyy, HH:mm:ss').format(dt)
                            : (trx['timestamp']?.toString() ?? '-');

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: isVoided ? const Color(0xFFFEF2F2).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isVoided ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Status Badge Container
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isVoided ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isVoided ? Icons.close : Icons.check,
                                  color: isVoided ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Info Title & Items Count
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'TRANSAKSI #${trx['id']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            decoration: isVoided ? TextDecoration.lineThrough : null,
                                            color: isVoided ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Class A Protected Pill
                                        if (hasClassA && !isVoided)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFFDE68A)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.shield, size: 12, color: Color(0xFFB45309)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Buku Terlaris (Batal Butuh PIN)',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFB45309),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$dateStr | ${items.length} jenis buku dibeli',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),

                              // Amount
                              Expanded(
                                flex: 3,
                                child: Text(
                                  currencyFormat.format(totalAmount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    decoration: isVoided ? TextDecoration.lineThrough : null,
                                    color: isVoided ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),

                              // Action Buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Detail Struk Button
                                  OutlinedButton.icon(
                                    onPressed: () => _showReceiptDialog(context, trx),
                                    icon: const Icon(Icons.receipt, size: 14),
                                    label: const Text('Struk', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Void Button
                                  if (!isVoided)
                                    ElevatedButton(
                                      onPressed: () => _handleVoidClick(context, provider, trx),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFEE2E2),
                                        foregroundColor: const Color(0xFFDC2626),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('BATALKAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  if (isVoided)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'DIBATALKAN',
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
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

  void _handleVoidClick(BuildContext context, PosProvider provider, Map<String, dynamic> trx) {
    final items = (trx['items'] as List?) ?? [];
    final hasClassA = items.any((it) => it['book']?['abc_class'] == 'A');
    final classABooks = items
        .where((it) => it['book']?['abc_class'] == 'A')
        .map((it) => (it['book']?['title'] ?? '').toString())
        .toList();

    if (hasClassA) {
      _showAdminPinVoidDialog(context, provider, trx['id'], classABooks);
    } else {
      _showStandardVoidConfirmDialog(context, provider, trx['id']);
    }
  }

  void _showStandardVoidConfirmDialog(BuildContext context, PosProvider provider, int trxId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Batalkan Transaksi #$trxId?'),
        content: const Text(
          'Transaksi ini memuat buku Kategori B atau C. Seluruh stok yang terjual akan otomatis dikembalikan ke toko.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await provider.voidTransaction(trxId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? res['error'] ?? 'Selesai'),
                    backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Ya, Batalkan & Kembalikan Stok'),
          ),
        ],
      ),
    );
  }

  void _showAdminPinVoidDialog(
    BuildContext context,
    PosProvider provider,
    int trxId,
    List<String> classABooks,
  ) {
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'PIN Manajer (Buku Terlaris)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KEAMANAN BUKU KELAS A (TERLARIS):',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Transaksi #$trxId memuat buku terlaris (Kategori A): ${classABooks.join(', ')}.\nPembatalan transaksi buku terlaris memerlukan otorisasi PIN Manajer Toko (default: 123456).',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Masukkan PIN Manajer Toko',
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                  helperText: 'Stok akan dikembalikan setelah PIN valid.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN Manajer wajib diisi')),
                );
                return;
              }

              final res = await provider.voidTransaction(trxId, adminPin: pin);
              if (ctx.mounted) Navigator.pop(ctx);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? res['error'] ?? 'Selesai'),
                    backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Konfirmasi & Batalkan Transaksi'),
          ),
        ],
      ),
    );
  }

  void _showReceiptDialog(BuildContext context, Map<String, dynamic> trx) {
    final items = (trx['items'] as List?) ?? [];
    final total = (trx['total_amount'] as num?)?.toDouble() ?? 0.0;
    final isVoided = (trx['status']?.toString() ?? '').toLowerCase() == 'voided';

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
              const Text(
                'LIBRIS BOOKSTORE INDONESIA',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
              ),
              const Text('RETAIL ERP & INVENTORY MANAGEMENT', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TRX #${trx['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isVoided ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isVoided ? 'DIBATALKAN' : 'LUNAS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isVoided ? const Color(0xFFDC2626) : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Waktu Transaksi:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  Text(trx['timestamp'] ?? '-', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              const Divider(height: 20),
              // Line Items
              ...items.map((it) {
                final book = it['book'] as Map<String, dynamic>?;
                final qty = it['qty'];
                final subtotal = (it['subtotal'] as num?)?.toDouble() ?? 0.0;
                final abc = book?['abc_class'] ?? 'C';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${book?['title'] ?? 'Buku'} (Kelas $abc) x$qty',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Text(currencyFormat.format(subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL TAGIHAN:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  Text(
                    currencyFormat.format(total),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Barcode Graphic
              Container(
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Center(
                  child: Text(
                    '||| |||| || ||| |||||| || |',
                    style: TextStyle(letterSpacing: 4, color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
            child: const Text('Tutup Struk'),
          ),
        ],
      ),
    );
  }
}
