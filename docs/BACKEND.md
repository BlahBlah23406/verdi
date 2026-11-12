# Accounts, encrypted cloud ledger and organizations

This checkout adds an optional Supabase backend to the existing Flutter app. The
account icon opens real provider sign-in, passkey registration/sign-in, explicit
encrypted backup/download/deletion and organization membership controls. Without
configuration the app remains offline; it does not pretend an account is linked.

## Deployment and run

Prerequisites: the repo's Flutter SDK, a Supabase project, the Supabase CLI for
database migrations, and provider credentials owned by the deployer. No project
or provider credentials were supplied or created by this implementation.

1. Run `flutter pub get`. New libraries are pinned in `pubspec.yaml`; regenerate
   and review `pubspec.lock` after successful resolution. The implementation
   session could not reach pub.dev, so the original lockfile is not a completed
   lock for the new dependencies. Do not use `--enforce-lockfile` until resolved.
2. If needed, run `supabase init` in the repo to generate CLI configuration.
   For local development, run `supabase start`, `supabase db reset` and
   `supabase test db`. The migration is
   `supabase/migrations/202611120001_privacy_foundation.sql`; the pgTAP suite is
   `supabase/tests/privacy_foundation_test.sql`. Inspect/test locally before
   applying the migration to the linked hosted project with `supabase db push`.
   Applying to a hosted project is an operator deployment step, not an action
   already taken here.
3. Copy `config/backend.example.json` to `config/backend.json` and fill in your
   real HTTPS project URL and **publishable** key. The real file is ignored.
   `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are compile-time environment
   values, supplied with `--dart-define-from-file=config/backend.json`. They are
   public client configuration; they do not grant privileged access. Never put a
   Supabase secret/service-role key or OAuth client secret in this file or app.
4. Enable Google and Apple in Supabase Authentication Providers. Configure the
   Google OAuth client and Apple Service ID using their actual dashboard
   callback values. Store client secrets only in the Supabase provider settings.
   Apple web OAuth secrets expire and need operator rotation. Add the exact app
   callback `com.verdi.verdi://login-callback` to Supabase's allowed redirect URLs,
   and separately allow your actual deployed web URL. The native scheme is wired
   in the Android manifest and iOS Info.plist. The SDK uses PKCE.
5. Enable Supabase's **beta Passkeys** feature, choose a relying-party domain you
   control, and configure its allowed origins. Sign in with Google/Apple first,
   then choose Register a passkey. Sign out and use Sign in with a passkey. No
   application-managed password or custom token minting endpoint is introduced.
6. On Android, publish the real app package (`com.verdi.verdi`) and signing
   certificate SHA-256 under the RP domain's `.well-known/assetlinks.json` with
   `delegate_permission/common.get_login_creds`. On iOS, use your real Apple
   development team, add the Associated Domains capability (`webcredentials:`
   followed by that RP domain), and publish the matching TeamID/bundle ID in
   `.well-known/apple-app-site-association`. These ownership-dependent values
   must be configured by the deployer; no fictional domains or identities are
   checked in. Android minimum API is 28 and iOS deployment target is 16.0.
7. Run `flutter run -d <physical-device-id> --dart-define-from-file=config/backend.json`.
   Follow `docs/PHYSICAL_DEVICE_VALIDATION.md` for location/permission/battery acceptance.
   An unconfigured build can be run without the define file.

## Privacy and key custody

Only explicitly confirmed activities can be backed up. The backup action shows
the destination account and asks for confirmation every time. Pending imports,
raw GPS coordinates, organization journals and the dashboard demo are never
automatically uploaded. The existing local journal and review queue still use
**unencrypted SharedPreferences**; sign-out does not remove them or isolate them
by account. The UI states this. A person switching accounts must not back up
another person's local journal. Encrypting/migrating local storage is a separate
release prerequisite if shared-device protection is required.

Each entire Activity JSON is AES-256-GCM encrypted locally with a random 256-bit
device/account/project key and fresh 96-bit nonce. Owner UUID, version and record
token are authenticated additional data. A separate HKDF-SHA256 derived key
produces HMAC-SHA256 record identifiers; source IDs are not plain database keys.
Tampering, wrong owner/key, substitutions and unsupported versions fail closed.
The database sees ciphertext length, owner, row count and server upload time. It
does not see activity dates, notes, amounts, source IDs or carbon estimates.

