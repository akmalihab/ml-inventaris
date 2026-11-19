import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room.dart';
import '../models/prediction_result.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Room>> getRooms() async {
    final response = await client.from('rooms').select().order('id');
    return (response as List).map((e) => Room.fromJson(e)).toList();
  }

  Future<Map<String, String>> saveInventoryAndPrediction({
    required int roomId,
    required String namaBarang,
    required String bahan,
    required String kategori,
    required int tahunPembelian,
    required int jumlah,
    required double harga,
    String? triwulan,
    required PredictionResult prediction,
  }) async {
    // 1. Simpan inventaris
    final invRes = await client
        .from('inventories')
        .insert({
          'room_id': roomId,
          'nama_barang': namaBarang,
          'bahan': bahan,
          'kategori': kategori,
          'tahun_pembelian': tahunPembelian,
          'jumlah': jumlah,
          'harga': harga,
          'triwulan': triwulan,
        })
        .select('id')
        .single();

    final inventoryId = invRes['id'] as String;

    // 2. Simpan prediksi
    final shapMap = prediction.shapTop3
        .map((s) => {'fitur': s.fitur, 'penjelasan': s.penjelasan})
        .toList();

    final predRes = await client
        .from('predictions')
        .insert({
          'inventory_id': inventoryId,
          'prob_perlu_pemeliharaan': prediction.probabilitas,
          'label_biner': prediction.labelBiner,
          'threshold': prediction.threshold,
          'prioritas': prediction.prioritas,
          'shap_top3': shapMap,
          'model_version': prediction.modelVersion,
        })
        .select('id')
        .single();

    final predictionId = predRes['id'] as String;

    return {
      'inventory_id': inventoryId,
      'prediction_id': predictionId,
    };
  }

  Future<void> submitCorrection(String predictionId, int koreksi) async {
    await client
        .from('predictions')
        .update({'koreksi_petugas': koreksi})
        .eq('id', predictionId);
  }

  Future<void> createMaintenanceTask(String predictionId) async {
    await client.from('maintenance_tasks').insert({
      'prediction_id': predictionId,
      'status': 'Antre',
    });
  }

  Future<List<Map<String, dynamic>>> getRoomItems(int roomId) async {
    final data = await client
        .from('inventories')
        .select('''
          id, nama_barang, bahan, kategori, tahun_pembelian, jumlah, harga,
          predictions (
            id, prob_perlu_pemeliharaan, label_biner, threshold, prioritas, shap_top3, model_version, koreksi_petugas
          )
        ''')
        .eq('room_id', roomId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }
}
