class JournalEntry {
  final String id;
  final String authorId;
  final String text;
  final String? emotion;
  final DateTime timestamp;
  List<String> tags;
  bool hidden;

  JournalEntry({
    required this.id,
    required this.authorId,
    required this.text,
    this.emotion,
    required this.timestamp,
    List<String>? tags,
    this.hidden = false,
  }) : tags = tags ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'authorId': authorId,
        'text': text,
        'emotion': emotion,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'tags': tags.join(','),
        'hidden': hidden ? 1 : 0,
      };

  factory JournalEntry.fromMap(Map<String, dynamic> map) => JournalEntry(
        id: map['id'],
        authorId: map['authorId'],
        text: map['text'],
        emotion: map['emotion'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] is int
            ? map['timestamp']
            : int.parse(map['timestamp'].toString())),
        tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
            ? (map['tags'] as String).split(',')
            : [],
        hidden: map['hidden'] == 1,
      );
}

/// Standard emotion options used across the PluralLog ecosystem.
/// My general recommendation would be that if you want to extend 
/// these, then extend frm the base emotions given, and have a way 
/// to mapo them back to the official set on export. You can include
/// an additional channel in exports (custom key, ie) to store the
/// correct data if needed. 
/// 
/// We won't enforce that of course, but the idea is to keep save 
/// compatability between clients. The reason the set is so simple
/// is for easy review/analysis.
/// 
class Emotion {
  final String name;
  final String label;
  final int colorValue;

  const Emotion({
    required this.name,
    required this.label,
    required this.colorValue,
  });

  static const List<Emotion> all = [
    Emotion(name: 'happy', label: 'Happy', colorValue: 0xFF7ec96a),
    Emotion(name: 'neutral', label: 'Neutral', colorValue: 0xFFa0adb8),
    Emotion(name: 'sad', label: 'Sad', colorValue: 0xFF6b8fd4),
    Emotion(name: 'anxious', label: 'Anxious', colorValue: 0xFFd4a84b),
    Emotion(name: 'angry', label: 'Angry', colorValue: 0xFFd46b6b),
    Emotion(name: 'dissociated', label: 'Dissociated', colorValue: 0xFF9b8ec4),
  ];

  static Emotion? byName(String? name) {
    if (name == null) return null;
    try {
      return all.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }
}
