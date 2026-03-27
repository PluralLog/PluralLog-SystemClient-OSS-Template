import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import 'protocol.dart';
import 'api_client.dart';

/// Tracks version counters for each volume type.
class VolumeVersions {
  Map<String, int> _versions;
  VolumeVersions() : _versions = {};
  VolumeVersions._(this._versions);

  int getVersion(String volumeName) => _versions[volumeName] ?? 0;

  int incrementVersion(String volumeName) {
    _versions[volumeName] = getVersion(volumeName) + 1;
    return _versions[volumeName]!;
  }

  Map<String, dynamic> toMap() => _versions.map((k, v) => MapEntry(k, v));

  factory VolumeVersions.fromMap(Map<String, dynamic> map) {
    return VolumeVersions._(
        map.map((k, v) => MapEntry(k, (v as num).toInt())));
  }
}

/// Builds volumes from local database data and uploads them to the relay server.
///
/// Each volume is a self-contained JSON document that gets encrypted with
/// the VEK before upload. The server stores it as an opaque blob.
class VolumeManager {
  final LocalDatabase db;
  final FederationClient client;
  final VolumeVersions versions;

  VolumeManager(
      {required this.db, required this.client, required this.versions});

  /// Sync all volumes to the server. Returns the list of successfully uploaded volume names.
  Future<List<String>> syncAll() async {
    final uploaded = <String>[];
    for (final spec in _volumeSpecs) {
      try {
        await _syncVolume(spec.name, spec.builder, spec.tags);
        uploaded.add(spec.name);
      } catch (e) {
        debugPrint('Failed to sync ${spec.name}: $e');
      }
    }
    return uploaded;
  }

  late final List<_VolumeSpec> _volumeSpecs = [
    _VolumeSpec(
        FederationProtocol.volumeMeta, () => _buildMeta(), ['meta']),
    _VolumeSpec(FederationProtocol.volumeMembers, () => _buildMembers(),
        ['member']),
    _VolumeSpec(FederationProtocol.volumeFronts, () => _buildFronts(),
        ['switch', 'front']),
    _VolumeSpec(FederationProtocol.volumeJournal, () => _buildJournal(),
        ['journal']),
    _VolumeSpec(
        FederationProtocol.volumeChat, () => _buildChat(), ['chat']),
    _VolumeSpec(
        FederationProtocol.volumePolls, () => _buildPolls(), ['poll']),
    _VolumeSpec(
        FederationProtocol.volumeVault, () => _buildVault(), ['vault']),
  ];

  Future<void> _syncVolume(
    String volumeName,
    Future<Map<String, dynamic>> Function() builder,
    List<String> eventTags,
  ) async {
    final data = await builder();
    final jsonStr = jsonEncode(data);
    final plaintext = Uint8List.fromList(utf8.encode(jsonStr));
    final newVersion = versions.incrementVersion(volumeName);
    await client.uploadVolume(
      volumeName: volumeName,
      version: newVersion,
      plaintext: plaintext,
      eventTags: eventTags,
    );
  }

  Future<Map<String, dynamic>> _buildMeta() async {
    final config = await db.getConfig();
    return {
      'schema_version': 1,
      'system_name': config.systemName,
      'protocol_version': FederationProtocol.protocolVersion,
      'feature_set': FederationProtocol.featureSet,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _buildMembers() async {
    final members = await db.getMembers();
    final customFields = await db.getCustomFieldDefs();
    return {
      'schema_version': 1,
      'members': members.map((m) => m.toMap()).toList(),
      'custom_field_defs': customFields.map((d) => d.toMap()).toList(),
    };
  }

  Future<Map<String, dynamic>> _buildFronts() async {
    final switches = await db.getSwitchEvents();
    return {
      'schema_version': 1,
      'switch_events': switches.map((s) => s.toMap()).toList(),
    };
  }

  Future<Map<String, dynamic>> _buildJournal() async {
    final entries = await db.getJournalEntries();
    final visible = entries.where((e) => !e.hidden).toList();
    return {
      'schema_version': 1,
      'journal_entries': visible.map((e) => e.toMap()).toList(),
    };
  }

  Future<Map<String, dynamic>> _buildChat() async {
    final channels = await db.getChannels();
    final messages = await db.getMessages();
    return {
      'schema_version': 1,
      'channels': channels.map((c) => c.toMap()).toList(),
      'messages': messages.map((m) => m.toMap()).toList(),
    };
  }

  Future<Map<String, dynamic>> _buildPolls() async {
    final polls = await db.getPolls();
    return {
      'schema_version': 1,
      'polls': polls.map((p) => p.toMap()).toList(),
    };
  }

  Future<Map<String, dynamic>> _buildVault() async {
    final members = await db.getMembers();
    final vaultEntries = <Map<String, dynamic>>[];
    for (final m in members) {
      if (m.vault.isNotEmpty) {
        vaultEntries.add({'member_id': m.id, 'data': m.vault});
      }
    }
    return {'schema_version': 1, 'vault_entries': vaultEntries};
  }
}

class _VolumeSpec {
  final String name;
  final Future<Map<String, dynamic>> Function() builder;
  final List<String> tags;
  _VolumeSpec(this.name, this.builder, this.tags);
}
