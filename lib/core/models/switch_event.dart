class SwitchEvent {
  final String id;
  String memberId;
  DateTime startTime;
  DateTime? endTime;
  String? notes;
  List<String> cofronterIds;

  SwitchEvent({
    required this.id,
    required this.memberId,
    required this.startTime,
    this.endTime,
    this.notes,
    List<String>? cofronterIds,
  }) : cofronterIds = cofronterIds ?? [];

  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  bool get isActive => endTime == null;

  List<String> get allFronterIds => [memberId, ...cofronterIds];

  SwitchEvent copyWith({
    String? memberId,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
    List<String>? cofronterIds,
    bool clearEndTime = false,
  }) {
    return SwitchEvent(
      id: id,
      memberId: memberId ?? this.memberId,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      notes: notes ?? this.notes,
      cofronterIds: cofronterIds ?? List.from(this.cofronterIds),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'memberId': memberId,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime?.millisecondsSinceEpoch,
        'notes': notes,
        'cofronterIds': cofronterIds.join(','),
      };

  factory SwitchEvent.fromMap(Map<String, dynamic> map) => SwitchEvent(
        id: map['id'],
        memberId: map['memberId'],
        startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] is int
            ? map['startTime']
            : int.parse(map['startTime'].toString())),
        endTime: map['endTime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['endTime'] is int
                ? map['endTime']
                : int.parse(map['endTime'].toString()))
            : null,
        notes: map['notes'],
        cofronterIds: map['cofronterIds'] != null &&
                (map['cofronterIds'] as String).isNotEmpty
            ? (map['cofronterIds'] as String).split(',')
            : [],
      );
}
