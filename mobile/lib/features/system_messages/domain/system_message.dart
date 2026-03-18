class SystemMessage {
  final String id;
  final DateTime createdAt;
  final String title;
  final String body;

  const SystemMessage({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.body,
  });

  factory SystemMessage.fromJson(Map<String, dynamic> json) {
    return SystemMessage(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
    );
  }
}

