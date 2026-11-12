import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi/services/backend/ledger_cipher.dart';
import 'package:verdi/services/backend/secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('parallel key creation shares a single persisted account key', () async {
    final first = LedgerKeyStore(
      const FlutterSecureStorage(),
      LedgerCipher(),
      namespace: 'project-a',
    );
    final second = LedgerKeyStore(
      const FlutterSecureStorage(),
      LedgerCipher(),
      namespace: 'project-a',
    );
    final keys = await Future.wait([
      first.create('user-a'),
      second.create('user-a'),
    ]);
    final bytes = await keys.first.extractBytes();
    expect(await keys.last.extractBytes(), bytes);
    expect(await (await first.read('user-a'))!.extractBytes(), bytes);
  });

  test(
    'keys are isolated by account and project; missing read creates nothing',
    () async {
      final first = LedgerKeyStore(
        const FlutterSecureStorage(),
        LedgerCipher(),
        namespace: 'project-a',
      );
      final second = LedgerKeyStore(
        const FlutterSecureStorage(),
        LedgerCipher(),
        namespace: 'project-b',
      );
      expect(await first.read('missing-user'), isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      final key = await first.create('user-a');
      expect(await first.read('user-b'), isNull);
      expect(await second.read('user-a'), isNull);
      expect(
        await (await first.read('user-a'))!.extractBytes(),
        await key.extractBytes(),
      );
    },
  );
}
