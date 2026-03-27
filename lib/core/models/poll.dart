class Poll {
  final String id;
  final String question;
  final List<String> options;
  final Map<String, int> votes; // memberId -> optionIndex
  final DateTime createdAt;
  bool closed;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    Map<String, int>? votes,
    required this.createdAt,
    this.closed = false,
  }) : votes = votes ?? {};

  Map<int, int> get tallies {
    final result = <int, int>{};
    for (int i = 0; i < options.length; i++) {
      result[i] = 0;
    }
    for (final v in votes.values) {
      result[v] = (result[v] ?? 0) + 1;
    }
    return result;
  }

  int get totalVotes => votes.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'options': options.join('|||'),
        'votes': votes.entries.map((e) => '${e.key}:${e.value}').join(','),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'closed': closed ? 1 : 0,
      };

  factory Poll.fromMap(Map<String, dynamic> map) {
    final votesStr = map['votes'] as String? ?? '';
    final votes = <String, int>{};
    if (votesStr.isNotEmpty) {
      for (final pair in votesStr.split(',')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          votes[parts[0]] = int.tryParse(parts[1]) ?? 0;
        }
      }
    }
    return Poll(
      id: map['id'],
      question: map['question'],
      options: (map['options'] as String).split('|||'),
      votes: votes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] is int
          ? map['createdAt']
          : int.parse(map['createdAt'].toString())),
      closed: map['closed'] == 1 || map['closed'] == true,
    );
  }
}
