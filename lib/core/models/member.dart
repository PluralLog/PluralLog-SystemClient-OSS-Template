import 'dart:convert';
import 'package:flutter/material.dart';

class Member {
  final String id;
  String name;
  String? pronouns;
  String? role;
  String? description;
  Color color;
  String? profileMarkdown;
  Map<String, String> customFields;
  String? parentMemberId;
  DateTime createdAt;
  Map<String, String> vault;

  Member({
    required this.id,
    required this.name,
    this.pronouns,
    this.role,
    this.description,
    required this.color,
    this.profileMarkdown,
    Map<String, String>? customFields,
    this.parentMemberId,
    DateTime? createdAt,
    Map<String, String>? vault,
  })  : customFields = customFields ?? {},
        createdAt = createdAt ?? DateTime.now(),
        vault = vault ?? {};

  String get displayInitial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  bool hasSubsystem(List<Member> allMembers) =>
      allMembers.any((m) => m.parentMemberId == id);

  List<Member> getSubsystemMembers(List<Member> allMembers) =>
      allMembers.where((m) => m.parentMemberId == id).toList();

  bool get isSubsystemMember => parentMemberId != null;

  Member copyWith({
    String? name,
    String? pronouns,
    String? role,
    String? description,
    Color? color,
    String? profileMarkdown,
    Map<String, String>? customFields,
    String? parentMemberId,
    bool clearParent = false,
    Map<String, String>? vault,
  }) {
    return Member(
      id: id,
      name: name ?? this.name,
      pronouns: pronouns ?? this.pronouns,
      role: role ?? this.role,
      description: description ?? this.description,
      color: color ?? this.color,
      profileMarkdown: profileMarkdown ?? this.profileMarkdown,
      customFields: customFields ?? Map.from(this.customFields),
      parentMemberId:
          clearParent ? null : (parentMemberId ?? this.parentMemberId),
      createdAt: createdAt,
      vault: vault ?? Map.from(this.vault),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'pronouns': pronouns,
        'role': role,
        'description': description,
        'color': color.value,
        'profileMarkdown': profileMarkdown,
        'customFields': jsonEncode(customFields),
        'parentMemberId': parentMemberId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'vault': jsonEncode(vault),
      };

  factory Member.fromMap(Map<String, dynamic> map) {
    Map<String, String> fields = {};
    if (map['customFields'] != null) {
      try {
        final decoded = map['customFields'] is String
            ? jsonDecode(map['customFields'] as String)
            : map['customFields'];
        if (decoded is Map) {
          fields = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }
    Map<String, String> vaultData = {};
    if (map['vault'] != null) {
      try {
        final decoded = map['vault'] is String
            ? jsonDecode(map['vault'] as String)
            : map['vault'];
        if (decoded is Map) {
          vaultData =
              decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }
    return Member(
      id: map['id'],
      name: map['name'],
      pronouns: map['pronouns'],
      role: map['role'],
      description: map['description'],
      color: Color(map['color'] is int
          ? map['color']
          : int.parse(map['color'].toString())),
      profileMarkdown: map['profileMarkdown'],
      customFields: fields,
      parentMemberId: map['parentMemberId'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] is int
          ? map['createdAt']
          : int.parse(map['createdAt'].toString())),
      vault: vaultData,
    );
  }

  static Member unknown() => Member(
        id: 'unknown',
        name: 'Unknown',
        color: Colors.grey,
        description: 'An unknown or unrecognized member',
      );
}
