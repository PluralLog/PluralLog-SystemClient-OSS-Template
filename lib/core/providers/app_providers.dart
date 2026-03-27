import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/local_database.dart';
import '../models/models.dart';

const _uuid = Uuid();

final databaseProvider =
    Provider<LocalDatabase>((ref) => LocalDatabase.instance);

// -- System Config --

class ConfigNotifier extends StateNotifier<SystemConfig> {
  final LocalDatabase db;
  ConfigNotifier(this.db) : super(SystemConfig()) {
    _load();
  }
  Future<void> _load() async {
    state = await db.getConfig();
  }

  Future<void> update(SystemConfig config) async {
    state = config;
    await db.saveConfig(config);
  }
}

final configProvider =
    StateNotifierProvider<ConfigNotifier, SystemConfig>((ref) {
  return ConfigNotifier(ref.read(databaseProvider));
});

// -- Members --

class MembersNotifier extends StateNotifier<List<Member>> {
  final LocalDatabase db;
  MembersNotifier(this.db) : super([]) {
    _load();
  }
  Future<void> _load() async {
    state = await db.getMembers();
  }

  Future<void> add(Member member) async {
    await db.addMember(member);
    state = await db.getMembers();
  }

  Future<void> update(Member member) async {
    await db.updateMember(member);
    state = await db.getMembers();
  }

  Future<void> remove(String id) async {
    await db.deleteMember(id);
    state = await db.getMembers();
  }

