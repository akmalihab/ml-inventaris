import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'item_detail_screen.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'Semua'; // 'Semua', 'Antre', 'Dikerjakan', 'Selesai'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tasks = await _supabaseService.getMaintenanceTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String taskId, String newStatus, String? predictionId) async {
    try {
      await _supabaseService.updateTaskStatus(taskId, newStatus, predictionId: predictionId);
      _fetchTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status tugas berhasil diubah ke: $newStatus'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status: $e'),
            backgroundColor: const Color(0xFFF43F5E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Antre':
        return const Color(0xFFD97706); // amber
      case 'Dikerjakan':
        return const Color(0xFF2563EB); // blue
      case 'Selesai':
        return const Color(0xFF047857); // emerald
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _tasks.where((t) {
      final status = t['status'] as String? ?? '';
      if (_filterStatus != 'Semua' && status != _filterStatus) return false;

      final pred = t['predictions'] as Map<String, dynamic>?;
      final inv = pred?['inventories'] as Map<String, dynamic>?;
      final nama = (inv?['nama_barang'] as String? ?? '').toLowerCase();
      final ruang = (inv?['rooms']?['nama'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();

      if (q.isNotEmpty && !nama.contains(q) && !ruang.contains(q)) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Antrean Tugas Pemeliharaan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Tindak Lanjut & Perbaikan Lapangan',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTasks,
            tooltip: 'Segarkan',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama aset atau ruangan…',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('Semua Status', 'Semua'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Antre', 'Antre'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Dikerjakan', 'Dikerjakan'),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Selesai', 'Selesai'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List Tasks
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 12)),
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('Tidak ada antrean tugas yang sesuai.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) {
                              final task = filtered[idx];
                              return _buildTaskCard(task);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return InkWell(
      onTap: () => setState(() => _filterStatus = value),
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

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final taskId = task['id'] as String;
    final currentStatus = task['status'] as String? ?? 'Antre';
    final pred = task['predictions'] as Map<String, dynamic>?;
    final predId = pred?['id'] as String?;
    final inv = pred?['inventories'] as Map<String, dynamic>?;
    final invId = inv?['id'] as String?;
    final roomName = inv?['rooms']?['nama'] as String? ?? '-';
    final statusColor = _getStatusColor(currentStatus);
    final prioritas = pred?['prioritas'] as String? ?? 'Baik';
    final double? prob = (pred?['prob_perlu_pemeliharaan'] as num?)?.toDouble();

    return Container(
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
          // Header: Room badge & Status Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Text(
                  'Ruang $roomName',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),

              // Status Dropdown Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentStatus,
                    icon: Icon(Icons.arrow_drop_down, size: 16, color: statusColor),
                    isDense: true,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    items: const [
                      DropdownMenuItem(value: 'Antre', child: Text('Antre')),
                      DropdownMenuItem(value: 'Dikerjakan', child: Text('Dikerjakan')),
                      DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                    ],
                    onChanged: (newVal) {
                      if (newVal != null && newVal != currentStatus) {
                        _updateStatus(taskId, newVal, predId);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nama Barang
          Text(
            inv?['nama_barang'] ?? '-',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),

          // Info Kategori & Prioritas
          Row(
            children: [
              Text(
                '${inv?['kategori']} • Material ${inv?['bahan']}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              if (prob != null)
                Text(
                  'Risiko ${(prob * 100).toStringAsFixed(0)}% ($prioritas)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: prioritas == 'Tinggi' ? const Color(0xFFBE123C) : const Color(0xFFD97706),
                  ),
                ),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),

          // Footer: Action ke Detail Barang
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: ${taskId.substring(0, 8)}…',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
              ),
              if (invId != null)
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(inventoryId: invId),
                      ),
                    ).then((_) => _fetchTasks());
                  },
                  child: const Row(
                    children: [
                      Text(
                        'Lihat Detail & SHAP',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
