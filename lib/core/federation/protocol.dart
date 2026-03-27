/// PluralLog Federation Protocol Constants.
///
/// These must match across the System App, Friend Client, and Relay Server.
/// 
/// /// If you're trying to add new volumes/feature, please prepend them with a package/org name or code. 
/// This leaves room for us to implement new volumes without worries about breaking OSS/User apps.
/// Also leave the pvsb/bucket prefix/name alone, as we're looking at the possibility of creating bucket volumes.
/// This assumes you want compatibility of course, which isn't required.
class FederationProtocol {
  static const int protocolVersion = 1;

  static const List<String> featureSet = [
    'members:1',
    'fronts:1',
    'journal:1',
    'chat:1',
    'polls:1',
    'analytics:1',
    'meta:1',
    'vault:1',
  ];

  static const String volumeMeta = 'meta';
  static const String volumeMembers = 'members';
  static const String volumeFronts = 'fronts';
  static const String volumeJournal = 'journal';
  static const String volumeChat = 'chat';
  static const String volumePolls = 'polls';
  static const String volumeAnalytics = 'analytics';
  static const String volumeVault = 'vault';

  static const List<String> allVolumes = [
    volumeMeta, volumeMembers, volumeFronts, volumeJournal,
    volumeChat, volumePolls, volumeAnalytics, volumeVault,
  ];

  /// Encrypted payloads are padded to the nearest 4KB boundary before
  /// encryption to reduce metadata leakage via payload size.
  /// (TODO Though this needs updated, it had null bytes in volumes iirc)
  static const int paddingBoundary = 4096;

  /// Timestamps in control headers are rounded to the nearest hour.
  static const int timestampRoundingSeconds = 3600;
}

/// Per-friend permission flags controlling which volumes are shared.
class SharingPermissions {
  bool shareFrontStatus;
  bool shareMembers;
  bool shareFrontHistory;
  bool shareJournal;
  bool shareMoodTrends;
  bool sharePolls;
  bool shareVault;

  SharingPermissions({
    this.shareFrontStatus = true,
    this.shareMembers = true,
    this.shareFrontHistory = false,
    this.shareJournal = false,
    this.shareMoodTrends = false,
    this.sharePolls = false,
    this.shareVault = false,
  });

  Map<String, bool> toMap() => {
        'share_front_status': shareFrontStatus,
        'share_members': shareMembers,
        'share_front_history': shareFrontHistory,
        'share_journal': shareJournal,
        'share_mood_trends': shareMoodTrends,
        'share_polls': sharePolls,
        'share_vault': shareVault,
      };

  factory SharingPermissions.fromMap(Map<String, dynamic> map) =>
      SharingPermissions(
        shareFrontStatus: map['share_front_status'] ?? true,
        shareMembers: map['share_members'] ?? true,
        shareFrontHistory: map['share_front_history'] ?? false,
        shareJournal: map['share_journal'] ?? false,
        shareMoodTrends: map['share_mood_trends'] ?? false,
        sharePolls: map['share_polls'] ?? false,
        shareVault: map['share_vault'] ?? false,
      );

  /// Returns the list of volume names that these permissions enable.
  List<String> get enabledVolumes {
    final result = <String>[FederationProtocol.volumeMeta];
    if (shareMembers) result.add(FederationProtocol.volumeMembers);
    if (shareFrontStatus || shareFrontHistory) {
      result.add(FederationProtocol.volumeFronts);
    }
    if (shareJournal) result.add(FederationProtocol.volumeJournal);
    if (sharePolls) result.add(FederationProtocol.volumePolls);
    if (shareMoodTrends) result.add(FederationProtocol.volumeAnalytics);
    if (shareVault) result.add(FederationProtocol.volumeVault);
    return result;
  }
}
