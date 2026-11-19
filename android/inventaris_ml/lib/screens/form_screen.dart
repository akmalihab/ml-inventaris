import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';
import 'item_detail_screen.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _supabaseService = SupabaseService();

  List<Room> _rooms = [];
  bool _isLoadingRooms = true;
  bool _isSubmitting = false;

  int? _selectedRoomId;
  final _namaController = TextEditingController();
  final _jumlahController = TextEditingController(text: '1');
  final _tahunController = TextEditingController(text: '2020');
  final _hargaController = TextEditingController();

  String _selectedBahan = 'Besi';
  String _selectedKategori = 'Elektronik';
  String? _selectedTriwulan;

  final List<String> _bahanList = [
    'Besi',
    'Kayu',
    'Plastik',
    'Kain',
    'Kaca',
    'Campuran',
    'Karet',
    'Aluminium',
    'Stainless Steel',
  ];

  final List<String> _kategoriList = [
    'Elektronik',
    'Furnitur',
    'Pelengkap',
  ];

  final List<String> _triwulanList = [
    'TW 1',
    'TW 2',
    'TW 3',
    'TW 4',
  ];

  @override
  void initState() {
    super.initState();
    _applyCurrentPeriod();
    _loadRooms();
  }

  void _applyCurrentPeriod() {
    final now = DateTime.now();
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    _tahunController.text = now.year.toString();
    _selectedTriwulan = 'TW $currentQuarter';
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _supabaseService.getRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          if (_rooms.isNotEmpty) {
            _selectedRoomId = _rooms.any((r) => r.id == 1) ? 1 : _rooms.first.id;
          }
          _isLoadingRooms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat daftar ruangan: $e')),
        );
      }
    }
  }

  void _applyBenchmarkPreset() {
    setState(() {
      _namaController.text = 'AC Panasonic 2 PK';
      _selectedBahan = 'Besi';
      _selectedKategori = 'Elektronik';
      _tahunController.text = '2013';
      _jumlahController.text = '1';
      _hargaController.text = '10845230';
      _selectedTriwulan = 'TW 2';
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih ruangan terlebih dahulu')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final nama = _namaController.text.trim();
      final tahun = int.parse(_tahunController.text.trim());
      final jumlah = int.parse(_jumlahController.text.trim());
      final harga = double.parse(_hargaController.text.trim());

      final room = _rooms.firstWhere((r) => r.id == _selectedRoomId);

      // 1. Panggil FastAPI /predict
      final predResult = await _apiService.predictItem(
        namaBarang: nama,
        namaRuangan: room.nama,
        bahan: _selectedBahan,
        kategori: _selectedKategori,
        tahunPembelian: tahun,
        jumlah: jumlah,
        harga: harga,
        triwulan: _selectedTriwulan,
      );

      // 2. Simpan ke Supabase (inventories + predictions)
      final ids = await _supabaseService.saveInventoryAndPrediction(
        roomId: _selectedRoomId!,
        namaBarang: nama,
        bahan: _selectedBahan,
        kategori: _selectedKategori,
        tahunPembelian: tahun,
        jumlah: jumlah,
        harga: harga,
        triwulan: _selectedTriwulan,
        prediction: predResult,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        // 3. Navigasi langsung ke layar Detail Barang & Analisis SHAP
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(
              inventoryId: ids['inventory_id']!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Gagal Memproses Prediksi'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Input Aset Non-Medis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              'Klasifikasi XGBoost & Rekomendasi AI',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _applyBenchmarkPreset,
              icon: const Icon(Icons.flash_on, size: 15, color: Color(0xFFF59E0B)),
              label: const Text(
                'Preset AC',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B).withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFF59E0B), width: 0.8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingRooms
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner Status Periode Timezone Otomatis
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF047857)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Periode Aktif: Tahun ${DateTime.now().year} • $_selectedTriwulan',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857)),
                                ),
                                Text(
                                  'Otomatis disinkronkan dengan zona waktu sistem (${DateTime.now().timeZoneName})',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() => _applyCurrentPeriod());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tahun & Triwulan disetel ke waktu sistem saat ini.'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                              ),
                              child: const Text('Reset Waktu', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kartu Ruangan & Info Dasar
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lokasi Penempatan',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: _selectedRoomId,
                              decoration: const InputDecoration(
                                labelText: 'Ruang Rawat Inap',
                                prefixIcon: Icon(Icons.meeting_room_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: _rooms.map((r) {
                                return DropdownMenuItem<int>(
                                  value: r.id,
                                  child: Text('${r.nama} (ID: ${r.id})'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedRoomId = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Spesifikasi Barang
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spesifikasi Barang',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _namaController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Barang *',
                                hintText: 'Misal: AC Panasonic 2 PK, Ranjang Pasien',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Nama barang wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedKategori,
                                    decoration: const InputDecoration(
                                      labelText: 'Kategori',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _kategoriList.map((k) {
                                      return DropdownMenuItem(value: k, child: Text(k));
                                    }).toList(),
                                    onChanged: (v) => setState(() => _selectedKategori = v ?? 'Elektronik'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedBahan,
                                    decoration: const InputDecoration(
                                      labelText: 'Bahan Material',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _bahanList.map((b) {
                                      return DropdownMenuItem(value: b, child: Text(b));
                                    }).toList(),
                                    onChanged: (v) => setState(() => _selectedBahan = v ?? 'Besi'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _tahunController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Tahun Beli *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (val) {
                                      final y = int.tryParse(val ?? '');
                                      if (y == null || y < 1990 || y > DateTime.now().year) {
                                        return 'Tahun tidak valid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _jumlahController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Jumlah Unit *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (val) {
                                      final j = int.tryParse(val ?? '');
                                      if (j == null || j <= 0) return 'Minimal 1';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _hargaController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Harga Perolehan (Rp) *',
                                hintText: 'Contoh: 10845230',
                                prefixIcon: Icon(Icons.payments_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                final h = double.tryParse(val ?? '');
                                if (h == null || h <= 0) return 'Masukkan harga yang valid';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              value: _selectedTriwulan,
                              decoration: const InputDecoration(
                                labelText: 'Triwulan Pembelian (Opsional)',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Tidak ditentukan')),
                                ..._triwulanList.map((tw) => DropdownMenuItem(value: tw, child: Text(tw))),
                              ],
                              onChanged: (v) => setState(() => _selectedTriwulan = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Submit Prediksi AI
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.psychology_outlined),
                        label: Text(
                          _isSubmitting ? 'Memproses Inferensi XGBoost…' : 'Prediksi Kondisi & Prioritas AI',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
