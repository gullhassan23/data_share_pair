class FileMeta {
  final String name;
  final int size;
  final String type;

  FileMeta({required this.name, required this.size, required this.type});

  factory FileMeta.fromJson(Map<String, dynamic> json) => FileMeta(
    name: json['name'] as String? ?? '',
    size: json['size'] is int
        ? json['size'] as int
        : (json['size'] as num?)?.toInt() ?? 0,
    type: json['type'] as String? ?? 'file',
  );

  Map<String, dynamic> toJson() => {'name': name, 'size': size, 'type': type};
}
