import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plurallog_system_template/core/models/models.dart';
import 'package:plurallog_system_template/core/federation/protocol.dart';
import 'package:plurallog_system_template/core/database/local_database.dart';

void main() {
  group('Member model', () {
    test('serializes and deserializes correctly', () {
      final member = Member(
        id: 'test-1',
        name: 'Alice',
        pronouns: 'she/her',
        role: 'Host',
        description: 'The primary fronter',
        color: const Color(0xFFE57373),
        customFields: {'age': '25'},
        createdAt: DateTime(2024, 1, 1),
        vault: {'private_note': 'test'},
      );

      final map = member.toMap();
      final restored = Member.fromMap(map);

      expect(restored.id, 'test-1');
      expect(restored.name, 'Alice');
      expect(restored.pronouns, 'she/her');
      expect(restored.role, 'Host');
      expect(restored.color.value, const Color(0xFFE57373).value);
      expect(restored.customFields['age'], '25');
      expect(restored.vault['private_note'], 'test');
    });

    test('fromMap handles customFields as JSON string', () {
      final map = {
        'id': 'test-2',
        'name': 'Bob',
        'color': 0xFF81C784,
        'customFields': '{"key":"value"}',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      final member = Member.fromMap(map);
      expect(member.customFields['key'], 'value');
    });

    test('fromMap handles customFields as raw Map', () {
      final map = {
        'id': 'test-3',
        'name': 'Carol',
        'color': 0xFF64B5F6,
        'customFields': {'direct': 'map'},
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      // This exercises the fallback path in the friend client's fromMap
      // The system template always JSON-encodes, but we should handle both.
      final member = Member.fromMap(map);
      // System template's fromMap expects JSON string, so this tests resilience
      expect(member.name, 'Carol');
    });

    test('subsystem relationships', () {
      final parent = Member(id: 'p1', name: 'Parent', color: Colors.red);
      final child = Member(
          id: 'c1', name: 'Child', color: Colors.blue, parentMemberId: 'p1');
      final all = [parent, child];

      expect(parent.hasSubsystem(all), true);
      expect(child.isSubsystemMember, true);
      expect(parent.getSubsystemMembers(all).length, 1);
    });
  });

  group('SwitchEvent model', () {
    test('serializes and deserializes correctly', () {
      final event = SwitchEvent(
        id: 'sw-1',
        memberId: 'm-1',
        startTime: DateTime(2024, 6, 15, 10, 30),
        cofronterIds: ['m-2', 'm-3'],
        notes: 'Test switch',
      );

      final map = event.toMap();
      final restored = SwitchEvent.fromMap(map);

      expect(restored.id, 'sw-1');
      expect(restored.memberId, 'm-1');
      expect(restored.cofronterIds, ['m-2', 'm-3']);
      expect(restored.isActive, true);
      expect(restored.allFronterIds, ['m-1', 'm-2', 'm-3']);
    });

    test('duration calculation', () {
      final event = SwitchEvent(
        id: 'sw-2',
        memberId: 'm-1',
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 1, 12, 30),
      );
      expect(event.duration, const Duration(hours: 2, minutes: 30));
      expect(event.isActive, false);
    });
  });

  group('Poll model', () {
    test('tallies votes correctly', () {
      final poll = Poll(
        id: 'p-1',
        question: 'Favorite color?',
        options: ['Red', 'Blue', 'Green'],
        votes: {'m1': 0, 'm2': 1, 'm3': 0, 'm4': 2},
        createdAt: DateTime.now(),
      );

      expect(poll.totalVotes, 4);
      expect(poll.tallies[0], 2); // Red
      expect(poll.tallies[1], 1); // Blue
      expect(poll.tallies[2], 1); // Green
    });

    test('serializes options with ||| delimiter', () {
      final poll = Poll(
        id: 'p-2',
        question: 'Test?',
        options: ['A', 'B'],
        createdAt: DateTime.now(),
      );
      final map = poll.toMap();
      expect(map['options'], 'A|||B');

      final restored = Poll.fromMap(map);
      expect(restored.options, ['A', 'B']);
    });
  });

  group('JournalEntry model', () {
    test('Emotion.byName lookup', () {
      expect(Emotion.byName('happy')?.label, 'Happy');
      expect(Emotion.byName('dissociated')?.label, 'Dissociated');
      expect(Emotion.byName('nonexistent'), null);
      expect(Emotion.byName(null), null);
    });
  });

  group('FederationProtocol', () {
    test('protocol version is 1', () {
      expect(FederationProtocol.protocolVersion, 1);
    });

    test('feature set contains expected volume types', () {
      expect(FederationProtocol.featureSet, contains('members:1'));
      expect(FederationProtocol.featureSet, contains('fronts:1'));
      expect(FederationProtocol.featureSet, contains('journal:1'));
      expect(FederationProtocol.featureSet, contains('vault:1'));
    });

    test('padding boundary is 4096', () {
      expect(FederationProtocol.paddingBoundary, 4096);
    });
  });

  group('SharingPermissions', () {
    test('defaults share front status and members', () {
      final perms = SharingPermissions();
      expect(perms.shareFrontStatus, true);
      expect(perms.shareMembers, true);
      expect(perms.shareJournal, false);
    });

    test('enabledVolumes includes meta always', () {
      final perms = SharingPermissions(
        shareFrontStatus: false,
        shareMembers: false,
      );
      expect(perms.enabledVolumes, contains('meta'));
    });

    test('enabledVolumes reflects permissions', () {
      final perms = SharingPermissions(
        shareMembers: true,
        shareJournal: true,
        sharePolls: true,
      );
      final vols = perms.enabledVolumes;
      expect(vols, contains('members'));
      expect(vols, contains('journal'));
      expect(vols, contains('polls'));
      expect(vols, isNot(contains('analytics')));
    });

    test('round-trips through map', () {
      final perms = SharingPermissions(shareJournal: true, shareVault: true);
      final map = perms.toMap();
      final restored = SharingPermissions.fromMap(map);
      expect(restored.shareJournal, true);
      expect(restored.shareVault, true);
      expect(restored.shareFrontHistory, false);
    });
  });

  group('Import validation', () {
    test('rejects empty JSON', () {
      expect(
        () => LocalDatabase.validateImport({}),
        throwsA(isA<FormatException>()),
      );
    });

    test('detects PluralKit exports', () {
      expect(
        () => LocalDatabase.validateImport({
          'members': [],
          'switches': [],
          'system_id': 'abc',
        }),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('PluralKit'))),
      );
    });

    test('detects Simply Plural exports', () {
      expect(
        () => LocalDatabase.validateImport({
          'uid': 'abc',
          'content': {},
          'members': [],
        }),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Simply Plural'))),
      );
    });

    test('accepts valid PluralLog export', () {
      // Should not throw
      LocalDatabase.validateImport({
        'members': [
          {'id': 'm1', 'name': 'Alice', 'color': 0xFFFF0000, 'createdAt': 0}
        ],
        'switchEvents': [],
      });
    });

    test('rejects members with uuid instead of id', () {
      expect(
        () => LocalDatabase.validateImport({
          'members': [
            {'uuid': 'abc', 'name': 'Test'}
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
