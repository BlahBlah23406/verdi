import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi/domain/carbon.dart';
import 'package:verdi/services/backend/ledger_cipher.dart';

void main() {
  final activity = Activity(
    id: 'sensitive-meter-record',
    kind: ActivityKind.electricity,
    quantity: 12.5,
    date: DateTime.utc(2026, 11, 1),
    note: 'Private account nickname',
  );
  const owner = '10000000-0000-0000-0000-000000000001';
  late LedgerCipher cipher;
  late SecretKey key;

  setUp(() async {
    cipher = LedgerCipher();
    key = await cipher.newKey();
  });

  test(
    'activity round trips and envelope contains no clear activity fields',
    () async {
      final envelope = await cipher.encrypt(activity, owner: owner, key: key);
      final encoded = jsonEncode(envelope.toJson());
      expect(encoded, isNot(contains(activity.id)));
      expect(encoded, isNot(contains(activity.note)));
      expect(envelope.recordToken, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(base64Decode(envelope.nonce).length, 12);
      expect(base64Decode(envelope.mac).length, 16);
      final restored = await cipher.decrypt(
        LedgerEnvelope.fromJson(envelope.toJson()),
        owner: owner,
        key: key,
      );
      expect(restored.toJson(), activity.toJson());
    },
  );

  test(
    'retries use stable private record token and fresh ciphertext nonce',
    () async {
      final first = await cipher.encrypt(activity, owner: owner, key: key);
      final second = await cipher.encrypt(activity, owner: owner, key: key);
      expect(first.recordToken, second.recordToken);
      expect(first.nonce, isNot(second.nonce));
      expect(first.ciphertext, isNot(second.ciphertext));
      final otherKey = await cipher.newKey();
      expect(
        (await cipher.encrypt(
          activity,
          owner: owner,
          key: otherKey,
        )).recordToken,
        isNot(first.recordToken),
      );
    },
  );

  test(
    'wrong key, different owner and record substitution all fail closed',
    () async {
      final envelope = await cipher.encrypt(activity, owner: owner, key: key);
      await expectLater(
        cipher.decrypt(envelope, owner: owner, key: await cipher.newKey()),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        cipher.decrypt(envelope, owner: 'other-user', key: key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final substituted = LedgerEnvelope.fromJson({
        ...envelope.toJson(),
        'record_token': 'b' * 64,
      });
      await expectLater(
        cipher.decrypt(substituted, owner: owner, key: key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );

  test(
    'tampered ciphertext and unsupported envelope versions fail closed',
    () async {
      final envelope = await cipher.encrypt(activity, owner: owner, key: key);
      final bytes = base64Decode(envelope.ciphertext);
      bytes[0] ^= 1;
      final tampered = LedgerEnvelope.fromJson({
        ...envelope.toJson(),
        'ciphertext': base64Encode(bytes),
      });
      await expectLater(
        cipher.decrypt(tampered, owner: owner, key: key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final futureVersion = LedgerEnvelope.fromJson({
        ...envelope.toJson(),
        'version': 2,
      });
      await expectLater(
        cipher.decrypt(futureVersion, owner: owner, key: key),
        throwsFormatException,
      );
    },
  );
}
