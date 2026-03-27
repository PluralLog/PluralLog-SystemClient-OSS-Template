import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'protocol.dart';
import 'crypto.dart';

/// If you want to add or change an auth flow,
/// we again suggest adding or extending a new endpoint, or negotiating with the 
/// server for version info first. 

/// Error returned when the server requires a newer client version.
class UpgradeRequiredError implements Exception {
  final String message;
  UpgradeRequiredError(this.message);
  @override
  String toString() => 'UpgradeRequired: $message';
}

/// Represents a registered user on the relay server.
class FederationUser {
  final String userId;
  final String? handle;
  final String publicSigningKey;
  final String publicExchangeKey;
  final String clientType;
  final int protocolVersion;
  final List<String> featureSet;

  FederationUser({
    required this.userId,
    this.handle,
    required this.publicSigningKey,
    required this.publicExchangeKey,
    required this.clientType,
    required this.protocolVersion,
    required this.featureSet,
  });

  factory FederationUser.fromJson(Map<String, dynamic> json) => FederationUser(
        userId: json['user_id'],
        handle: json['handle'],
        publicSigningKey: json['public_signing_key'],
        publicExchangeKey: json['public_exchange_key'],
        clientType: json['client_type'],
        protocolVersion: json['protocol_version'] ?? 1,
        featureSet: List<String>.from(json['feature_set'] ?? []),
      );
}

/// Represents a sharing relationship between a system user and a friend.
class SharingRelationship {
  final String id;
  final String systemUserId;
  final String friendUserId;
  final String status;
  final Map<String, bool> permissions;
  final String? encryptedVekBlob;
  final String? friendExchangePublicKey;
  final String? friendHandle;

  SharingRelationship({
    required this.id,
    required this.systemUserId,
    required this.friendUserId,
    required this.status,
    required this.permissions,
    this.encryptedVekBlob,
    this.friendExchangePublicKey,
    this.friendHandle,
  });

  factory SharingRelationship.fromJson(Map<String, dynamic> json) =>
      SharingRelationship(
        id: json['id'],
        systemUserId: json['system_user_id'],
        friendUserId: json['friend_user_id'],
        status: json['status'],
        permissions: Map<String, bool>.from(json['permissions'] ?? {}),
        encryptedVekBlob: json['encrypted_vek_blob'],
        friendExchangePublicKey: json['friend_exchange_public_key'],
        friendHandle: json['friend_handle'],
      );
}

/// Volume control header (plaintext metadata stored on server).
class VolumeControlHeader {
  final String volumeName;
  final int version;
  final int modifiedAtEpochHour;
  final int sizeBytes;
  final List<String> eventTypeTags;

  VolumeControlHeader({
    required this.volumeName,
    required this.version,
    required this.modifiedAtEpochHour,
    required this.sizeBytes,
    this.eventTypeTags = const [],
  });

  Map<String, dynamic> toJson() => {
        'volume_name': volumeName,
        'version': version,
        'modified_at': modifiedAtEpochHour,
        'size_bytes': sizeBytes,
        'event_tags': eventTypeTags,
      };

  factory VolumeControlHeader.fromJson(Map<String, dynamic> json) =>
      VolumeControlHeader(
        volumeName: json['volume_name'],
        version: json['version'],
        modifiedAtEpochHour: json['modified_at'],
        sizeBytes: json['size_bytes'],
        eventTypeTags: List<String>.from(json['event_tags'] ?? []),
      );
}

/// Federation API client for the System App.
///
/// Handles registration, authentication, volume upload, discovery,
/// and sharing management against a PluralLog relay server.
class FederationClient {
  final Dio _dio;
  String? _serverUrl;
  String? _userId;
  String? _authToken;

