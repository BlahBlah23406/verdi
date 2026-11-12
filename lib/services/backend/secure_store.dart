import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ledger_cipher.dart';

const deviceSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
);

/// Supabase session tokens and PKCE verifier use OS storage, not preferences.
class SecureAuthStorage extends LocalStorage {
  SecureAuthStorage(this.storage, {required this.namespace});
  final FlutterSecureStorage storage;
  final String namespace;
  String get _sessionKey => 'verdi.auth.session.v1.$namespace';

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async =>
      await storage.containsKey(key: _sessionKey);
  @override
  Future<String?> accessToken() => storage.read(key: _sessionKey);
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: _sessionKey, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => storage.delete(key: _sessionKey);
}

class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(this.storage, {required this.namespace});
  final FlutterSecureStorage storage;
  final String namespace;
  String _key(String key) => 'verdi.auth.pkce.$namespace.$key';
  @override
  Future<String?> getItem({required String key}) =>
      storage.read(key: _key(key));
  @override
  Future<void> setItem({required String key, required String value}) =>
      storage.write(key: _key(key), value: value);
  @override
  Future<void> removeItem({required String key}) =>
      storage.delete(key: _key(key));
}

/// One key per account per installation. Keys never leave the device.
class LedgerKeyStore {
  LedgerKeyStore(this.storage, this.cipher, {this.namespace = 'default'});
  final FlutterSecureStorage storage;
  final LedgerCipher cipher;
  final String namespace;
  static final Map<String, Future<SecretKey>> _creating = {};
  String _key(String owner) => 'verdi.ledger.key.v1.$namespace.$owner';

  Future<SecretKey?> read(String owner) async {
    final encoded = await storage.read(key: _key(owner));
    if (encoded == null) return null;
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) throw const FormatException('Invalid ledger key.');
    return SecretKey(bytes);
  }

  Future<SecretKey> create(String owner) =>
      _creating.putIfAbsent(_key(owner), () => _create(owner));

  Future<SecretKey> _create(String owner) async {
    try {
      final existing = await read(owner);
      if (existing != null) return existing;
      final key = await cipher.newKey();
      await storage.write(
        key: _key(owner),
        value: base64Encode(await key.extractBytes()),
      );
      return key;
    } finally {
      _creating.remove(_key(owner));
    }
  }
}
