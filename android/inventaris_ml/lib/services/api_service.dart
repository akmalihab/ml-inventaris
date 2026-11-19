import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/prediction_result.dart';

class ApiService {
  Future<PredictionResult> predictItem({
    required String namaBarang,
    required String namaRuangan,
    required String bahan,
    required String kategori,
    required int tahunPembelian,
    required int jumlah,
    required double harga,
    String? triwulan,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/predict');
    final payload = {
      'nama_barang': namaBarang,
      'nama_ruangan': namaRuangan,
      'bahan': bahan,
      'kategori': kategori,
      'tahun_pembelian': tahunPembelian,
      'jumlah': jumlah,
      'harga': harga,
      if (triwulan != null) 'triwulan': triwulan,
    };

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PredictionResult.fromJson(data);
    } else {
      throw Exception('Gagal inferensi AI (${response.statusCode}): ${response.body}');
    }
  }
}