  FederationClient({bool allowSelfSignedCert = false})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    if (allowSelfSignedCert) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      };
    }
  }

  bool get isConfigured => _serverUrl != null;
  bool get isAuthenticated => _authToken != null;
  String? get userId => _userId;

  void configure(String serverUrl) {
    _serverUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
  }

  void restoreUserId(String userId) {
    _userId = userId;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Protocol-Version':
            FederationProtocol.protocolVersion.toString(),
        'X-Feature-Set': FederationProtocol.featureSet.join(','),
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  void _handleResponse(Response response) {
    if (response.statusCode == 426) {
      throw UpgradeRequiredError(
        response.data?['message'] ?? 'Please update the app',
      );
    }
  }

  // -- Registration --

  Future<String> register({String? handle}) async {
    final signingKey = await FederationCrypto.getSigningPublicKey();
    final exchangeKey = await FederationCrypto.getExchangePublicKey();

    final response = await _dio.post(
      '$_serverUrl/api/v1/register',
      options: Options(headers: _headers),
      data: {
        'public_signing_key': signingKey,
        'public_exchange_key': exchangeKey,
        'handle': handle,
        'client_type': 'system',
        'protocol_version': FederationProtocol.protocolVersion,
        'feature_set': FederationProtocol.featureSet,
      },
    );

    _handleResponse(response);
    _userId = response.data['user_id'];
    return _userId!;
  }

  // -- Authentication --

  Future<void> authenticate() async {
    final challengeResp = await _dio.post(
      '$_serverUrl/api/v1/auth/challenge',
      options: Options(headers: _headers),
      data: {'user_id': _userId},
    );
    _handleResponse(challengeResp);
    final nonce = challengeResp.data['nonce'] as String;

    final signature =
        await FederationCrypto.sign(Uint8List.fromList(utf8.encode(nonce)));

    final tokenResp = await _dio.post(
      '$_serverUrl/api/v1/auth/token',
      options: Options(headers: _headers),
      data: {
        'user_id': _userId,
        'nonce': nonce,
        'signature': base64Encode(signature),
      },
    );
    _handleResponse(tokenResp);
    _authToken = tokenResp.data['token'];
  }

  // -- Volume Upload --

  Future<void> uploadVolume({
    required String volumeName,
    required int version,
    required Uint8List plaintext,
    List<String> eventTags = const [],
  }) async {
    // Pad plaintext to 4KB boundary before encryption
    final paddedSize =
        ((plaintext.length + FederationProtocol.paddingBoundary - 1) ~/
                FederationProtocol.paddingBoundary) *
            FederationProtocol.paddingBoundary;
    final paddedPlaintext = Uint8List(paddedSize);
    paddedPlaintext.setRange(0, plaintext.length, plaintext);

    final encrypted = await FederationCrypto.encryptVolume(
        paddedPlaintext, volumeName, version);

    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final roundedEpoch =
        (nowEpoch ~/ FederationProtocol.timestampRoundingSeconds) *
            FederationProtocol.timestampRoundingSeconds;

    final header = VolumeControlHeader(
      volumeName: volumeName,
      version: version,
      modifiedAtEpochHour: roundedEpoch,
      sizeBytes: encrypted.length,
      eventTypeTags: eventTags,
    );

    final headerJson = jsonEncode(header.toJson());
    final signatureInput = BytesBuilder();
    signatureInput.add(utf8.encode(headerJson));
    signatureInput.add(encrypted);
    final signature =
        await FederationCrypto.sign(signatureInput.toBytes());

    final response = await _dio.put(
      '$_serverUrl/api/v1/volumes/$volumeName',
      options: Options(headers: _headers),
      data: {
        'control_header': header.toJson(),
        'encrypted_payload': base64Encode(encrypted),
        'signature': base64Encode(signature),
      },
    );
    _handleResponse(response);
  }

  // -- Discovery & Sharing --

  Future<List<FederationUser>> discover(String query) async {
    final response = await _dio.get(
      '$_serverUrl/api/v1/discover',
      queryParameters: {'handle': query},
      options: Options(headers: _headers),
    );
    _handleResponse(response);
    return (response.data['results'] as List)
        .map((e) => FederationUser.fromJson(e))
        .toList();
  }

  Future<List<SharingRelationship>> getPendingRequests() async {
    final response = await _dio.get(
      '$_serverUrl/api/v1/sharing/requests',
      options: Options(headers: _headers),
    );
    _handleResponse(response);
    return (response.data['requests'] as List)
        .map((e) => SharingRelationship.fromJson(e))
        .toList();
  }

  Future<void> acceptSharing({
    required String requestId,
    required String friendExchangePublicKey,
    required SharingPermissions permissions,
  }) async {
    final wrappedVek =
        await FederationCrypto.wrapVekForFriend(friendExchangePublicKey);

    final response = await _dio.post(
      '$_serverUrl/api/v1/sharing/respond',
      options: Options(headers: _headers),
      data: {
        'request_id': requestId,
        'accepted': true,
        'encrypted_vek_blob': base64Encode(wrappedVek),
        'permissions': permissions.toMap(),
      },
    );
    _handleResponse(response);
  }

  Future<void> rejectSharing(String requestId) async {
    await _dio.post(
      '$_serverUrl/api/v1/sharing/respond',
      options: Options(headers: _headers),
      data: {'request_id': requestId, 'accepted': false},
    );
  }

  Future<void> revokeSharing(String sharingId) async {
    await _dio.delete(
      '$_serverUrl/api/v1/sharing/$sharingId',
      options: Options(headers: _headers),
    );
  }

  Future<void> updatePermissions({
    required String sharingId,
    required SharingPermissions permissions,
  }) async {
    await _dio.patch(
      '$_serverUrl/api/v1/sharing/$sharingId/permissions',
      options: Options(headers: _headers),
      data: {'permissions': permissions.toMap()},
    );
  }

  Future<String> generateInviteCode() async {
    final response = await _dio.post(
      '$_serverUrl/api/v1/sharing/invite',
      options: Options(headers: _headers),
    );
    _handleResponse(response);
    return response.data['code'];
  }

  Future<List<SharingRelationship>> getActiveSharings() async {
    final response = await _dio.get(
      '$_serverUrl/api/v1/sharing/requests',
      queryParameters: {'status': 'active'},
      options: Options(headers: _headers),
    );
    _handleResponse(response);
    return (response.data['requests'] as List)
        .map((e) => SharingRelationship.fromJson(e))
        .toList();
  }

  Future<Map<String, int>> listOwnVolumes() async {
    final response = await _dio.get(
      '$_serverUrl/api/v1/volumes',
      options: Options(headers: _headers),
    );
    _handleResponse(response);
    final volumes = response.data['volumes'] as List? ?? [];
    final result = <String, int>{};
    for (final v in volumes) {
      result[v['volume_name'] as String] = (v['version'] as num).toInt();
    }
    return result;
  }

  Future<void> deleteAccount() async {
    await _dio.delete(
      '$_serverUrl/api/v1/users/me',
      options: Options(headers: _headers),
    );
    _userId = null;
    _authToken = null;
  }

  void disconnect() {
    _serverUrl = null;
    _userId = null;
    _authToken = null;
  }
}
