import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';

class ItemDetailScreen extends StatefulWidget {
  final String inventoryId;

  const ItemDetailScreen({super.key, required this.inventoryId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _supabaseService = SupabaseService();
  final _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _inventory;
  Map<String, dynamic>? _prediction;
  Map<String, dynamic>? _localShap;

  String? _koreksiMsg;
  String? _taskMsg;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final inv = await _supabaseService.getItemDetail(widget.inventoryId);
      final preds = inv['predictions'] as List<dynamic>? ?? [];
      final pred = preds.isNotEmpty ? preds.first as Map<String, dynamic> : null;

      Map<String, dynamic>? shap;
      try {
        shap = await _apiService.explainById(widget.inventoryId);
      } catch (_) {
        // Fallback jika API explain tidak terjangkau
      }

      if (mounted) {
        setState(() {
          _inventory = inv;
          _prediction = pred;
          _localShap = shap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleKoreksi(int val) async {
    if (_prediction == null) return;
    setState(() => _isActionLoading = true);
    try {
      final predId = _prediction!['id'] as String;
      await _supabaseService.submitCorrection(predId, val);
      setState(() {
        _prediction!['koreksi_petugas'] = val;
        _koreksiMsg = val == 0
            ? 'Koreksi tersimpan: Dikonfirmasi Kondisi Baik'
            : 'Koreksi tersimpan: Dikonfirmasi Perlu Pemeliharaan';
        _isActionLoading = false;
      });
    } catch (e) {
      setState(() {
        _koreksiMsg = 'Gagal menyimpan koreksi: $e';
        _isActionLoading = false;
      });
    }
  }

  Future<void> _handleTambahAntrean() async {
    if (_prediction == null) return;
    setState(() => _isActionLoading = true);
    try {
      final predId = _prediction!['id'] as String;
      await _supabaseService.createMaintenanceTask(predId);
      setState(() {
        _taskMsg = 'Aset berhasil dimasukkan ke antrean pemeliharaan.';
        _isActionLoading = false;
      });
    } catch (e) {
      setState(() {
        _taskMsg = 'Gagal membuat antrean: $e';
        _isActionLoading = false;
      });
    }
  }

  Future<void> _handleDeleteAsset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Aset Ini?'),
        content: Text(
          'Aset "${_inventory?['nama_barang'] ?? ''}" beserta data prediksi dan riwayat tugas pemeliharaan akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            child: const Text('Hapus Permanen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabaseService.deleteInventoryItem(widget.inventoryId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aset berhasil dihapus.'),
              backgroundColor: Color(0xFF047857),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus aset: $e'), backgroundColor: const Color(0xFFE11D48)),
          );
        }
      }
    }
  }

  String _formatCurrency(num value) {
    final s = value.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp' + s.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Detail Aset Non-Medis',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFDA4AF)),
            onPressed: (_isLoading || _inventory == null) ? null : _handleDeleteAsset,
            tooltip: 'Hapus Aset Ini',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAllData,
            tooltip: 'Segarkan Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF10B981)),
                  SizedBox(height: 12),
                  Text('Memuat informasi aset & analisis AI…', style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Color(0xFFF43F5E)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAllData,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                          child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _inventory == null
                  ? const Center(child: Text('Data aset tidak ditemukan'))
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final inv = _inventory!;
    final pred = _prediction;
    final roomName = inv['rooms']?['nama'] as String? ?? '-';
    final int effLabel = (pred?['koreksi_petugas'] as int?) ?? (pred?['label_biner'] as int?) ?? 0;
    final prioritas = pred?['prioritas'] as String? ?? 'Baik';
    final double probVal = (pred?['prob_perlu_pemeliharaan'] as num?)?.toDouble() ?? 0.0;
    final int probPct = (probVal * 100).round();

    final num harga = inv['harga'] as num? ?? 0;
    final int jumlah = (inv['jumlah'] as num?)?.toInt() ?? 1;
    final num hargaPerUnit = jumlah > 0 ? (harga / jumlah).round() : harga;

    final double? rasioSusut = (_localShap?['rasio_susut_persen'] as num?)?.toDouble();
    final num? sisaBuku = (_localShap?['sisa_nilai_buku'] as num?);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Card
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Text(
                        'Ruang $roomName',
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      'ID: ${(inv['id'] as String).substring(0, 8)}…',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black45),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  inv['nama_barang'] ?? '-',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${inv['kategori']} • Material ${inv['bahan']} • Tahun Beli ${inv['tahun_pembelian']}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (pred != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Badge Status
                      _buildStatusBadge(pred),
                      // Badge Prioritas
                      _buildPrioritasBadge(pred, effLabel, prioritas),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Card Spesifikasi & Nilai Aset
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('SPESIFIKASI & NILAI ASET', 'Data Fisik'),
                const Divider(height: 18, color: Color(0xFFE2E8F0)),
                _buildDataRow('Tahun Pembelian', '${inv['tahun_pembelian']}'),
                _buildDataRow('Kuantitas Unit', '$jumlah unit'),
                _buildDataRow('Harga Total', _formatCurrency(harga), bold: true),
                _buildDataRow('Harga per Unit', _formatCurrency(hargaPerUnit)),
                if (rasioSusut != null)
                  _buildDataRow(
                    'Persentase Susut',
                    '${rasioSusut.toStringAsFixed(1)}% dari harga awal',
                    color: rasioSusut > 80 ? const Color(0xFFE11D48) : const Color(0xFFD97706),
                    bold: true,
                  ),
                if (sisaBuku != null)
                  _buildDataRow(
                    'Sisa Nilai Buku',
                    _formatCurrency(sisaBuku),
                    color: const Color(0xFF047857),
                    bold: true,
                  ),
                if (inv['kondisi_asli'] != null)
                  _buildDataRow('Label Dokumen Awal', '${inv['kondisi_asli']}'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Card Hasil Inferensi Model AI
          if (pred != null)
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('HASIL INFERENSI MODEL AI', 'XGBoost Decision'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),

                  // Probabilitas Progress Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Probabilitas Kerusakan',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            Text(
                              '${(probVal * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: probVal.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              probPct > 66.7
                                  ? const Color(0xFFE11D48)
                                  : probPct > 33.3
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildDataRow('Threshold Keputusan F2', '${pred['threshold'] ?? 0.417}',
                      color: const Color(0xFF047857), bold: true),
                  _buildDataRow('Versi Model', '${pred['model_version'] ?? 'v1.0.0'}'),

                  if (pred['koreksi_petugas'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Koreksi Petugas', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: pred['koreksi_petugas'] == 0
                                  ? const Color(0xFF10B981).withOpacity(0.12)
                                  : const Color(0xFFF43F5E).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pred['koreksi_petugas'] == 0
                                  ? 'Dikonfirmasi Baik'
                                  : 'Dikonfirmasi Perlu Pemeliharaan',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: pred['koreksi_petugas'] == 0
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFBE123C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // SHAP Top 3
                  if ((pred['shap_top3'] as List<dynamic>? ?? []).isNotEmpty) ...[
                    const Divider(height: 18, color: Color(0xFFE2E8F0)),
                    const Row(
                      children: [
                        Icon(Icons.bolt, size: 16, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'Faktor Utama Keputusan (SHAP):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(pred['shap_top3'] as List<dynamic>).asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${idx + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['penjelasan'] ?? item['fitur'] ?? '-',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 14),

          // 4. Card Visualisasi SHAP Lokal (Bar Chart)
          if (_localShap != null && (_localShap!['features'] as List<dynamic>? ?? []).isNotEmpty)
            _buildLocalShapCard(_localShap!['features'] as List<dynamic>),

          const SizedBox(height: 14),

          // 5. Card Tindak Lanjut & Intervensi Petugas
          if (pred != null)
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('TINDAK LANJUT & INTERVENSI PETUGAS', 'Aksi Lapangan'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  const Text(
                    'Verifikasi / Koreksi manual klasifikasi kondisi:',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isActionLoading ? null : () => _handleKoreksi(0),
                          icon: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                          label: const Text('Validasi: Baik', style: TextStyle(fontSize: 11, color: Color(0xFF047857))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isActionLoading ? null : () => _handleKoreksi(1),
                          icon: const Icon(Icons.highlight_off, size: 16, color: Color(0xFFE11D48)),
                          label: const Text('Validasi: Perlu', style: TextStyle(fontSize: 11, color: Color(0xFFBE123C))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE11D48)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleTambahAntrean,
                    icon: const Icon(Icons.assignment_outlined, size: 16),
                    label: const Text('+ Masukkan Antrean Pemeliharaan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (_koreksiMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _koreksiMsg!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (_taskMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _taskMsg!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLocalShapCard(List<dynamic> features) {
    // Cari nilai absolut maksimum untuk normalisasi bar
    double maxAbs = 0.1;
    for (var f in features) {
      final v = ((f['shap_value'] as num?)?.toDouble() ?? 0.0).abs();
      if (v > maxAbs) maxAbs = v;
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('KONTRIBUSI FITUR SHAP LOKAL', 'Explainable AI'),
          const SizedBox(height: 4),
          const Text(
            'Pengaruh masing-masing atribut terhadap probabilitas kerusakan aset ini:',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const Divider(height: 18, color: Color(0xFFE2E8F0)),

          ...features.map((f) {
            final double val = (f['shap_value'] as num?)?.toDouble() ?? 0.0;
            final bool isPositive = val >= 0; // Mendorong ke Perlu Pemeliharaan
            final double pct = (val.abs() / maxAbs).clamp(0.05, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            f['label'] ?? f['key'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              '${f['formatted_value'] ?? f['value'] ?? ''}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${val.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: isPositive ? const Color(0xFFE11D48) : const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Stack(
                    children: [
                      Container(
                        height: 7,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: isPositive ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFF43F5E), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text('Mendorong Rusak', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text('Menahan Rusak (Baik)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> pred) {
    final int? kor = pred['koreksi_petugas'] as int?;
    final int biner = (pred['label_biner'] as num?)?.toInt() ?? 0;

    String text;
    Color bg;
    Color border;
    Color textColor;

    if (kor == 0) {
      text = 'Kondisi Baik (Selesai Perbaikan)';
      bg = const Color(0xFF10B981).withOpacity(0.12);
      border = const Color(0xFF10B981).withOpacity(0.4);
      textColor = const Color(0xFF047857);
    } else if (kor == 1) {
      text = 'Perlu Pemeliharaan (Koreksi)';
      bg = const Color(0xFFF43F5E).withOpacity(0.12);
      border = const Color(0xFFF43F5E).withOpacity(0.4);
      textColor = const Color(0xFFBE123C);
    } else if (biner == 1) {
      text = 'Perlu Pemeliharaan';
      bg = const Color(0xFFF43F5E).withOpacity(0.12);
      border = const Color(0xFFF43F5E).withOpacity(0.4);
      textColor = const Color(0xFFBE123C);
    } else {
      text = 'Kondisi Baik';
      bg = const Color(0xFF10B981).withOpacity(0.12);
      border = const Color(0xFF10B981).withOpacity(0.4);
      textColor = const Color(0xFF047857);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildPrioritasBadge(Map<String, dynamic> pred, int effLabel, String prioritas) {
    if (pred['koreksi_petugas'] == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        ),
        child: const Text('Prioritas Teratasi',
            style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11)),
      );
    }

    Color color;
    if (prioritas == 'Tinggi') {
      color = const Color(0xFFE11D48);
    } else if (prioritas == 'Sedang') {
      color = const Color(0xFFD97706);
    } else {
      color = const Color(0xFF047857);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text('Prioritas $prioritas',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, String badge) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334155),
            letterSpacing: 0.5,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badge,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? const Color(0xFF0F172A),
              fontFamily: bold ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
