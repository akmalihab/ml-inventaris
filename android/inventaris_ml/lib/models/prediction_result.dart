class ShapReason {
  final String fitur;
  final String penjelasan;

  ShapReason({required this.fitur, required this.penjelasan});

  factory ShapReason.fromJson(Map<String, dynamic> json) {
    return ShapReason(
      fitur: json['fitur'] as String? ?? '',
      penjelasan: json['penjelasan'] as String? ?? '',
    );
  }
}

class PredictionResult {
  final double probabilitas;
  final int labelBiner; // 0 = Baik, 1 = Perlu Pemeliharaan
  final double threshold;
  final String prioritas; // 'Baik', 'Sedang', 'Tinggi'
  final List<ShapReason> shapTop3;
  final String modelVersion;
  final double? sisaNilaiBuku;
  final double? rasioSusutPersen;
  final String? inventoryId;
  final String? predictionId;
  int? koreksiPetugas;

  PredictionResult({
    required this.probabilitas,
    required this.labelBiner,
    required this.threshold,
    required this.prioritas,
    required this.shapTop3,
    required this.modelVersion,
    this.sisaNilaiBuku,
    this.rasioSusutPersen,
    this.inventoryId,
    this.predictionId,
    this.koreksiPetugas,
  });

  bool get isPerluPemeliharaan => (koreksiPetugas ?? labelBiner) == 1;

  factory PredictionResult.fromJson(Map<String, dynamic> json, {String? invId, String? predId}) {
    final rawShap = json['shap_top3'] as List<dynamic>? ?? [];
    return PredictionResult(
      probabilitas: (json['prob_perlu_pemeliharaan'] as num).toDouble(),
      labelBiner: (json['label_biner'] as num).toInt(),
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.417,
      prioritas: json['prioritas'] as String? ?? 'Baik',
      shapTop3: rawShap
          .map((e) => ShapReason.fromJson(e as Map<String, dynamic>))
          .toList(),
      modelVersion: json['model_version'] as String? ?? 'v1.0.0',
      sisaNilaiBuku: (json['sisa_nilai_buku'] as num?)?.toDouble(),
      rasioSusutPersen: (json['rasio_susut_persen'] as num?)?.toDouble(),
      inventoryId: invId ?? json['inventory_id'] as String?,
      predictionId: predId ?? json['id'] as String?,
      koreksiPetugas: json['koreksi_petugas'] as int?,
    );
  }
}
