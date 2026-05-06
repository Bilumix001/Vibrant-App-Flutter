class ConversationModel {
  final int id;
  final String title;
  final String preview;
  final DateTime updatedAt;

  const ConversationModel({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      ConversationModel(
        id:        json['id'],
        title:     json['title'] ?? '',
        preview:   json['preview'] ?? '',
        updatedAt: DateTime.parse(json['updated_at']),
      );
}