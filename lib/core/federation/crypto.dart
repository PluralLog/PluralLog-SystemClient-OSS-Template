import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages all cryptographic operations for federation.
///
/// Key hierarchy:
///   - Ed25519 signing keypair: authenticates requests and signs volumes
///   - X25519 exchange keypair: derives per-friend shared secrets via ECDH
///   - Volume Encryption Key (VEK): AES-256-GCM symmetric key for all volumes
///
/// When sharing with a friend:
///   1. ECDH(our X25519 private, friend X25519 public) -> shared secret
///   2. HKDF-SHA256(shared secret) -> Friend Key Encryption Key (FKEK)
///   3. AES-GCM-encrypt(VEK, FKEK) -> encrypted VEK blob stored on server
///
/// The server never sees any private keys or the plaintext VEK.
class FederationCrypto {
  static const _storage = FlutterSecureStorage();

  static const _kSigningPrivate = 'fed_signing_private';
  static const _kSigningPublic = 'fed_signing_public';
  static const _kExchangePrivate = 'fed_exchange_private';
  static const _kExchangePublic = 'fed_exchange_public';
  static const _kVolumeKey = 'fed_volume_key';

  static final _ed25519 = Ed25519();
  static final _x25519 = X25519();
  static final _aesGcm = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Whether identity keys have been generated.
  static Future<bool> get hasIdentity async {
    final key = await _storage.read(key: _kSigningPublic);
    return key != null;
  }

  /// Generate a new identity (signing + exchange keypairs) and VEK.
  /// Call once during federation setup.
  static Future<void> generateIdentity() async {
    // Ed25519 signing keypair
    final signingPair = await _ed25519.newKeyPair();
    final signingPrivBytes = await signingPair.extractPrivateKeyBytes();
    final signingPubKey = await signingPair.extractPublicKey();

    await _storage.write(
        key: _kSigningPrivate, value: base64Encode(signingPrivBytes));
    await _storage.write(
        key: _kSigningPublic, value: base64Encode(signingPubKey.bytes));

    // X25519 exchange keypair
    final exchangePair = await _x25519.newKeyPair();
    final exchangePrivBytes = await exchangePair.extractPrivateKeyBytes();
    final exchangePubKey = await exchangePair.extractPublicKey();

    await _storage.write(
        key: _kExchangePrivate, value: base64Encode(exchangePrivBytes));
    await _storage.write(
        key: _kExchangePublic, value: base64Encode(exchangePubKey.bytes));

    // Volume Encryption Key (AES-256)
    final vek = await _aesGcm.newSecretKey();
    final vekBytes = await vek.extractBytes();
    await _storage.write(key: _kVolumeKey, value: base64Encode(vekBytes));
  }

  static Future<String> getSigningPublicKey() async {
    return (await _storage.read(key: _kSigningPublic))!;
  }

  static Future<String> getExchangePublicKey() async {
    return (await _storage.read(key: _kExchangePublic))!;
  }

  /// Sign data with Ed25519.
  static Future<Uint8List> sign(Uint8List data) async {
    final privBytes =
        base64Decode((await _storage.read(key: _kSigningPrivate))!);
    final pubBytes =
        base64Decode((await _storage.read(key: _kSigningPublic))!);

    final keyPair = SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );

    final signature = await _ed25519.sign(data, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Encrypt data with the VEK (AES-256-GCM).
  /// Returns nonce(12) + ciphertext + mac(16) concatenated.
  static Future<Uint8List> encryptVolume(
      Uint8List plaintext, String volumeName, int version) async {
    final vekBytes =
        base64Decode((await _storage.read(key: _kVolumeKey))!);
    final vek = SecretKey(vekBytes);

    // Deterministic nonce from volume_name || version
    final nonceInput = utf8.encode('$volumeName|$version');
    final nonceHash = await Sha256().hash(nonceInput);
    final nonce = nonceHash.bytes.sublist(0, 12);

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: vek,
      nonce: nonce,
    );

    final result = BytesBuilder();
    result.add(nonce);
    result.add(secretBox.cipherText);
    result.add(secretBox.mac.bytes);
    return result.toBytes();
  }

  /// Decrypt volume data with the VEK.
  static Future<Uint8List> decryptVolume(Uint8List encrypted) async {
    final vekBytes =
        base64Decode((await _storage.read(key: _kVolumeKey))!);
    final vek = SecretKey(vekBytes);

    final nonce = encrypted.sublist(0, 12);
    final mac = Mac(encrypted.sublist(encrypted.length - 16));
    final cipherText = encrypted.sublist(12, encrypted.length - 16);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final plaintext = await _aesGcm.decrypt(secretBox, secretKey: vek);
    return Uint8List.fromList(plaintext);
  }

  /// Derive a Friend Key Encryption Key via ECDH + HKDF.
  static Future<SecretKey> deriveFriendKey(
      String friendExchangePublicKeyBase64) async {
    final privBytes =
        base64Decode((await _storage.read(key: _kExchangePrivate))!);
    final pubBytes =
        base64Decode((await _storage.read(key: _kExchangePublic))!);

    final myKeyPair = SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );

    final friendPubKey = SimplePublicKey(
      base64Decode(friendExchangePublicKeyBase64),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: friendPubKey,
    );

    // HKDF with 32 zero bytes as salt (required for Android compatibility)
    final fkek = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      info: utf8.encode('PluralLog-FKEK-v1'),
      nonce: Uint8List(32),
    );

    return fkek;
  }

  /// Encrypt the VEK for a specific friend (key wrapping).
  static Future<Uint8List> wrapVekForFriend(
      String friendExchangePublicKeyBase64) async {
    final fkek = await deriveFriendKey(friendExchangePublicKeyBase64);
    final vekBytes =
        base64Decode((await _storage.read(key: _kVolumeKey))!);

    final secretBox = await _aesGcm.encrypt(vekBytes, secretKey: fkek);

    final result = BytesBuilder();
    result.add(secretBox.nonce);
    result.add(secretBox.cipherText);
    result.add(secretBox.mac.bytes);
    return result.toBytes();
  }

  /// Re-key: generate a new VEK. Call after revoking a friend.
  static Future<void> rekeyVolumeKey() async {
    final newVek = await _aesGcm.newSecretKey();
    final newVekBytes = await newVek.extractBytes();
    await _storage.write(key: _kVolumeKey, value: base64Encode(newVekBytes));
  }

  /// Delete all federation keys.
  static Future<void> deleteKeys() async {
    await _storage.delete(key: _kSigningPrivate);
    await _storage.delete(key: _kSigningPublic);
    await _storage.delete(key: _kExchangePrivate);
    await _storage.delete(key: _kExchangePublic);
    await _storage.delete(key: _kVolumeKey);
  }
}
