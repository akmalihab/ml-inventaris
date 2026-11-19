import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/supabase_service.dart';
import 'item_detail_screen.dart';

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
  String _filterStatus = 'semua'; // 'semua' | 'baik' | 'perlu' | 'kritis'
  String _filterKategori = 'semua'; // 'semua' | 'Elektronik' | 'Furnitur' | 'Pelengkap'

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

  String _formatCurrency(num value) {
    final s = value.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp' + s.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    // Hitung ringkasan statistik ruangan (Summary Cards)
    final totalAset = _items.length;
    int perluCount = 0;
    int kritisCount = 0;

    for (var item in _items) {
      final preds = item['predictions'] as List<dynamic>? ?? [];
      final pred = preds.isNotEmpty ? preds.first as Map<String, dynamic> : null;
      final int eff = (pred?['koreksi_petugas'] as int?) ?? (pred?['label_biner'] as int?) ?? 0;
      if (eff == 1) {
        perluCount++;
        if (pred?['prioritas'] == 'Tinggi') {
          kritisCount++;
        }
      }
    }

    // Filter list
    final filtered = _items.where((i) {
      // 1. Search nama barang
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final n = (i['nama_barang'] as String? ?? '').toLowerCase();
        if (!n.contains(q)) return false;
      }

      // 2. Filter kategori
      if (_filterKategori != 'semua') {
        if (i['kategori'] != _filterKategori) return false;
      }

      // 3. Filter status
      final preds = i['predictions'] as List<dynamic>? ?? [];
      final pred = preds.isNotEmpty ? preds.first as Map<String, dynamic> : null;
      final int eff = (pred?['koreksi_petugas'] as int?) ?? (pred?['label_biner'] as int?) ?? 0;
      final bool isPerlu = eff == 1;
      final bool isKritis = isPerlu && pred?['prioritas'] == 'Tinggi';

      if (_filterStatus == 'baik' && isPerlu) return false;
      if (_filterStatus == 'perlu' && !isPerlu) return false;
      if (_filterStatus == 'kritis' && !isKritis) return false;

      return true;
    }).toList();

    final selectedRoom = _rooms.firstWhere(
      (r) => r.id == _selectedRoomId,
      orElse: () => Room(id: 0, nama: '-'),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data & Inventaris Ruangan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '12 Ruang Rawat Inap Kelas 3',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedRoomId != null) _loadItems(_selectedRoomId!);
            },
            tooltip: 'Segarkan',
          ),
        ],
      ),
      body: _isLoadingRooms
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : Column(
              children: [
                // Top control: Selector Ruangan & Statistik 3 Card
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      // Dropdown Ruangan
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedRoomId,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF0F172A)),
                            items: _rooms.map((r) {
                              return DropdownMenuItem(
                                value: r.id,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'R.${r.id}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ruang ${r.nama}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    const Spacer(),
                                    const Text(
                                      'Kelas 3',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRoomId = val);
                                _loadItems(val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 3 Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Total Aset',
                              value: '$totalAset',
                              color: const Color(0xFF0F172A),
                              bgColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Perlu Pemeliharaan',
                              value: '$perluCount',
                              color: const Color(0xFFD97706),
                              bgColor: const Color(0xFFFFFBEB),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Prioritas Kritis',
                              value: '$kritisCount',
                              color: const Color(0xFFE11D48),
                              bgColor: const Color(0xFFFFF1F2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Search Box
                      SizedBox(
                        height: 38,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cari aset di Ruang ${selectedRoom.nama}…',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Filter Chips: Status
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Semua Status', _filterStatus == 'semua', () {
                              setState(() => _filterStatus = 'semua');
                            }),
                            const SizedBox(width: 6),
                            _buildFilterChip('Kondisi Baik', _filterStatus == 'baik', () {
                              setState(() => _filterStatus = 'baik');
                            }),
                            const SizedBox(width: 6),
                            _buildFilterChip('Perlu Servis', _filterStatus == 'perlu', () {
                              setState(() => _filterStatus = 'perlu');
                            }),
                            const SizedBox(width: 6),
                            _buildFilterChip('Prioritas Kritis', _filterStatus == 'kritis', () {
                              setState(() => _filterStatus = 'kritis');
                            }),
                            const VerticalDivider(width: 16),
                            // Filter Kategori
                            _buildCategoryChip('Semua Kategori', _filterKategori == 'semua', () {
                              setState(() => _filterKategori = 'semua');
                            }),
                            const SizedBox(width: 6),
                            _buildCategoryChip('Elektronik', _filterKategori == 'Elektronik', () {
                              setState(() => _filterKategori = 'Elektronik');
                            }),
                            const SizedBox(width: 6),
                            _buildCategoryChip('Furnitur', _filterKategori == 'Furnitur', () {
                              setState(() => _filterKategori = 'Furnitur');
                            }),
                            const SizedBox(width: 6),
                            _buildCategoryChip('Pelengkap', _filterKategori == 'Pelengkap', () {
                              setState(() => _filterKategori = 'Pelengkap');
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // List Items
                Expanded(
                  child: _isLoadingItems
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _items.isEmpty
                                        ? 'Belum ada aset di ruangan ini.'
                                        : 'Tidak ada aset yang cocok dengan filter.',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final item = filtered[idx];
                                return _buildItemCard(item);
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final preds = item['predictions'] as List<dynamic>? ?? [];
    final pred = preds.isNotEmpty ? preds.first as Map<String, dynamic> : null;

    final int effLabel = (pred?['koreksi_petugas'] as int?) ?? (pred?['label_biner'] as int?) ?? 0;
    final bool isPerlu = effLabel == 1;
    final String prioritas = pred?['prioritas'] as String? ?? 'Baik';
    final double? prob = (pred?['prob_perlu_pemeliharaan'] as num?)?.toDouble();
    final num harga = item['harga'] as num? ?? 0;

    Color badgeColor;
    String badgeText;

    if (pred?['koreksi_petugas'] == 0) {
      badgeText = 'Kondisi Baik (Selesai)';
      badgeColor = const Color(0xFF047857);
    } else if (pred?['koreksi_petugas'] == 1) {
      badgeText = 'Perlu Servis (Koreksi)';
      badgeColor = const Color(0xFFBE123C);
    } else if (isPerlu) {
      badgeText = 'Perlu Pemeliharaan';
      badgeColor = prioritas == 'Tinggi' ? const Color(0xFFBE123C) : const Color(0xFFD97706);
    } else {
      badgeText = 'Kondisi Baik';
      badgeColor = const Color(0xFF047857);
    }

    return InkWell(
      onTap: () {
        final invId = item['id'] as String;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(inventoryId: invId),
          ),
        ).then((_) {
          // Segarkan data saat kembali dari halaman detail jika ada perubahan
          if (_selectedRoomId != null) _loadItems(_selectedRoomId!);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.02), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Kategori pill & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '${item['kategori']}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Material ${item['bahan']}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Nama Barang & Tombol Panah
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item['nama_barang'] ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 6),

            // Row 3: Meta & Nilai Aset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tahun ${item['tahun_pembelian']} • ${item['jumlah']} unit',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                Text(
                  _formatCurrency(harga),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),

            // Row 4: Probabilitas bar jika ada prediksi
            if (prob != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: prob.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          prob > 0.8
                              ? const Color(0xFFE11D48)
                              : prob > 0.417
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Risiko: ${(prob * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: prob > 0.417 ? const Color(0xFFBE123C) : const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