  Member? byId(String id) {
    try {
      return state.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}

final membersProvider =
    StateNotifierProvider<MembersNotifier, List<Member>>((ref) {
  return MembersNotifier(ref.read(databaseProvider));
});

// -- Switch Events --

class SwitchNotifier extends StateNotifier<List<SwitchEvent>> {
  final LocalDatabase db;
  SwitchNotifier(this.db) : super([]) {
    _load();
  }
  Future<void> _load() async {
    state = await db.getSwitchEvents();
  }

  SwitchEvent? get activeFront {
    try {
      return state.lastWhere((e) => e.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<void> switchTo(String memberId,
      {String? notes, List<String>? cofronterIds}) async {
    final event = SwitchEvent(
      id: _uuid.v4(),
      memberId: memberId,
      startTime: DateTime.now(),
      notes: notes,
      cofronterIds: cofronterIds,
    );
    await db.addSwitchEvent(event);
    state = await db.getSwitchEvents();
  }

  Future<void> endCurrent() async {
    final events = await db.getSwitchEvents();
    for (final e in events) {
      if (e.isActive) e.endTime = DateTime.now();
    }
    await db.saveSwitchEvents(events);
    state = events;
  }

  Future<void> deleteSwitch(String id) async {
    await db.deleteSwitchEvent(id);
    state = await db.getSwitchEvents();
  }
}

final switchProvider =
    StateNotifierProvider<SwitchNotifier, List<SwitchEvent>>((ref) {
  return SwitchNotifier(ref.read(databaseProvider));
});

final activeFrontProvider = Provider<SwitchEvent?>((ref) {
  final switches = ref.watch(switchProvider);
  try {
    return switches.lastWhere((e) => e.isActive);
  } catch (_) {
    return null;
  }
});

// -- Chat --

class ChannelsNotifier extends StateNotifier<List<ChatChannel>> {
  final LocalDatabase db;
  ChannelsNotifier(this.db) : super([]) {
    _load();
  }
  Future<void> _load() async {
    state = await db.getChannels();
  }

  Future<void> add(ChatChannel channel) async {
    final channels = [...state, channel];
    await db.saveChannels(channels);
    state = channels;
  }
}

final channelsProvider =
    StateNotifierProvider<ChannelsNotifier, List<ChatChannel>>((ref) {
  return ChannelsNotifier(ref.read(databaseProvider));
});

final selectedChannelProvider = StateProvider<String?>((ref) => null);

class MessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final LocalDatabase db;
  MessagesNotifier(this.db) : super([]) {
    _load();
  }
  Future<void> _load() async {
    state = await db.getMessages();
  }

  List<ChatMessage> forChannel(String channelId) {
    return state.where((m) => m.channelId == channelId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> send(ChatMessage message) async {
    await db.addMessage(message);
    state = await db.getMessages();
  }

  Future<void> delete(String id) async {
    await db.deleteMessage(id);
    state = await db.getMessages();
  }
}

final messagesProvider =
    StateNotifierProvider<MessagesNotifier, List<ChatMessage>>((ref) {
  return MessagesNotifier(ref.read(databaseProvider));
});

// -- Journal --

class JournalNotifier extends StateNotifier<List<JournalEntry>> {
  final LocalDatabase db;
  JournalNotifier(this.db) : super([]) {
    _load();
  }
  Future<void> _load() async {
    state = await db.getJournalEntries();
  }

  Future<void> add(JournalEntry entry) async {
    await db.addJournalEntry(entry);
    state = await db.getJournalEntries();
  }

  Future<void> remove(String id) async {
    await db.deleteJournalEntry(id);
    state = await db.getJournalEntries();
  }
}

final journalProvider =
    StateNotifierProvider<JournalNotifier, List<JournalEntry>>((ref) {
  return JournalNotifier(ref.read(databaseProvider));
});

// -- Polls --

class PollsNotifier extends StateNotifier<List<Poll>> {
  final LocalDatabase db;
  PollsNotifier(this.db) : super([]) {
    _load();
  }
  Future<void> _load() async {
    state = await db.getPolls();
  }

  Future<void> add(Poll poll) async {
    await db.addPoll(poll);
    state = await db.getPolls();
  }

  Future<void> vote(String pollId, String memberId, int optionIndex) async {
    final polls = [...state];
    final idx = polls.indexWhere((p) => p.id == pollId);
    if (idx >= 0) {
      polls[idx].votes[memberId] = optionIndex;
      await db.updatePoll(polls[idx]);
      state = polls;
    }
  }

  Future<void> closePoll(String pollId) async {
    final polls = [...state];
    final idx = polls.indexWhere((p) => p.id == pollId);
    if (idx >= 0) {
      polls[idx].closed = true;
      await db.updatePoll(polls[idx]);
      state = polls;
    }
  }
}

final pollsProvider =
    StateNotifierProvider<PollsNotifier, List<Poll>>((ref) {
  return PollsNotifier(ref.read(databaseProvider));
});

// -- Custom Field Definitions --

class CustomFieldDefsNotifier extends StateNotifier<List<CustomFieldDef>> {
  final LocalDatabase db;
  CustomFieldDefsNotifier(this.db) : super([]) {
    _load();
  }
  Future<void> _load() async {
    state = await db.getCustomFieldDefs();
  }

  Future<void> add(CustomFieldDef def) async {
    await db.saveCustomFieldDefs([...state, def]);
    state = await db.getCustomFieldDefs();
  }
}

final customFieldDefsProvider =
    StateNotifierProvider<CustomFieldDefsNotifier, List<CustomFieldDef>>(
        (ref) {
  return CustomFieldDefsNotifier(ref.read(databaseProvider));
});

//  Navigation 

enum AppTab { dashboard, members, switching, journal, polls, chat, settings }

final currentTabProvider = StateProvider<AppTab>((ref) => AppTab.dashboard);

// -- Chat sender --

final chatSenderProvider = StateProvider<String?>((ref) => null);

// -- Federation sync state --

class FederationSyncState {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? lastError;
  final List<String> lastUploadedVolumes;

  const FederationSyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.lastError,
    this.lastUploadedVolumes = const [],
  });

  FederationSyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? lastError,
    List<String>? lastUploadedVolumes,
    bool clearError = false,
  }) {
    return FederationSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastUploadedVolumes:
          lastUploadedVolumes ?? this.lastUploadedVolumes,
    );
  }
}

final federationSyncProvider = StateProvider<FederationSyncState>((ref) => const FederationSyncState());
