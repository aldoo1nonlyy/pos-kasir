import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'history_screen.dart';
import 'alerts_screen.dart';
import 'abc_analysis_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    PosScreen(),
    InventoryScreen(),
    HistoryScreen(),
    AlertsScreen(),
    AbcAnalysisScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final alertCount = provider.totalOpnameAlerts;
    final classACount = provider.classAOverdueCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          // Clean & Simple Minimalist Sidebar
          Container(
            width: 230,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: const Icon(Icons.menu_book, size: 20, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KASIR BUKU',
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Sistem Toko Buku',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Server Health Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: provider.isBackendConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              provider.isBackendConnected ? 'Online (Localhost)' : 'Offline',
                              style: TextStyle(
                                color: provider.isBackendConnected ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 6),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.point_of_sale_outlined,
                        label: 'Kasir Penjualan',
                        sublabel: 'Transaksi & Bayar',
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.auto_stories_outlined,
                        label: 'Katalog & Stok',
                        sublabel: 'Daftar Buku',
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.receipt_long_outlined,
                        label: 'Riwayat Transaksi',
                        sublabel: 'Struk & Pembatalan',
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.notifications_active_outlined,
                        label: 'Cek Stok Fisik',
                        sublabel: 'Jadwal Pengecekan',
                        badgeCount: alertCount,
                        badgeColor: classACount > 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                      ),
                      _buildNavItem(
                        index: 4,
                        icon: Icons.bar_chart_outlined,
                        label: 'Buku Terlaris (ABC)',
                        sublabel: 'Peringkat Penjualan',
                      ),
                    ],
                  ),
                ),

                // Bottom User & Terminal Status
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: provider.isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF2563EB),
                        child: Icon(
                          provider.isAdmin ? Icons.admin_panel_settings : Icons.person,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.isAdmin ? 'MANAJER TOKO' : 'KASIR 01',
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              provider.isAdmin ? 'Akses Penuh' : 'Kasir (Batal Butuh PIN)',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, size: 18, color: Color(0xFF64748B)),
                        tooltip: 'Pengaturan Sistem',
                        onPressed: () => _showSettingsDialog(context, provider),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main View Content
          Expanded(
            child: Stack(
              children: [
                _screens[_selectedIndex],
                if (provider.isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.2),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            SizedBox(width: 14),
                            Text(
                              'Menyinkronkan Data...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required String sublabel,
    int? badgeCount,
    Color? badgeColor,
  }) {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFFBFDBFE) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF1E293B),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        sublabel,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, PosProvider provider) {
    final urlCtrl = TextEditingController(text: provider.baseUrl);
    String selectedRole = provider.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                child: const Icon(Icons.tune, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pengaturan Sistem POS',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Koneksi REST API Server:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    hintText: 'http://127.0.0.1:5000/api',
                    prefixIcon: Icon(Icons.link, size: 20),
                    helperText: 'Desktop Kasir gunakan localhost:5000 untuk respon cepat.',
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pilih Peran Pengguna:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'kasir',
                      label: Text('Kasir'),
                      icon: Icon(Icons.point_of_sale, size: 16),
                    ),
                    ButtonSegment(
                      value: 'admin',
                      label: Text('Manajer Toko'),
                      icon: Icon(Icons.admin_panel_settings, size: 16),
                    ),
                  ],
                  selected: {selectedRole},
                  onSelectionChanged: (newVal) {
                    setDialogState(() => selectedRole = newVal.first);
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_person, size: 18, color: Color(0xFFB45309)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'PIN Manajer default: 123456\nDiperlukan saat kasir membatalkan transaksi buku terlaris (Kategori A).',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                provider.setRole(selectedRole);
                await provider.setBaseUrl(urlCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Konfigurasi berhasil disimpan!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              },
              child: const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}
