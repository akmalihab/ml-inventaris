class Room {
  final int id;
  final String nama;

  Room({required this.id, required this.nama});

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as int,
      nama: json['nama'] as String? ?? 'Ruangan ${json['id']}',
    );
  }
}
