class ChatChannel {
  final String id;
  String name;

  ChatChannel({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
      };

  factory ChatChannel.fromMap(Map<String, dynamic> map) => ChatChannel(
        id: map['id'],
        name: map['name'],
      );
}

class ChatMessage {
  final String id;
  final String channelId;
  final String authorId;
  final String text;
  final DateTime timestamp;
  bool pinned;

  ChatMessage({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.text,
    required this.timestamp,
    this.pinned = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'channelId': channelId,
        'authorId': authorId,
        'text': text,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'pinned': pinned ? 1 : 0,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'],
        channelId: map['channelId'],
        authorId: map['authorId'],
        text: map['text'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
        pinned: map['pinned'] == 1,
      );
}
