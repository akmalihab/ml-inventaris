import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import 'rooms_screen.dart';
import 'maintenance_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _roomSummaries = [];
  List<Map<String, dynamic>> _predictions = [];
  List<Map<String, dynamic>> _tasks = [];

  String _chartView = 'ruangan'; // 'ruangan' | 'kategori'

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _supabase.getRoomSummaries(),
        _supabase.getAllPredictions(),
        _supabase.getMaintenanceTasks(),
      ]);

      if (mounted) {
        setState(() {
          _roomSummaries = results[0];
          _predictions = results[1];
          _tasks = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data dashboard: $e';
          _isLoading = false;
        });
      }
    }
  }

  // --- Perhitungan Metrik Global ---
  int get _totalAset => _roomSummaries.fold<int>(0, (sum, r) => sum + ((r['total'] as num?)?.toInt() ?? 0));
  int get _totalPerlu => _roomSummaries.fold<int>(0, (sum, r) => sum + ((r['perlu'] as num?)?.toInt() ?? 0));
  int get _totalTinggi => _roomSummaries.fold<int>(0, (sum, r) => sum + ((r['tinggi'] as num?)?.toInt() ?? 0));
  int get _totalBaik => (_totalAset - _totalPerlu).clamp(0, _totalAset);

  // --- Perhitungan Kategori ---
  List<Map<String, dynamic>> get _categoryStats {
    final Map<String, Map<String, int>> map = {};
    for (final p in _predictions) {
      final inv = p['inventories'] as Map<String, dynamic>?;
      final kat = inv?['kategori'] as String? ?? 'Lainnya';
      if (!map.containsKey(kat)) {
        map[kat] = {'total': 0, 'perlu': 0, 'tinggi': 0, 'baik': 0};
      }
      map[kat]!['total'] = map[kat]!['total']! + 1;

      final isPerlu = p['koreksi_petugas'] == 1 || (p['koreksi_petugas'] == null && p['label_biner'] == 1);
      if (isPerlu) {
        map[kat]!['perlu'] = map[kat]!['perlu']! + 1;
        if (p['prioritas'] == 'Tinggi') {
          map[kat]!['tinggi'] = map[kat]!['tinggi']! + 1;
        }
      } else {
        map[kat]!['baik'] = map[kat]!['baik']! + 1;
      }
    }

    final list = map.entries.map((e) {
      final t = e.value['total']!;
      final p = e.value['perlu']!;
      return {
        'label': e.key,
        'total': t,
        'perlu': p,
        'tinggi': e.value['tinggi']!,
        'baik': e.value['baik']!,
        'ratio': t > 0 ? (p / t) * 100 : 0.0,
      };
    }).toList();

    list.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    return list;
  }

  // --- Reminders Keputusan Bisnis ---
  List<Map<String, dynamic>> get _businessReminders {
    final reminders = <Map<String, dynamic>>[];

    // 1. Alokasi Anggaran Suku Cadang & Aset Kritis
    final criticalItems = _predictions.where(
      (p) => p['prioritas'] == 'Tinggi' && p['koreksi_petugas'] != 0,
    ).toList();

    final totalNilaiKritis = criticalItems.fold<num>(
      0,
      (sum, p) => sum + ((p['inventories']?['harga'] as num?) ?? 0),
    );

    if (criticalItems.isNotEmpty) {
      reminders.add({
        'id': 'anggaran',
        'level': 'danger',
        'tag': 'Alokasi Anggaran',
        'title': '${criticalItems.length} Aset Kritis Butuh Tindakan Segera',
        'desc': 'Total taksiran nilai aset berisiko tinggi ${_currencyFormat.format(totalNilaiKritis)}. Direkomendasikan segera alokasikan anggaran darurat perbaikan atau suku cadang.',
        'actionText': 'Buka Antrean Tugas',
        'targetTab': 3, // MaintenanceScreen
      });
    }

    // 2. Kategori dengan Rasio Kerusakan Tertinggi
    final catList = [..._categoryStats];
    catList.sort((a, b) => (b['ratio'] as double).compareTo(a['ratio'] as double));
    if (catList.isNotEmpty && (catList.first['perlu'] as int) > 0) {
      final c = catList.first;
      reminders.add({
        'id': 'kategori',
        'level': 'warning',
        'tag': 'Fokus Kategori',
        'title': 'Kerusakan Terpusat pada Kategori ${c['label']}',
        'desc': '${c['perlu']} dari ${c['total']} unit (${(c['ratio'] as double).toStringAsFixed(0)}%) terprediksi butuh pemeliharaan. Jadwalkan inspeksi teknis khusus perangkat ${c['label'].toString().toLowerCase()}.',
        'actionText': 'Periksa Ruangan',
        'targetTab': 2, // RoomsScreen
      });
    }

    // 3. Ruangan dengan Beban Pemeliharaan Berat (>= 50%)
    final heavyRooms = _roomSummaries.where((r) {
      final t = (r['total'] as num?)?.toInt() ?? 0;
      final p = (r['perlu'] as num?)?.toInt() ?? 0;
      return t > 0 && (p / t) >= 0.5;
    }).toList();

    if (heavyRooms.isNotEmpty) {
      final names = heavyRooms.take(3).map((r) => r['nama'] as String).join(', ');
      final suffix = heavyRooms.length > 3 ? ' dkk.' : '';
      reminders.add({
        'id': 'ruangan',
        'level': 'danger',
        'tag': 'Audit Ruangan',
        'title': '${heavyRooms.length} Ruang Rawat Inap Beban Kerusakan ≥ 50%',
        'desc': 'Ruang $names$suffix memiliki beban pemeliharaan tinggi. Disarankan rotasi dan inspeksi fasilitas ruangan agar layanan pasien tidak terganggu.',
        'actionText': 'Lihat Data Ruangan',
        'targetTab': 2,
      });
    }

    // 4. Tiket Tugas Masih Menunggu Antrean
    final pendingTasks = _tasks.where((t) => t['status'] == 'Antre').toList();
    if (pendingTasks.isNotEmpty) {
      reminders.add({
        'id': 'tugas',
        'level': 'info',
        'tag': 'SLA Teknisi',
        'title': '${pendingTasks.length} Tiket Perbaikan Belum Dikerjakan',
        'desc': 'Terdapat backlog perbaikan pada antrean teknisi. Segera koordinasikan dengan teknisi internal RSD dr. Soebandi agar tidak menumpuk.',
        'actionText': 'Kelola Antrean',
        'targetTab': 3,
      });
    }

    if (reminders.isEmpty) {
      reminders.add({
        'id': 'aman',
        'level': 'success',
        'tag': 'Kondisi Aman',
        'title': 'Seluruh Inventaris Beroperasi Optimal',
        'desc': 'Tidak terdeteksi anomali kegagalan non-medis. Pertahankan pemantauan rutin preventif.',
        'actionText': 'Cek Ruangan',
        'targetTab': 2,
      });
    }

    return reminders;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'START',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Sistem Terpadu Alat Rumah Tangga • RSD dr. Soebandi',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              ThemeService.instance.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: const Color(0xFFFBBF24),
            ),
            onPressed: () => setState(() => ThemeService.instance.toggleTheme()),
            tooltip: 'Ganti Tema',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Segarkan Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFE11D48)),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFFE11D48))),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadDashboardData,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF10B981),
                  onRefresh: _loadDashboardData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                    children: [
                      // --- Section 1: 4 Metrik Ringkasan (KPI) ---
                      _buildKpiGrid(isDark),
                      const SizedBox(height: 16),

                      // --- Section 2: Visualisasi Bar Chart Kondisi Inventaris ---
                      _buildBarChartSection(isDark),
                      const SizedBox(height: 16),

                      // --- Section 3: Kolom Pengingat Keputusan Bisnis ---
                      _buildBusinessRemindersSection(isDark),
                    ],
                  ),
                ),
    );
  }

  // ==========================================
  // WIDGET: 4 Metrik Ringkasan KPI
  // ==========================================
  Widget _buildKpiGrid(bool isDark) {
    final double persenBaik = _totalAset > 0 ? (_totalBaik / _totalAset) * 100 : 0;
    final double persenPerlu = _totalAset > 0 ? (_totalPerlu / _totalAset) * 100 : 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'TOTAL ASET',
                value: '$_totalAset',
                subtitle: '12 Ruang Rawat Inap',
                icon: Icons.inventory_2_outlined,
                accentColor: const Color(0xFF38BDF8),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'KONDISI BAIK',
                value: '$_totalBaik',
                subtitle: '${persenBaik.toStringAsFixed(1)}% Terkendali',
                icon: Icons.check_circle_outline,
                accentColor: const Color(0xFF10B981),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'PERLU PEMELIHARAAN',
                value: '$_totalPerlu',
                subtitle: '${persenPerlu.toStringAsFixed(1)}% Perlu Servis',
                icon: Icons.build_circle_outlined,
                accentColor: const Color(0xFFF59E0B),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'PRIORITAS KRITIS',
                value: '$_totalTinggi',
                subtitle: 'Risiko Kerusakan > 80%',
                icon: Icons.error_outline,
                accentColor: const Color(0xFFE11D48),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.02), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: Visualisasi Bar Chart Kondisi Aset
  // ==========================================
  Widget _buildBarChartSection(bool isDark) {
    final List<Map<String, dynamic>> items;
    if (_chartView == 'ruangan') {
      items = _roomSummaries.map((r) {
        final t = (r['total'] as num?)?.toInt() ?? 0;
        final p = (r['perlu'] as num?)?.toInt() ?? 0;
        final b = (t - p).clamp(0, t);
        return {
          'id': r['id'],
          'label': r['nama'] as String,
          'shortLabel': 'R.${r['id']}',
          'total': t,
          'perlu': p,
          'baik': b,
          'tinggi': (r['tinggi'] as num?)?.toInt() ?? 0,
        };
      }).toList();
    } else {
      items = _categoryStats.map((c) {
        return {
          'id': c['label'],
          'label': c['label'] as String,
          'shortLabel': c['label'] as String,
          'total': c['total'] as int,
          'perlu': c['perlu'] as int,
          'baik': c['baik'] as int,
          'tinggi': c['tinggi'] as int,
        };
      }).toList();
    }

    final maxVal = items.fold<int>(1, (max, it) => it['total'] > max ? it['total'] : max);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.02), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar Chart
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Visualisasi Kondisi Inventaris',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),

              // Tab Toggle Switcher
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    _buildChartTab('Ruangan', _chartView == 'ruangan', () {
                      setState(() => _chartView = 'ruangan');
                    }, isDark),
                    _buildChartTab('Kategori', _chartView == 'kategori', () {
                      setState(() => _chartView = 'kategori');
                    }, isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Komparasi batang: Hijau (Kondisi Baik) vs Kuning/Merah (Perlu Pemeliharaan)',
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),

          // Legend Bar
          Row(
            children: [
              _buildLegendItem(const Color(0xFF10B981), 'Baik', isDark),
              const SizedBox(width: 12),
              _buildLegendItem(const Color(0xFFF59E0B), 'Perlu Servis', isDark),
              const SizedBox(width: 12),
              _buildLegendItem(const Color(0xFFE11D48), 'Kritis', isDark),
            ],
          ),
          const SizedBox(height: 14),

          // Horizontal Bars List (Ideal for mobile touch & label readability)
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada data inventaris', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            )
          else
            ...items.map((it) {
              final int total = it['total'];
              final int baik = it['baik'];
              final int perlu = it['perlu'];
              final int tinggi = it['tinggi'];
              final double flexBaik = total > 0 ? (baik / maxVal) : 0;
              final double flexPerlu = total > 0 ? (perlu / maxVal) : 0;
              final double remainingFlex = (1.0 - (flexBaik + flexPerlu)).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bar Header (Label & Counts)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          it['label'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '$baik',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'monospace'),
                            ),
                            Text(' / ', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                            Text(
                              '$perlu',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), fontFamily: 'monospace'),
                            ),
                            if (tinggi > 0) ...[
                              Text(' (', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                              Text(
                                '$tinggi',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48), fontFamily: 'monospace'),
                              ),
                              Text(')', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                            ],
                            const SizedBox(width: 4),
                            Text(
                              '($total)',
                              style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Multi-Segment Progress Bar
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          // Segment Baik (Hijau)
                          if (baik > 0)
                            Expanded(
                              flex: (flexBaik * 1000).toInt(),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.horizontal(
                                    left: const Radius.circular(6),
                                    right: perlu == 0 ? const Radius.circular(6) : Radius.zero,
                                  ),
                                ),
                              ),
                            ),
                          // Segment Perlu (Kuning / Merah jika kritis)
                          if (perlu > 0)
                            Expanded(
                              flex: (flexPerlu * 1000).toInt(),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: tinggi > 0 ? const Color(0xFFE11D48) : const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.horizontal(
                                    left: baik == 0 ? const Radius.circular(6) : Radius.zero,
                                    right: const Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          // Remaining Space to scale
                          if (remainingFlex > 0)
                            Expanded(
                              flex: (remainingFlex * 1000).toInt(),
                              child: const SizedBox(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildChartTab(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0F172A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF10B981)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // WIDGET: Kolom Pengingat Keputusan Bisnis
  // ==========================================
  Widget _buildBusinessRemindersSection(bool isDark) {
    final reminders = _businessReminders;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.02), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pengingat Keputusan Bisnis',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${reminders.length} Rekomendasi',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tindakan strategis terintegrasi sistem rekomendasi XGBoost',
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),

          // Cards list
          ...reminders.map((rem) {
            final level = rem['level'] as String;
            final Color accentColor = level == 'danger'
                ? const Color(0xFFE11D48)
                : level == 'warning'
                    ? const Color(0xFFD97706)
                    : level == 'info'
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF047857);

            final Color cardBg = accentColor.withValues(alpha: isDark ? 0.08 : 0.05);
            final Color cardBorder = accentColor.withValues(alpha: isDark ? 0.25 : 0.2);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row: Tag & Badge Urgensi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rem['tag'],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                            color: accentColor,
                          ),
                        ),
                      ),
                      if (level == 'danger')
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE11D48),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Prioritas Mendesak',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    rem['title'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    rem['desc'],
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Action Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () {
                        final tabIndex = rem['targetTab'] as int?;
                        if (tabIndex != null && widget.onNavigateTab != null) {
                          widget.onNavigateTab!(tabIndex);
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              rem['actionText'],
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 13, color: accentColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
