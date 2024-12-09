// tag.dart
class Tag {
  final String id;
  final String name;
  final String icon;
  final String category;

  Tag({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
  });

  factory Tag.fromMap(Map<String, dynamic> data, String documentId) {
    return Tag(
      id: documentId,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '',
      category: data['category'] ?? 'Other',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'category': category,
    };
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      category: json['category'] ?? 'Other',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'category': category,
    };
  }
}
