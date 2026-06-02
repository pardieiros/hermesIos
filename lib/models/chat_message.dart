enum MessageRole { user, assistant, system, tool }
enum MessageStatus { pending, streaming, complete, error }

class ToolCallEntry {
  final String id;
  final String name;
  String input;
  String? output;
  bool isRunning;
  bool isComplete;

  ToolCallEntry({
    required this.id,
    required this.name,
    required this.input,
    this.output,
    this.isRunning = false,
    this.isComplete = false,
  });
}

class ChatMessage {
  final String id;
  final MessageRole role;
  String text;
  String? thinking;
  MessageStatus status;
  DateTime timestamp;
  List<ToolCallEntry> toolCalls;
  String? statusText;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.thinking,
    this.status = MessageStatus.complete,
    DateTime? timestamp,
    List<ToolCallEntry>? toolCalls,
    this.statusText,
  })  : timestamp = timestamp ?? DateTime.now(),
        toolCalls = toolCalls ?? [];

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isStreaming => status == MessageStatus.streaming;
}
