enum MessageRole { user, assistant }

class Message {
  final String text;
  final MessageRole role;
  final bool usedRag;
  final List<String> sources;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.role,
    this.usedRag = false,
    this.sources = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}