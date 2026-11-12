import 'package:flutter/foundation.dart';
import 'package:passkeys/authenticator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/carbon.dart';
import 'ledger_cipher.dart';
import 'secure_store.dart';

/// Optional account service. An unconfigured build remains usable offline.
class BackendService {
  BackendService(this.client, {LedgerKeyStore? keys, LedgerCipher? cipher})
    : cipher = cipher ?? LedgerCipher(),
      keys =
          keys ?? LedgerKeyStore(deviceSecureStorage, cipher ?? LedgerCipher());

  final SupabaseClient client;
  final LedgerCipher cipher;
  final LedgerKeyStore keys;
  bool _backupBusy = false;
  static BackendService? instance;
  static String? initializationError;
  static const nativeRedirect = 'com.verdi.verdi://login-callback';

  static bool get nativeLedgerSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty && key.isEmpty) return;
    try {
      if (!url.startsWith('https://') || key.isEmpty) {
        throw const FormatException(
          'Supply HTTPS SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
        );
      }
      const storage = deviceSecureStorage;
      final namespace = Uri.parse(url).host;
      await Supabase.initialize(
        url: url,
        publishableKey: key,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          persistSession: !kIsWeb,
          localStorage: kIsWeb
              ? const EmptyLocalStorage()
              : SecureAuthStorage(storage, namespace: namespace),
          pkceAsyncStorage: SecurePkceStorage(storage, namespace: namespace),
        ),
      );
      final cipher = LedgerCipher();
      instance = BackendService(
        Supabase.instance.client,
        cipher: cipher,
        keys: LedgerKeyStore(storage, cipher, namespace: namespace),
      );
    } catch (_) {
      // Never surface URLs, tokens or raw provider errors in app logs/UI.
      initializationError = 'Account setup failed. Check backend configuration and secure storage.';
    }
  }

  String get userId =>
      client.auth.currentUser?.id ??
      (throw StateError('Sign in before accessing account data.'));

  Future<void> signIn(OAuthProvider provider) async {
    if (provider != OAuthProvider.apple && provider != OAuthProvider.google) {
      throw ArgumentError('Unsupported sign-in provider.');
    }
    final launched = await client.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb
          ? Uri.base.replace(query: '', fragment: '').toString()
          : nativeRedirect,
    );
    if (!launched) throw StateError('The sign-in browser could not open.');
  }

  Future<void> signInWithPasskey() async {
    _checkNative();
    await client.auth.signInWithPasskey(PasskeyAuthenticator());
  }

  Future<void> registerPasskey() async {
    _checkNative();
    await client.auth.registerPasskey(
      PasskeyAuthenticator(),
      friendlyName: 'Verdi device',
    );
  }

  Future<void> signOut() => client.auth.signOut();

  void _checkNative() {
    if (!nativeLedgerSupported) {
      throw UnsupportedError(
        'Passkeys and encrypted cloud ledgers require the Android or iOS app.',
      );
    }
  }

  /// Explicit backup of confirmed activities; no raw location or pending imports.
  /// Existing ciphertext is immutable. Retry safely skips already uploaded IDs.
  Future<int> backup(List<Activity> activities) async {
    if (_backupBusy) {
      throw StateError('An encrypted backup is already running.');
    }
    _backupBusy = true;
    try {
      return await _backup(activities);
    } finally {
      _backupBusy = false;
    }
  }

  Future<int> _backup(List<Activity> activities) async {
    _checkNative();
    final owner = userId;
    var key = await keys.read(owner);
    if (key == null) {
      final existing = await client
          .from('ledger_vaults')
          .select('user_id')
          .limit(1);
      if (existing.isNotEmpty) {
        throw StateError(
          'This account has a backup from another installation. Its key is unavailable; do not overwrite it.',
        );
      }
      key = await keys.create(owner);
    }
    final keyToken = await cipher.keyToken(key);
    // Unique user_id is an atomic claim, including two-device first-backup races.
    try {
      await client.from('ledger_vaults').insert({
        'user_id': owner,
        'key_token': keyToken,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
    final vault = await client
        .from('ledger_vaults')
        .select('key_token')
        .single();
    if (vault['key_token'] != keyToken) {
      throw StateError(
        'This account’s cloud ledger belongs to a different device key. No records were uploaded.',
      );
    }
    var uploaded = 0;
    for (final activity in activities) {
      final envelope = await cipher.encrypt(activity, owner: owner, key: key);
      // The SELECT is an optimization; the unique constraint handles races.
      final exists = await client
          .from('activity_ledger')
          .select('id')
          .eq('record_token', envelope.recordToken)
          .limit(1);
      if (exists.isNotEmpty) {
        continue;
      }
      try {
        await client.from('activity_ledger').insert({
          'user_id': owner,
          'key_token': keyToken,
          ...envelope.toJson(),
        });
        uploaded++;
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
      }
    }
    return uploaded;
  }

  Future<List<Activity>> download() async {
    _checkNative();
    final owner = userId;
    final key = await keys.read(owner);
    if (key == null) {
      throw StateError(
        'The ledger key for this account is unavailable on this device.',
      );
    }
    final result = <Activity>[];
    var offset = 0;
    const pageSize = 100;
    while (true) {
      final rows = await client
          .from('activity_ledger')
          .select()
          .order('id')
          .range(offset, offset + pageSize - 1);
      for (final row in rows) {
        result.add(
          await cipher.decrypt(
            LedgerEnvelope.fromJson(row),
            owner: owner,
            key: key,
          ),
        );
      }
      if (rows.length < pageSize) {
        return result;
      }
      offset += pageSize;
    }
  }

  Future<void> deleteCloudLedger() async {
    _checkNative();
    if (_backupBusy) {
      throw StateError(
        'Wait for the current backup before deleting the ledger.',
      );
    }
    // Cascading FK removes this owner's ciphertext and releases its vault claim.
    await client.from('ledger_vaults').delete().eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> memberships() async => await client
      .from('organization_members')
      .select('organization_id,role,organizations(name)')
      .eq('user_id', userId);

  Future<String> createOrganization(String name) async => await client.rpc(
    'create_organization',
    params: {'organization_name': name},
  ) as String;

  Future<void> addMember(String organizationId, String memberUserId) async {
    await client.rpc(
      'add_organization_member',
      params: {
        'organization_id': organizationId,
        'member_user_id': memberUserId,
      },
    );
  }

  Future<void> removeMember(String organizationId, String memberUserId) async {
    await client.rpc(
      'remove_organization_member',
      params: {
        'organization_id': organizationId,
        'member_user_id': memberUserId,
      },
    );
  }
}
