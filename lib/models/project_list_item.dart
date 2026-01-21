/// Simple project item for listing projects
class ProjectListItem {
  final String id;
  final String name;
  final String? slug;
  final String? description;

  ProjectListItem({
    required this.id,
    required this.name,
    this.slug,
    this.description,
  });

  factory ProjectListItem.fromJson(Map<String, dynamic> json) {
    return ProjectListItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Project',
      slug: json['slug'] as String?,
      description: json['description'] as String?,
    );
  }
}
