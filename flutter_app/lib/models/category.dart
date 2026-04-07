class Category {
  final String id;
  final String name;
  final String slug;
  final String? icon;
  final String? description;
  final List<Category>? children;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.description,
    this.children,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      icon: json['icon'],
      description: json['description'],
      children: json['children'] != null
          ? (json['children'] as List)
              .map((e) => Category.fromJson(e))
              .toList()
          : null,
    );
  }
}
