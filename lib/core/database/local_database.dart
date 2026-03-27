import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';

/// Simple local JSON file-based database.
/// All data stays on-device. No server, no accounts.
///
/// This is the PluralLog local storage format. The entire database is a single
/// JSON object persisted to disk. See EXPORT_FORMAT.md for the full schema.
class LocalDatabase {
  static LocalDatabase? _instance;
  static LocalDatabase get instance => _instance ??= LocalDatabase._();
  LocalDatabase._();

  /// Constructor for testing — accepts an injectable data map.
  @visibleForTesting
  LocalDatabase.forTesting(this._data) : _initialized = true, _dbPath = '';

  late String _dbPath;
  Map<String, dynamic> _data = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationSupportDirectory();
    _dbPath = p.join(dir.path, 'plurallog_data.json');
    await _load();
    _initialized = true;
  }

  Future<void> _load() async {
    final file = File(_dbPath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        _data = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('DB load error: $e');
        _data = {};
      }
    }
  }

  Future<void> _save() async {
    if (_dbPath.isEmpty) return; // Testing mode
    final file = File(_dbPath);
    await file.writeAsString(jsonEncode(_data));
  }

  // -- System Config --

  Future<SystemConfig> getConfig() async {
    final raw = _data['config'];
    if (raw == null) return SystemConfig();
    return SystemConfig.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> saveConfig(SystemConfig config) async {
    _data['config'] = config.toMap();
    await _save();
  }

  // -- Members --

  Future<List<Member>> getMembers() async {
    final raw = _data['members'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((e) => Member.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveMembers(List<Member> members) async {
    _data['members'] = members.map((m) => m.toMap()).toList();
    await _save();
  }

  Future<void> addMember(Member member) async {
    final members = await getMembers();
    members.add(member);
    await saveMembers(members);
  }

  Future<void> updateMember(Member member) async {
    final members = await getMembers();
    final idx = members.indexWhere((m) => m.id == member.id);
    if (idx >= 0) {
      members[idx] = member;
      await saveMembers(members);
    }
  }

  Future<void> deleteMember(String id) async {
    final members = await getMembers();
    members.removeWhere((m) => m.id == id);
    for (final m in members) {
      if (m.parentMemberId == id) m.parentMemberId = null;
    }
    await saveMembers(members);

    final switches = await getSwitchEvents();
    switches.removeWhere((s) => s.memberId == id);
    for (final s in switches) {
      s.cofronterIds.remove(id);
    }
    await saveSwitchEvents(switches);

    final messages = await getMessages();
    messages.removeWhere((m) => m.authorId == id);
    await saveMessages(messages);

    final journal = await getJournalEntries();
    journal.removeWhere((j) => j.authorId == id);
    await saveJournalEntries(journal);

    final polls = await getPolls();
    for (final p in polls) {
      p.votes.remove(id);
    }
    await savePolls(polls);
  }

  // -- Switch Events --

  Future<List<SwitchEvent>> getSwitchEvents() async {
    final raw = _data['switchEvents'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((e) => SwitchEvent.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveSwitchEvents(List<SwitchEvent> events) async {
    _data['switchEvents'] = events.map((e) => e.toMap()).toList();
    await _save();
  }

  Future<void> addSwitchEvent(SwitchEvent event) async {
    final events = await getSwitchEvents();
    for (final e in events) {
      if (e.endTime == null) e.endTime = event.startTime;
    }
    events.add(event);
    await saveSwitchEvents(events);
  }

  Future<void> updateSwitchEvent(SwitchEvent event) async {
    final events = await getSwitchEvents();
    final idx = events.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      events[idx] = event;
      await saveSwitchEvents(events);
    }
  }

  Future<void> deleteSwitchEvent(String id) async {
    final events = await getSwitchEvents();
    events.removeWhere((e) => e.id == id);
    await saveSwitchEvents(events);
  }

  Future<SwitchEvent?> getActiveFront() async {
    final events = await getSwitchEvents();
    try {
      return events.lastWhere((e) => e.isActive);
    } catch (_) {
      return null;
    }
  }

  // -- Chat Channels --

  Future<List<ChatChannel>> getChannels() async {
    final raw = _data['channels'] as List<dynamic>?;
    if (raw == null) {
      final defaults = [
        ChatChannel(id: 'ch_general', name: 'general'),
        ChatChannel(id: 'ch_planning', name: 'planning'),
      ];
      await saveChannels(defaults);
      return defaults;
    }
    return raw
        .map((e) => ChatChannel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveChannels(List<ChatChannel> channels) async {
    _data['channels'] = channels.map((c) => c.toMap()).toList();
    await _save();
  }

  // -- Chat Messages --

  Future<List<ChatMessage>> getMessages({String? channelId}) async {
    final raw = _data['messages'] as List<dynamic>?;
    if (raw == null) return [];
    var messages = raw
        .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    if (channelId != null) {
      messages = messages.where((m) => m.channelId == channelId).toList();
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  Future<void> saveMessages(List<ChatMessage> messages) async {
    _data['messages'] = messages.map((m) => m.toMap()).toList();
    await _save();
  }

  Future<void> addMessage(ChatMessage message) async {
    final all = await getMessages();
    all.add(message);
    await saveMessages(all);
  }

  Future<void> deleteMessage(String id) async {
    final all = await getMessages();
    all.removeWhere((m) => m.id == id);
    await saveMessages(all);
  }

  // -- Journal --

  Future<List<JournalEntry>> getJournalEntries() async {
    final raw = _data['journal'] as List<dynamic>?;
    if (raw == null) return [];
    final entries = raw
        .map((e) => JournalEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  Future<void> saveJournalEntries(List<JournalEntry> entries) async {
    _data['journal'] = entries.map((e) => e.toMap()).toList();
    await _save();
  }

  Future<void> addJournalEntry(JournalEntry entry) async {
    final entries = await getJournalEntries();
    entries.add(entry);
    await saveJournalEntries(entries);
  }

  Future<void> deleteJournalEntry(String id) async {
    final entries = await getJournalEntries();
    entries.removeWhere((e) => e.id == id);
    await saveJournalEntries(entries);
  }

  // -- Polls --

  Future<List<Poll>> getPolls() async {
    final raw = _data['polls'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((e) => Poll.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> savePolls(List<Poll> polls) async {
    _data['polls'] = polls.map((p) => p.toMap()).toList();
    await _save();
  }

  Future<void> addPoll(Poll poll) async {
    final polls = await getPolls();
    polls.add(poll);
    await savePolls(polls);
  }

  Future<void> updatePoll(Poll poll) async {
    final polls = await getPolls();
    final idx = polls.indexWhere((p) => p.id == poll.id);
    if (idx >= 0) {
      polls[idx] = poll;
      await savePolls(polls);
    }
  }

  // -- Custom Field Definitions --

  Future<List<CustomFieldDef>> getCustomFieldDefs() async {
    final raw = _data['customFieldDefs'] as List<dynamic>?;
    if (raw == null) return [];
    return raw
        .map((e) => CustomFieldDef.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> saveCustomFieldDefs(List<CustomFieldDef> defs) async {
    _data['customFieldDefs'] = defs.map((d) => d.toMap()).toList();
    await _save();
  }

  // -- Danger zone --

  Future<void> deleteAllData() async {
    _data = {};
    await _save();
  }

  Future<String> exportData() async {
    return const JsonEncoder.withIndent('  ').convert(_data);
  }

  Future<String> exportToFile() async {
    final dir = await getApplicationSupportDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final exportPath = p.join(dir.path, 'plurallog_export_$timestamp.json');
    final content = await exportData();
    await File(exportPath).writeAsString(content);
    return exportPath;
  }

  // -- Import with validation --

  static const _knownKeys = {
    'config', 'members', 'switchEvents', 'channels', 'messages',
    'journal', 'polls', 'customFieldDefs', 'frontMessages', 'folders',
  };

  /// Validates that a JSON map is a PluralLog export.
  /// Throws [FormatException] with a descriptive message on failure.
  static void validateImport(Map<String, dynamic> data) {
    final recognized = data.keys.where((k) => _knownKeys.contains(k)).toList();
    if (recognized.isEmpty) {
      if (data.containsKey('members') &&
          data.containsKey('switches') &&
          data.containsKey('system_id')) {
        throw const FormatException(
            'This appears to be a PluralKit export, not a PluralLog export. '
            'PluralLog cannot import PluralKit files directly.');
      }
      if (data.containsKey('uid') &&
          data.containsKey('content') &&
          data.containsKey('members')) {
        throw const FormatException(
            'This appears to be a Simply Plural export, not a PluralLog export. '
            'PluralLog cannot import Simply Plural files directly.');
      }
      throw const FormatException(
          'This file does not appear to be a PluralLog export. '
          'PluralLog exports contain keys like "members", "switchEvents", "journal", etc.');
    }

    if (data.containsKey('members') && data['members'] is List) {
      final members = data['members'] as List;
      if (members.isNotEmpty) {
        final first = members.first;
        if (first is! Map) {
          throw const FormatException(
              'Invalid members format. Expected an array of member objects.');
        }
        final m = first as Map;
        if (!m.containsKey('id') || !m.containsKey('name')) {
          if (m.containsKey('uuid') || m.containsKey('pk_id')) {
            throw const FormatException(
                'This appears to be a PluralKit export. PluralLog members use '
                '"id" not "uuid".');
          }
          throw const FormatException(
              'Invalid member format. Each member must have "id" and "name" fields.');
        }
      }
    }
  }

  /// Import data from a JSON string.
  /// If [replace] is true, overwrites all data. Otherwise merges by ID.
  Future<Map<String, int>> importData(String jsonString,
      {bool replace = false}) async {
    final Map<String, dynamic> imported;
    try {
      imported = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid JSON: $e');
    }

    validateImport(imported);

    final summary = <String, int>{};

    if (replace) {
      _data = imported;
      await _save();
      summary['members'] =
          (imported['members'] as List<dynamic>?)?.length ?? 0;
      summary['switchEvents'] =
          (imported['switchEvents'] as List<dynamic>?)?.length ?? 0;
      summary['journal'] =
          (imported['journal'] as List<dynamic>?)?.length ?? 0;
      summary['polls'] = (imported['polls'] as List<dynamic>?)?.length ?? 0;
    } else {
      summary['members'] = await _mergeList('members', imported);
      summary['switchEvents'] = await _mergeList('switchEvents', imported);
      summary['journal'] = await _mergeList('journal', imported);
      summary['polls'] = await _mergeList('polls', imported);
      summary['messages'] = await _mergeList('messages', imported);
      summary['channels'] = await _mergeList('channels', imported);
      summary['customFieldDefs'] =
          await _mergeList('customFieldDefs', imported);
      await _save();
    }

    return summary;
  }

  Future<int> _mergeList(String key, Map<String, dynamic> imported) async {
    final importedList = imported[key] as List<dynamic>?;
    if (importedList == null || importedList.isEmpty) return 0;

    final existing = (_data[key] as List<dynamic>?) ?? [];
    final existingIds = existing
        .map((e) => (e as Map<String, dynamic>)['id']?.toString())
        .toSet();

    int added = 0;
    final merged = List<dynamic>.from(existing);
    for (final item in importedList) {
      final itemMap = item as Map<String, dynamic>;
      final id = itemMap['id']?.toString();
      if (id != null && !existingIds.contains(id)) {
        merged.add(itemMap);
        existingIds.add(id);
        added++;
      }
    }

    _data[key] = merged;
    return added;
  }

  /// Merge volume data from a remote backup into local storage.
  /// Uses local-wins conflict resolution: items with the same ID are not overwritten.
  Future<int> mergeVolumeData(
      String volumeName, Map<String, dynamic> remoteData) async {
    int added = 0;
    switch (volumeName) {
      case 'members':
        final remoteMembers =
            (remoteData['members'] as List<dynamic>? ?? []);
        final localMembers = (_data['members'] as List<dynamic>?) ?? [];
        final localIds = localMembers
            .map((e) => (e as Map<String, dynamic>)['id']?.toString())
            .toSet();
        for (final rm in remoteMembers) {
          final id = (rm as Map<String, dynamic>)['id']?.toString();
          if (id != null && !localIds.contains(id)) {
            localMembers.add(rm);
            localIds.add(id);
            added++;
          }
        }
        _data['members'] = localMembers;
        break;

      case 'fronts':
        final remoteEvents =
            (remoteData['switch_events'] as List<dynamic>? ?? []);
        final localEvents =
            (_data['switchEvents'] as List<dynamic>?) ?? [];
        final localIds = localEvents
            .map((e) => (e as Map<String, dynamic>)['id']?.toString())
            .toSet();
        for (final re in remoteEvents) {
          final id = (re as Map<String, dynamic>)['id']?.toString();
          if (id != null && !localIds.contains(id)) {
            localEvents.add(re);
            localIds.add(id);
            added++;
          }
        }
        _data['switchEvents'] = localEvents;
        break;

      case 'journal':
        final remoteEntries =
            (remoteData['journal_entries'] as List<dynamic>? ?? []);
        final localEntries = (_data['journal'] as List<dynamic>?) ?? [];
        final localIds = localEntries
            .map((e) => (e as Map<String, dynamic>)['id']?.toString())
            .toSet();
        for (final re in remoteEntries) {
          final id = (re as Map<String, dynamic>)['id']?.toString();
          if (id != null && !localIds.contains(id)) {
            localEntries.add(re);
            localIds.add(id);
            added++;
          }
        }
        _data['journal'] = localEntries;
        break;

      case 'chat':
        final remoteChannels =
            (remoteData['channels'] as List<dynamic>? ?? []);
        final localChannels = (_data['channels'] as List<dynamic>?) ?? [];
        final localChIds = localChannels
            .map((e) => (e as Map<String, dynamic>)['id']?.toString())
            .toSet();
        for (final rc in remoteChannels) {
          final id = (rc as Map<String, dynamic>)['id']?.toString();
          if (id != null && !localChIds.contains(id)) {
            localChannels.add(rc);
            localChIds.add(id);
          }
        }
        _data['channels'] = localChannels;

        final remoteMessages =
            (remoteData['messages'] as List<dynamic>? ?? []);
        final localMessages = (_data['messages'] as List<dynamic>?) ?? [];
        final localMsgIds = localMessages
            .map((e) => (e as Map<String, dynamic>)['id']?.toString())
            .toSet();
        for (final rm in remoteMessages) {
          final id = (rm as Map<String, dynamic>)['id']?.toString();
          if (id != null && !localMsgIds.contains(id)) {
            localMessages.add(rm);
            localMsgIds.add(id);
            added++;
          }
        }
        _data['messages'] = localMessages;
        break;

      case 'polls':
        final remotePolls = (remoteData['polls'] as List<dynamic>? ?? []);
        final localPolls = (_data['polls'] as List<dynamic>?) ?? [];
        final localIds = localPolls
            .map((e) => (e as Map<String, dynamic>)['id']?.toString())
            .toSet();
        for (final rp in remotePolls) {
          final id = (rp as Map<String, dynamic>)['id']?.toString();
          if (id != null && !localIds.contains(id)) {
            localPolls.add(rp);
            localIds.add(id);
            added++;
          }
        }
        _data['polls'] = localPolls;
        break;
    }

    await _save();
    return added;
  }
}
