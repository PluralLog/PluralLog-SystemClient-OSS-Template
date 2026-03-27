import 'dart:convert';

class SystemConfig {
  String? systemName;
  bool analyticsEnabled;
  bool onboardingComplete;

  // Federation
  bool federationEnabled;
  String? federationServerUrl;
  String? federationHandle;
  String? federationUserId;

  SystemConfig({
    this.systemName,
    this.analyticsEnabled = true,
    this.onboardingComplete = false,
    this.federationEnabled = false,
    this.federationServerUrl,
    this.federationHandle,
    this.federationUserId,
  });

  SystemConfig copyWith({
    String? systemName,
    bool? analyticsEnabled,
    bool? onboardingComplete,
    bool? federationEnabled,
    String? federationServerUrl,
    String? federationHandle,
    String? federationUserId,
    bool clearServerUrl = false,
    bool clearHandle = false,
    bool clearUserId = false,
  }) {
    return SystemConfig(
      systemName: systemName ?? this.systemName,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      federationEnabled: federationEnabled ?? this.federationEnabled,
      federationServerUrl: clearServerUrl
          ? null
          : (federationServerUrl ?? this.federationServerUrl),
      federationHandle:
          clearHandle ? null : (federationHandle ?? this.federationHandle),
      federationUserId:
          clearUserId ? null : (federationUserId ?? this.federationUserId),
    );
  }

  Map<String, dynamic> toMap() => {
        'systemName': systemName,
        'analyticsEnabled': analyticsEnabled ? 1 : 0,
        'onboardingComplete': onboardingComplete ? 1 : 0,
        'federationEnabled': federationEnabled ? 1 : 0,
        'federationServerUrl': federationServerUrl,
        'federationHandle': federationHandle,
        'federationUserId': federationUserId,
      };

  factory SystemConfig.fromMap(Map<String, dynamic> map) => SystemConfig(
        systemName: map['systemName'],
        analyticsEnabled: map['analyticsEnabled'] == 1,
        onboardingComplete: map['onboardingComplete'] == 1,
        federationEnabled: map['federationEnabled'] == 1,
        federationServerUrl: map['federationServerUrl'],
        federationHandle: map['federationHandle'],
        federationUserId: map['federationUserId'],
      );
}
