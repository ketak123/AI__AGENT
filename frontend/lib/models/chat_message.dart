class ChatMessage {
  final String sender;
  final String text;
  final String agentType;
  final DateTime timestamp;
  final List<String> suggestions;

  ChatMessage({
    required this.sender,
    required this.text,
    this.agentType = 'ai_manager',
    DateTime? timestamp,
    this.suggestions = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => sender.toLowerCase() == 'user';
}