Keys and native Supabase sessions/PKCE verifiers use flutter_secure_storage
(Android Keystore-backed storage / iOS Keychain with unlocked_this_device), scoped to project and account.
Android backup is disabled to avoid moving encrypted storage without its keys.
Keys remain after sign-out so the same user can decrypt after returning. They
are not sent to Supabase or organizations. Passkeys authenticate accounts; they
are independent of ledger keys. **There is no key export, escrow or cross-device
recovery in this version.** Losing the installation/key can permanently lose
decryption access. A fresh device with existing cloud rows fails backup rather
than generating a replacement key and silently mixing unreadable records.
An owner-only `ledger_vaults` row atomically binds the account to one random key
token; its unique account constraint resolves competing first backups from two
devices. A foreign key binds every ciphertext row to that vault token. In-process
key creation is serialized by account/project, and overlapping backups are
rejected. Deleting the cloud ledger releases the vault and cascades its rows.

Cloud ledger operations and passkey prompts target the Android/iOS apps. Web
supports OAuth but does not offer cloud ledger sync; browser session persistence
is disabled. PKCE redirect verification still needs transient browser secure
storage. No third-party JavaScript passkey bundle is loaded into the offline
web demo. Browser secure storage is not represented as a device hardware vault.

Backups are immutable by activity ID: repeating upload skips existing tokens;
it does not propagate edits/deletes to an already backed-up record. Delete cloud
ledger removes this account's ciphertext rows, while retaining local records and
device keys. Download decrypts all pages first and merges only missing local IDs;
any authentication/decryption failure aborts the merge. This is an explicit
backup service, not live bidirectional synchronization.

## Authorization and membership

Row-level security is enabled on every application table. An authenticated user
can select/append/delete only their own ledger. There is no UPDATE grant or
policy. Anonymous clients have no table access. The service-role key must never
be used by this app; database operators retaining privileged keys can bypass RLS
but cannot decrypt ciphertext without the device key.

Organization creation atomically adds the creator as owner. Only owners can add
an existing account by its UUID, supplied by the intended member out of band.
Members can leave; owners can remove members. Clients cannot directly insert or
change membership roles. The owner cannot remove their own owner row in this
minimal lifecycle. Account/organization deletion and ownership succession need
an operator retention procedure before a broad pilot. Members can see their own
membership and organization name; owners can query their organization's roster.
Membership **does not grant access to personal ledgers** and does not constitute
consent to share activity data. The existing institutional dashboard remains a
labeled simulation; no plaintext aggregate export has been silently connected.

## Verification

```powershell
flutter pub get
flutter analyze
flutter test test/ledger_cipher_test.dart
flutter test
supabase start
supabase db reset
supabase test db
flutter build web --release
```

The encryption tests cover round-trip, no plaintext fields, nonce uniqueness,
stable keyed IDs, different keys, ciphertext tampering, owner/record substitution
and version rejection. `test/secure_ledger_key_test.dart` checks concurrent
creation, key persistence and account/project isolation. The 17 database assertions cover owner access,
cross-user write rejection, immutability, owner-only membership management,
non-disclosure to members/outsiders, self-join rejection and withdrawal, atomic
vault claims, key-token binding and cascading owner deletion.
Live provider round trips, secure storage behavior on physical phones and
deployed RLS must also pass; test files alone are not proof of a production run.

Implementation-session status: Dart parser/formatter and platform XML/JSON
validation passed. Package resolution failed with
`Got socket error trying to find package passkeys at https://pub.dev.` Full
Flutter tests/build and database pgTAP execution remain unverified in this
environment; no Supabase project/provider secrets or physical device was given.

## API sources checked

- [Supabase Flutter passkey sign-in](https://supabase.com/docs/reference/dart/auth-signinwithpasskey)
  and [registration](https://supabase.com/docs/reference/dart/auth-registerpasskey):
  use the SDK's real end-to-end ceremony and platform authenticator.
- [Supabase Flutter package](https://pub.dev/packages/supabase_flutter): OAuth,
  deep links and custom session storage contracts.
- [Supabase.initialize API](https://pub.dev/documentation/supabase_flutter/latest/supabase_flutter/Supabase/initialize.html),
  [LocalStorage API](https://pub.dev/documentation/supabase_flutter/latest/supabase_flutter/LocalStorage-class.html),
  [GotrueAsyncStorage API](https://pub.dev/documentation/gotrue/latest/gotrue/GotrueAsyncStorage-class.html):
  checked `publishableKey`, secure session methods and named PKCE storage method parameters.
- [passkeys package](https://pub.dev/packages/passkeys): platform prompts,
  Digital Asset Links and Apple association requirements.
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) and
  [cryptography](https://pub.dev/packages/cryptography): OS storage and AES-GCM.
