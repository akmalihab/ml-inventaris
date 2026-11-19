import 'package:flutter/material.dart';
import '../models/prediction_result.dart';
import '../services/supabase_service.dart';

class ResultScreen extends StatefulWidget {
  final String namaBarang;
  final int roomId;
  final String roomNama;
  final int tahunPembelian;
  final String bahan;
  final String kategori;
  final double harga;
  final PredictionResult prediction;
  final String inventoryId;
  final String predictionId;

  const ResultScreen({
    super.key,
    required this.namaBarang,
    required this.roomId,
    required this.roomNama,
    required this.tahunPembelian,
    required this.bahan,
    required this.kategori,
    required this.harga,
    required this.prediction,
    required this.inventoryId,
    required this.predictionId,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _supabaseService = SupabaseService();
  bool _isSavingCorrection = false;
  bool _isCreatingTask = false;
  int? _koreksiPetugas;
  bool _taskCreated = false;

  @override
  void initState() {
    super.initState();
    _koreksiPetugas = widget.prediction.koreksiPetugas;
  }

  Color _getPriorityColor(String prioritas) {
    switch (prioritas) {
      case 'Tinggi':
        return const Color(0xFFF43F5E); // Rose 500
      case 'Sedang':
        return const Color(0xFFF59E0B); // Amber 500
      default:
        return const Color(0xFF10B981); // Emerald 500
    }
  }

  Future<void> _submitKoreksi(int koreksi) async {
    setState(() => _isSavingCorrection = true);
    try {
      await _supabaseService.submitCorrection(widget.predictionId, koreksi);
      setState(() {
        _koreksiPetugas = koreksi;
        widget.prediction.koreksiPetugas = koreksi;
        _isSavingCorrection = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              koreksi == 0
                  ? 'Koreksi tersimpan: Ditetapkan Kondisi BAIK oleh petugas.'
                  : 'Koreksi tersimpan: Ditetapkan PERLU PEMELIHARAAN oleh petugas.',
            ),
            backgroundColor: koreksi == 0 ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSavingCorrection = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan koreksi: $e')),
        );
      }
    }
  }

  Future<void> _createTask() async {
    setState(() => _isCreatingTask = true);
    try {
      await _supabaseService.createMaintenanceTask(widget.predictionId);
      setState(() {
        _isCreatingTask = false;
        _taskCreated = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas pemeliharaan berhasil dimasukkan ke antrean!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreatingTask = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat tugas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prioritasColor = _getPriorityColor(widget.prediction.prioritas);
    final bool isPerlu = (_koreksiPetugas ?? widget.prediction.labelBiner) == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Prediksi & SHAP', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card AI
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isPerlu ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
                  border: Border.all(
                    color: isPerlu ? const Color(0xFFFECDD3) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(widget.roomNama, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: EdgeInsets.zero,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: prioritasColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: prioritasColor),
                          ),
                          child: Text(
                            'Prioritas ${widget.prediction.prioritas}',
                            style: TextStyle(
                              color: prioritasColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.namaBarang,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.kategori} • ${widget.bahan} • Beli Tahun ${widget.tahunPembelian}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 10),

                    // Probabilitas & Threshold
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Probabilitas Risiko', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(
                              '${(widget.prediction.probabilitas * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: prioritasColor,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('Threshold Model (F2)', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.prediction.threshold}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPerlu ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: isPerlu ? const Color(0xFFF43F5E) : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _koreksiPetugas != null
                                ? (_koreksiPetugas == 0 ? 'Status: BAIK (Diverifikasi Petugas)' : 'Status: PERLU PEMELIHARAAN (Koreksi)')
                                : (widget.prediction.labelBiner == 1 ? 'Status AI: PERLU PEMELIHARAAN' : 'Status AI: KONDISI BAIK'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isPerlu ? const Color(0xFFE11D48) : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top-3 Faktor Penentu (SHAP Explainability)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 20, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text(
                          '3 Alasan Utama Rekomendasi AI (SHAP)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Model XGBoost menganalisis atribut aset dan menemukan faktor paling berpengaruh:',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    if (widget.prediction.shapTop3.isEmpty)
                      const Text('Belum ada rincian SHAP.', style: TextStyle(fontSize: 12, color: Colors.grey))
                    else
                      ...widget.prediction.shapTop3.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final shap = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: const Color(0xFF0F172A),
                                child: Text('$idx', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shap.fitur,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      shap.penjelasan,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
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
              ),
            ),
            const SizedBox(height: 16),

            // Koreksi Petugas Lapangan
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verifikasi & Koreksi Petugas Lapangan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Jika kondisi fisik di ruangan berbeda dengan hasil inferensi AI, petugas berhak mengoreksi keputusan sistem:',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSavingCorrection ? null : () => _submitKoreksi(0),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: BorderSide(
                                color: _koreksiPetugas == 0 ? const Color(0xFF059669) : Colors.grey.shade300,
                                width: _koreksiPetugas == 0 ? 2 : 1,
                              ),
                              backgroundColor: _koreksiPetugas == 0 ? const Color(0xFFECFDF5) : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Tetapkan Baik (0)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSavingCorrection ? null : () => _submitKoreksi(1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE11D48),
                              side: BorderSide(
                                color: _koreksiPetugas == 1 ? const Color(0xFFE11D48) : Colors.grey.shade300,
                                width: _koreksiPetugas == 1 ? 2 : 1,
                              ),
                              backgroundColor: _koreksiPetugas == 1 ? const Color(0xFFFFF1F2) : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.build_circle, size: 18),
                            label: const Text('Tetapkan Perlu (1)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Antrekan Pemeliharaan jika Perlu
            if (isPerlu)
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_isCreatingTask || _taskCreated) ? null : _createTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _taskCreated
                      ? const Icon(Icons.check, color: Color(0xFF10B981))
                      : const Icon(Icons.assignment_add),
                  label: Text(
                    _taskCreated ? 'Sudah Masuk Antrean Pemeliharaan' : 'Masukkan ke Antrean Pemeliharaan',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
