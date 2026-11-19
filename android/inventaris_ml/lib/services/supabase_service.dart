import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room.dart';
import '../models/prediction_result.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Room>> getRooms() async {
    final response = await client.from('rooms').select().order('id', ascending: true);
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

  Future<Map<String, dynamic>> getItemDetail(String inventoryId) async {
    final data = await client
        .from('inventories')
        .select('''
          id, room_id, nama_barang, bahan, kategori, tahun_pembelian, jumlah, harga, kondisi_asli,
          rooms (id, nama),
          predictions (
            id, prob_perlu_pemeliharaan, label_biner, threshold, prioritas, shap_top3, model_version, koreksi_petugas
          )
        ''')
        .eq('id', inventoryId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getMaintenanceTasks() async {
    final data = await client
        .from('maintenance_tasks')
        .select('''
          id, status, created_at,
          predictions (
            id, prob_perlu_pemeliharaan, label_biner, prioritas,
            inventories (
              id, nama_barang, kategori, bahan, tahun_pembelian,
              rooms (id, nama)
            )
          )
        ''')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
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

  Future<void> updateTaskStatus(String taskId, String status, {String? predictionId}) async {
    await client
        .from('maintenance_tasks')
        .update({'status': status})
        .eq('id', taskId);

    if (status == 'Selesai' && predictionId != null) {
      await client
          .from('predictions')
          .update({'koreksi_petugas': 0})
          .eq('id', predictionId);
    }
  }

  Future<void> clearRoomInventories(int roomId) async {
    await client.from('inventories').delete().eq('room_id', roomId);
  }

  Future<void> deleteInventoryItem(String inventoryId) async {
    await client.from('inventories').delete().eq('id', inventoryId);
  }
}
