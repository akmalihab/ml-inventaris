import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/supabase_service.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _supabaseService = SupabaseService();
  List<Room> _rooms = [];
  int? _selectedRoomId;
  List<Map<String, dynamic>> _items = [];
  bool _isLoadingRooms = true;
  bool _isLoadingItems = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final rooms = await _supabaseService.getRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          if (_rooms.isNotEmpty) {
            _selectedRoomId = _rooms.first.id;
          }
          _isLoadingRooms = false;
        });
        if (_selectedRoomId != null) {
          _loadItems(_selectedRoomId!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
      }
    }
  }

  Future<void> _loadItems(int roomId) async {
    setState(() => _isLoadingItems = true);
    try {
      final items = await _supabaseService.getRoomItems(roomId);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  Color _getBadgeColor(String? prioritas, int isPerlu) {
    if (isPerlu == 0) return const Color(0xFF10B981);
    if (prioritas == 'Tinggi') return const Color(0xFFF43F5E);
    if (prioritas == 'Sedang') return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((i) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final n = (i['nama_barang'] as String? ?? '').toLowerCase();
      return n.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantau Aset Ruangan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingRooms
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Ruangan selector + search
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedRoomId,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Ruangan',
                          prefixIcon: Icon(Icons.meeting_room),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _rooms.map((r) {
                          return DropdownMenuItem(
                            value: r.id,
                            child: Text('${r.nama} (ID: ${r.id})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedRoomId = val);
                            _loadItems(val);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Cari nama barang di ruangan ini…',
                          prefixIcon: Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // List barang
                Expanded(
                  child: _isLoadingItems
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? const Center(child: Text('Tidak ada aset tercatat di ruangan ini.'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (ctx, idx) {
                                final item = filtered[idx];
                                final preds = item['predictions'] as List<dynamic>? ?? [];
                                final pred = preds.isNotEmpty ? preds.first as Map<String, dynamic> : null;

                                final int effLabel = (pred?['koreksi_petugas'] as int?) ??
                                    (pred?['label_biner'] as int?) ??
                                    0;
                                final String prioritas = pred?['prioritas'] as String? ?? 'Baik';
                                final double? prob = (pred?['prob_perlu_pemeliharaan'] as num?)?.toDouble();
                                final color = _getBadgeColor(prioritas, effLabel);

                                return Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    title: Text(
                                      item['nama_barang'] ?? '-',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      '${item['kategori']} • ${item['bahan']} • Beli ${item['tahun_pembelian']} (${item['jumlah']} unit)',
                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: color.withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            effLabel == 1 ? 'Prioritas $prioritas' : 'Kondisi Baik',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                        if (prob != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              'Prob: ${(prob * 100).toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
