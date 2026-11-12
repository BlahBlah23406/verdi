import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../domain/carbon.dart';

/// The database sees only this envelope and its owner, never activity fields.
class LedgerEnvelope {
  const LedgerEnvelope({
    required this.recordToken,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    this.version = 1,
  });
  final String recordToken, nonce, ciphertext, mac;
  final int version;

  Map<String, dynamic> toJson() => {
    'record_token': recordToken,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
    'version': version,
  };

  factory LedgerEnvelope.fromJson(Map<String, dynamic> value) => LedgerEnvelope(
    recordToken: value['record_token'] as String,
    nonce: value['nonce'] as String,
    ciphertext: value['ciphertext'] as String,
    mac: value['mac'] as String,
    version: value['version'] as int,
  );
}

class LedgerCipher {
  final _cipher = AesGcm.with256bits();
  final _hmac = Hmac.sha256();

  Future<SecretKey> newKey() => _cipher.newSecretKey();

  Future<String> keyToken(SecretKey key) async {
    final digest = await _hmac.calculateMac(
      utf8.encode('verdi:vault-key:v1'),
      secretKey: key,
    );
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _aad(String owner, String token) =>
      utf8.encode('verdi:ledger:v1:$owner:$token');

  Future<LedgerEnvelope> encrypt(
    Activity activity, {
    required String owner,
    required SecretKey key,
  }) async {
    // Keyed digest hides low-entropy source/account IDs from the database.
    final identifierKey = await Hkdf(hmac: Hmac.sha256(), outputLength: 32)
        .deriveKey(
          secretKey: key,
          nonce: const [],
          info: utf8.encode('verdi:identifier-key:v1'),
        );
    final tokenMac = await _hmac.calculateMac(
      utf8.encode('verdi:record:v1:${activity.id}'),
      secretKey: identifierKey,
    );
    final token = tokenMac.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(activity.toJson())),
      secretKey: key,
      aad: _aad(owner, token),
    );
    return LedgerEnvelope(
      recordToken: token,
      nonce: base64Encode(box.nonce),
      ciphertext: base64Encode(box.cipherText),
      mac: base64Encode(box.mac.bytes),
    );
  }

  Future<Activity> decrypt(
    LedgerEnvelope envelope, {
    required String owner,
    required SecretKey key,
  }) async {
    if (envelope.version != 1) {
      throw const FormatException('Unsupported ledger encryption version.');
    }
    final clear = await _cipher.decrypt(
      SecretBox(
        base64Decode(envelope.ciphertext),
        nonce: base64Decode(envelope.nonce),
        mac: Mac(base64Decode(envelope.mac)),
      ),
      secretKey: key,
      aad: _aad(owner, envelope.recordToken),
    );
    return Activity.fromJson(
      Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map),
    );
  }
}
