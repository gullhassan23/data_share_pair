class FileMeta {
  final String name;
  final int size;
  final String type;

  FileMeta({required this.name, required this.size, required this.type});

  factory FileMeta.fromJson(Map<String, dynamic> json) => FileMeta(
    name: json['name'] as String,
    size: json['size'] as int,
    type: json['type'] as String,
  );

  Map<String, dynamic> toJson() => {'name': name, 'size': size, 'type': type};
}
