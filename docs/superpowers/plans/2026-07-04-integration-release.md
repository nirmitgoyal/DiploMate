# Integration + Release (Lane D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the fixture-backed app (plans 4/5) to the real API (plan 2): hardened Google auth with a documented token-lifecycle state machine, on-demand content fetch with a transparent drift cache, resilient event sync, the starter-chapter funnel, Sentry with IP-safe scrubbing, Play signing/compliance, and the deploy smoke that proves the whole activation path.

**Architecture:** Real implementations of the plan-4 seams (`AuthRepository`, `ContentRepository`, `SyncService`, `isOnlineProvider`, `reportErrorProvider`) live in `app/lib/data/remote/` and are injected via `ProviderScope(overrides:)` in `main.dart` - the widget tree and the study loop never change. One dio client owns the base URL, bearer header, and the `X-Refreshed-Token` interceptor. Release work is checklists with exact console steps, plus a scripted deploy smoke.

**Tech Stack:** dio, google_sign_in (v7 API), flutter_secure_storage, sentry_flutter, drift (plan 5's AppDatabase), integration_test.

## Global Constraints

Contract-verbatim (plan-contract.md); every task inherits them:

- NEVER use em-dashes or en-dashes anywhere; plain hyphens only.
- NO offline Downloads feature: `ContentRepository.ensureChapterCached` is an on-demand fetch + transparent drift cache keyed on `chapters.content_version`; inline retry copy is exactly `Couldn't load this - retry`; no download UI, no atomic-install/resume machinery, no RSS-budget install tests. Ratings/events/bookmarks remain local-first; a network blip never loses a rating.
- API surface (plan 2, amended D3 inventory): `POST /auth/google` `{id_token}` -> `{session_jwt, user}`; `GET /manifest[?speciality=]`; `GET /chapters/:chapterId/qnas?page=N` (pages of 50); `GET /images/:id` (ETag/If-None-Match 304); `POST /sync/review-events` / `POST /sync/app-events` `{events:[...]}` -> `{inserted, rejected}`; `PUT /me/bookmarks` (LWW); `POST /me/speciality` (409 `change_limit_reached`); `DELETE /me`; `POST /qna/:id/report`. Auth header `Authorization: Bearer <session JWT>`.
- Session JWT lifecycle: 90d expiry; any authed response may carry `X-Refreshed-Token` (token >30d old) - store it WITHOUT interrupting an in-flight sync batch; 401 means session expired OR account deleted -> re-auth via the state machine; JWT lives in flutter_secure_storage, never in Sentry payloads.
- Sync resilience: exponential backoff + jitter on 401/5xx (no retry storm - T5/T10); server-rejected poison rows are dropped locally after N attempts, never wedge the queue.
- Dyno tier: Basic recommended (content on demand makes wake latency user-facing); if Eco is kept, dio RECEIVE timeout >= 35s and every fetch surface shows visible progress, never a silent spinner (outside voice #6).
- Sentry scrub: no answer text, no JWTs in crash payloads or breadcrumbs (licensed IP).
- Free beta (PG3): no billing code; `beta_active` row already grants content.
- Stack locks: dio + google_sign_in + flutter_secure_storage + sentry_flutter only additions here. Server: no changes in this plan.
- TDD; conventional commits. Repo root `/Users/nirmit/Codebases/DiploMate`; app commands run from `app/`.

---

### Task 1: Token-lifecycle state machine (DOCUMENT FIRST - ENG-T7) + ApiClient with refresh interceptor

**Files:**

- Create: `docs/auth-state-machine.md`
- Create: `app/lib/data/remote/api_client.dart`
- Test: `app/test/remote/api_client_test.dart`

**Interfaces:**

- Consumes: nothing app-side; plan-2 API shapes.
- Produces: `ApiClient` - `Dio get dio`; `Future<({String sessionJwt, Map<String, dynamic> user})> authGoogle(String idToken)`; `String? sessionJwt` (in-memory) + `Future<void> setSessionJwt(String?)` persisting via an injected `TokenStore`; `abstract class TokenStore { Future<String?> read(); Future<void> write(String?); }` (secure-storage impl in Task 2, in-memory fake in tests). Every later task calls the API only through `ApiClient`.

- [ ] **Step 1: Write `docs/auth-state-machine.md` (the table BEFORE code - ENG-T7)**

| #   | State           | Meaning                                     | Transitions out                                                                                                                                                                                                                           |
| --- | --------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | signed-out      | no JWT in secure storage                    | `signInWithGoogle()` success -> active; cancel/offline -> signed-out (error surfaced)                                                                                                                                                     |
| 2   | signing-in      | Google flow + `POST /auth/google` in flight | success -> active; `invalid_google_token`/network -> signed-out                                                                                                                                                                           |
| 3   | active          | JWT valid, < 30d old                        | any authed call may carry `X-Refreshed-Token` -> active (rotated); 401 -> expired                                                                                                                                                         |
| 4   | active-stale    | JWT valid, > 30d old                        | next authed response rotates via `X-Refreshed-Token` -> active; mid-sync-batch receipt stores the token and the batch CONTINUES uninterrupted                                                                                             |
| 5   | expired-offline | 401 unreachable to fix (no network)         | queued events stay in drift; retry with backoff; network back -> expired-online                                                                                                                                                           |
| 6   | expired-online  | any authed call returned 401                | silent re-auth attempt: `google_sign_in` silent flow -> `POST /auth/google` -> active (queued events then sync - they were never lost); silent fails -> signed-out + Sign-in screen (same Google account restores everything server-side) |
| 7   | deleted         | 401 from a deleted users row                | identical UX to expired-online; server keeps 401ing -> signed-out                                                                                                                                                                         |

Rules under the table: JWT storage = flutter_secure_storage key `session_jwt`; the interceptor NEVER retries the failing request itself (callers own retry policy); weeks-offline path (T5 test row) = state 5 -> 6 -> active with queued events surviving.

- [ ] **Step 2: Write the failing test**

`app/test/remote/api_client_test.dart`:

```dart
import 'package:diplomate/data/remote/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTokenStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

/// Dio adapter stub: scripted responses, records requests.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(options);
    return handler(options);
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  test('bearer header attached; X-Refreshed-Token is stored without breaking the call', () async {
    final store = MemoryTokenStore()..value = 'old-jwt';
    final client = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await client.init();
    client.dio.httpClientAdapter = StubAdapter((o) {
      expect(o.headers['Authorization'], 'Bearer old-jwt');
      return ResponseBody.fromString('{"ok":true}', 200, headers: {
        'content-type': ['application/json'],
        'x-refreshed-token': ['new-jwt'],
      });
    });
    final res = await client.dio.get('/health');
    expect(res.statusCode, 200);
    expect(store.value, 'new-jwt', 'sliding renewal persisted');
    expect(client.sessionJwt, 'new-jwt');
  });

  test('authGoogle posts id_token and installs the returned session JWT', () async {
    final store = MemoryTokenStore();
    final client = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await client.init();
    client.dio.httpClientAdapter = StubAdapter((o) {
      expect(o.path, '/auth/google');
      return ResponseBody.fromString(
          '{"session_jwt":"fresh","user":{"id":"u1","email":"a@b.c","name":null,"photo_url":null,"speciality_id":null,"speciality_change_count":0}}',
          200,
          headers: {'content-type': ['application/json']});
    });
    final out = await client.authGoogle('gid');
    expect(out.sessionJwt, 'fresh');
    expect(store.value, 'fresh');
    expect(out.user['id'], 'u1');
  });

  test('receive timeout is >= 35s (Eco-wake guard targets the right timer)', () async {
    final client = ApiClient(baseUrl: 'https://api.test', tokenStore: MemoryTokenStore());
    await client.init();
    expect(client.dio.options.receiveTimeout!.inSeconds, greaterThanOrEqualTo(35));
  });
}
```

- [ ] **Step 3: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/remote/api_client_test.dart`
Expected: FAIL - `api_client.dart` missing.

- [ ] **Step 4: Implement**

`app/lib/data/remote/api_client.dart`:

```dart
import 'package:dio/dio.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class ApiClient {
  ApiClient({required this.baseUrl, required this.tokenStore});

  final String baseUrl;
  final TokenStore tokenStore;
  late final Dio dio;
  String? sessionJwt;

  Future<void> init() async {
    sessionJwt = await tokenStore.read();
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      // Outside voice #6: an Eco-dyno wake manifests as time-to-first-byte
      // through the Heroku router - a RECEIVE timeout. Basic dyno is the
      // recommendation; this guard keeps Eco survivable.
      receiveTimeout: const Duration(seconds: 35),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final jwt = sessionJwt;
        if (jwt != null) options.headers['Authorization'] = 'Bearer $jwt';
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Sliding renewal (D5 addendum): store and continue - never
        // interrupts an in-flight sync batch (state 4).
        final refreshed = response.headers.value('x-refreshed-token');
        if (refreshed != null) {
          sessionJwt = refreshed;
          tokenStore.write(refreshed); // fire-and-forget persist
        }
        handler.next(response);
      },
    ));
  }

  Future<void> setSessionJwt(String? jwt) async {
    sessionJwt = jwt;
    await tokenStore.write(jwt);
  }

  Future<({String sessionJwt, Map<String, dynamic> user})> authGoogle(
      String idToken) async {
    final res = await dio.post('/auth/google', data: {'id_token': idToken});
    final jwt = res.data['session_jwt'] as String;
    await setSessionJwt(jwt);
    return (sessionJwt: jwt, user: res.data['user'] as Map<String, dynamic>);
  }
}
```

Add `dio` to `app/pubspec.yaml` dependencies.

- [ ] **Step 5: Run, expect PASS, commit**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/remote/api_client_test.dart`

```bash
cd /Users/nirmit/Codebases/DiploMate
git add docs/auth-state-machine.md app/lib/data/remote/api_client.dart app/test/remote app/pubspec.yaml
git commit -m "feat(app): auth state machine doc + ApiClient with sliding-renewal interceptor"
```

---

### Task 2: Real AuthRepository - google_sign_in v7 + secure storage (ENG-T7)

**Files:**

- Create: `app/lib/data/remote/secure_token_store.dart`
- Create: `app/lib/data/remote/remote_auth_repository.dart`
- Test: `app/test/remote/remote_auth_repository_test.dart`

**Interfaces:**

- Consumes: `ApiClient` (Task 1), plan-4 `AuthRepository`/`SessionUser`/`AuthOffline`/`SignInCancelled`/`ChangeLimitReached`.
- Produces: `RemoteAuthRepository implements AuthRepository` - constructor `({required ApiClient api, required GoogleSignInLike google})` where `abstract class GoogleSignInLike { Future<String?> idToken({required bool silent}); Future<void> signOut(); }` wraps the plugin (v7: instance is a singleton `GoogleSignIn.instance`, initialized with `serverClientId` = the WEB client id, so the ID token's `aud` matches `GOOGLE_WEB_CLIENT_ID` server-side). `SecureTokenStore implements TokenStore` over flutter_secure_storage key `session_jwt`.

- [ ] **Step 1: Write the failing test**

`app/test/remote/remote_auth_repository_test.dart`:

```dart
import 'package:diplomate/data/remote/api_client.dart';
import 'package:diplomate/data/remote/remote_auth_repository.dart';
import 'package:diplomate/data/repos/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTokenStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

class FakeGoogle implements GoogleSignInLike {
  FakeGoogle({this.token, this.cancel = false});
  String? token;
  bool cancel;
  bool signedOut = false;
  @override
  Future<String?> idToken({required bool silent}) async {
    if (cancel) return null;
    return token;
  }
  @override
  Future<void> signOut() async => signedOut = true;
}

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? b, Future<void>? c) async =>
      handler(o);
  @override
  void close({bool force = false}) {}
}

ApiClient clientWith(ResponseBody Function(RequestOptions) handler, TokenStore store) {
  final c = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
  return c;
}

void main() {
  test('signInWithGoogle: id token -> /auth/google -> SessionUser + stored JWT', () async {
    final store = MemoryTokenStore();
    final api = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await api.init();
    api.dio.httpClientAdapter = StubAdapter((o) => ResponseBody.fromString(
        '{"session_jwt":"jwt1","user":{"id":"u1","email":"a@b.c","name":"Ananya","photo_url":null,"speciality_id":null,"speciality_change_count":0}}',
        200,
        headers: {'content-type': ['application/json']}));
    final repo = RemoteAuthRepository(api: api, google: FakeGoogle(token: 'gid'));

    final user = await repo.signInWithGoogle();
    expect(user.id, 'u1');
    expect(store.value, 'jwt1');
  });

  test('cancelled Google flow throws SignInCancelled; network failure throws AuthOffline',
      () async {
    final api = ApiClient(baseUrl: 'https://api.test', tokenStore: MemoryTokenStore());
    await api.init();
    final repo = RemoteAuthRepository(api: api, google: FakeGoogle(cancel: true));
    expect(repo.signInWithGoogle(), throwsA(isA<SignInCancelled>()));

    api.dio.httpClientAdapter = StubAdapter((o) =>
        throw DioException.connectionError(requestOptions: o, reason: 'down'));
    final repo2 = RemoteAuthRepository(api: api, google: FakeGoogle(token: 'gid'));
    expect(repo2.signInWithGoogle(), throwsA(isA<AuthOffline>()));
  });

  test('restoreSession: stored JWT + silent token refresh path on 401', () async {
    final store = MemoryTokenStore()..value = 'stored-jwt';
    final api = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await api.init();
    var calls = 0;
    api.dio.httpClientAdapter = StubAdapter((o) {
      calls++;
      if (o.path == '/manifest' && calls == 1) {
        return ResponseBody.fromString('{"error":"session_expired"}', 401,
            headers: {'content-type': ['application/json']});
      }
      if (o.path == '/auth/google') {
        return ResponseBody.fromString(
            '{"session_jwt":"jwt2","user":{"id":"u1","email":"a@b.c","name":null,"photo_url":null,"speciality_id":"S1","speciality_change_count":0}}',
            200,
            headers: {'content-type': ['application/json']});
      }
      return ResponseBody.fromString(
          '{"schema_version":1,"min_app_version":1,"specialities":[]}', 200,
          headers: {'content-type': ['application/json']});
    });
    final repo = RemoteAuthRepository(api: api, google: FakeGoogle(token: 'gid'));
    final user = await repo.restoreSession();
    expect(user!.specialityId, 'S1', 'expired-online -> silent re-auth -> active');
    expect(store.value, 'jwt2');
  });

  test('signOut clears the stored JWT and the Google session', () async {
    final store = MemoryTokenStore()..value = 'jwt';
    final api = ApiClient(baseUrl: 'https://api.test', tokenStore: store);
    await api.init();
    final google = FakeGoogle(token: 'gid');
    final repo = RemoteAuthRepository(api: api, google: google);
    await repo.signOut();
    expect(store.value, isNull);
    expect(google.signedOut, isTrue);
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/remote/remote_auth_repository_test.dart`

- [ ] **Step 3: Implement**

`app/lib/data/remote/secure_token_store.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;
  static const _key = 'session_jwt';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? value) => value == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: value);
}
```

`app/lib/data/remote/remote_auth_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../repos/auth_repository.dart';
import 'api_client.dart';

/// Thin seam over google_sign_in v7 (singleton instance API).
/// serverClientId MUST be the WEB client id - it becomes the ID token `aud`
/// the API verifies against GOOGLE_WEB_CLIENT_ID (D5).
abstract class GoogleSignInLike {
  Future<String?> idToken({required bool silent});
  Future<void> signOut();
}

class RealGoogleSignIn implements GoogleSignInLike {
  RealGoogleSignIn({required String serverClientId})
      : _init = GoogleSignIn.instance.initialize(serverClientId: serverClientId);
  final Future<void> _init;

  @override
  Future<String?> idToken({required bool silent}) async {
    await _init;
    final account = silent
        ? await GoogleSignIn.instance.attemptLightweightAuthentication()
        : await GoogleSignIn.instance.authenticate();
    return account?.authentication.idToken;
  }

  @override
  Future<void> signOut() async {
    await _init;
    await GoogleSignIn.instance.signOut();
  }
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({required this.api, required this.google});
  final ApiClient api;
  final GoogleSignInLike google;

  SessionUser _toUser(Map<String, dynamic> u) => SessionUser(
        id: u['id'] as String,
        email: u['email'] as String,
        name: u['name'] as String?,
        photoUrl: u['photo_url'] as String?,
        specialityId: u['speciality_id'] as String?,
        specialityChangeCount: (u['speciality_change_count'] ?? 0) as int,
      );

  Future<SessionUser> _exchange({required bool silent}) async {
    final String? idToken;
    try {
      idToken = await google.idToken(silent: silent);
    } catch (_) {
      throw SignInCancelled();
    }
    if (idToken == null) throw SignInCancelled();
    try {
      final out = await api.authGoogle(idToken);
      return _toUser(out.user);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw AuthOffline();
      }
      rethrow;
    }
  }

  @override
  Future<SessionUser> signInWithGoogle() => _exchange(silent: false);

  @override
  Future<SessionUser?> restoreSession() async {
    if (api.sessionJwt == null) return null;
    try {
      // /manifest doubles as the whoami probe: authed + cheap.
      final res = await api.dio.get('/manifest');
      if (res.statusCode == 200) {
        // We have no /me read endpoint (inventory-locked); user fields come
        // from the LAST sign-in and live in drift local_settings (plan 5).
        // Re-auth silently to refresh them:
        return _exchange(silent: true);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // expired-online (state 6): silent re-auth with the same account.
        try {
          return await _exchange(silent: true);
        } on SignInCancelled {
          await api.setSessionJwt(null);
          return null;
        }
      }
      // expired-offline (state 5): keep the JWT; caller stays signed-in
      // visually and sync retries later with backoff.
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await google.signOut();
    await api.setSessionJwt(null);
  }

  @override
  Future<void> deleteAccount() async {
    await api.dio.delete('/me');
    await signOut();
  }

  @override
  Future<SessionUser> setSpeciality(String specialityId) async {
    try {
      final res = await api.dio
          .post('/me/speciality', data: {'speciality_id': specialityId});
      final current = res.data as Map<String, dynamic>;
      return SessionUser(
        id: '', email: '', name: null, photoUrl: null,
        specialityId: current['speciality_id'] as String?,
        specialityChangeCount: current['speciality_change_count'] as int,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) throw ChangeLimitReached();
      rethrow;
    }
  }
}
```

Note the `setSpeciality` return: the API returns only `{speciality_id, speciality_change_count}`; the caller (speciality screen) merges into the existing `SessionUser` via `copyWith` - adjust the screen call site accordingly in Task 7 wiring: `ref.read(sessionUserProvider.notifier).state = current.copyWith(specialityId: r.specialityId, specialityChangeCount: r.specialityChangeCount)`. Simplify by making `RemoteAuthRepository.setSpeciality` take and return the merge itself if the screen owns no copy - pick ONE and keep the plan-4 interface signature.

Add `google_sign_in` + `flutter_secure_storage` to pubspec.

- [ ] **Step 4: Run, expect PASS, commit**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/remote/remote_auth_repository_test.dart`

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/data/remote app/test/remote app/pubspec.yaml
git commit -m "feat(app): RemoteAuthRepository - google_sign_in v7, secure JWT, silent re-auth on 401"
```

---

### Task 3: Real ContentRepository - on-demand fetch + transparent drift cache (ENG-T1 as amended)

**Files:**

- Create: `app/lib/data/remote/remote_content_repository.dart`
- Test: `app/test/remote/remote_content_repository_test.dart`

**Interfaces:**

- Consumes: `ApiClient` (Task 1); plan-5 `AppDatabase` (content mirror tables, `image_blobs`, `cached_chapters`); plan-4 `ContentRepository`/`ContentFetchException` + row models.
- Produces: `RemoteContentRepository implements ContentRepository`:
  - `specialities()` / `chapters(specialityId)`: GET `/manifest` (with `?speciality=`), upsert into drift, serve from drift (drift is the read model; a failed refresh serves the cached copy silently - transparent cache, never promised).
  - `ensureChapterCached(chapterId)`: compare manifest `content_version` to `cached_chapters.content_version`; when stale or absent, page through `/chapters/:id/qnas` (50/page), upsert topics+qnas in ONE drift transaction per chapter, update `cached_chapters`; network failure with NO cached copy -> `ContentFetchException(chapterId)`; failure WITH a cached copy -> serve cache (silent).
  - `imageBytes(imageId)`: serve `image_blobs` if present; else GET `/images/:id` (send `If-None-Match` when a sha is cached), store bytes+sha, return. 304 -> serve cached bytes.

- [ ] **Step 1: Write the failing test**

`app/test/remote/remote_content_repository_test.dart`:

```dart
import 'dart:convert';

import 'package:diplomate/data/db/app_db.dart';
import 'package:diplomate/data/remote/api_client.dart';
import 'package:diplomate/data/remote/remote_content_repository.dart';
import 'package:diplomate/data/repos/content_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTokenStore implements TokenStore {
  String? value = 'jwt';
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);
  ResponseBody Function(RequestOptions) handler;
  int hits = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? b, Future<void>? c) async {
    hits++;
    return handler(o);
  }
  @override
  void close({bool force = false}) {}
}

const _manifest = {
  'schema_version': 1, 'min_app_version': 1,
  'specialities': [
    {'id': 'S1', 'name': 'Anaesthesiology', 'exam_type': 'DNB', 'has_content': true},
  ],
  'chapters': [
    {'id': 'CH1', 'title': 'Airway Management', 'slug': 'airway', 'sort_order': 1,
     'exam_weight': 100, 'content_version': 1, 'topic_count': 1, 'qna_count': 1},
  ],
};

const _page = {
  'chapter_id': 'CH1', 'content_version': 1, 'schema_version': 1, 'page': 1, 'pages': 1,
  'items': [
    {'id': 'QN1', 'topic_id': 'TP1', 'question': 'Q?', 'years': '2021', 'marks': 10,
     'earns_marks': [], 'sections': [{'key': 's', 'heading': 'S', 'body_md': 'B', 'marks': 1}],
     'sort_order': 1,
     'images': [{'id': 'IM1', 'caption': 'Fig', 'content_description': 'D',
                 'byte_size': 4, 'sha256': 'abc', 'sort_order': 1}]},
  ],
};

ResponseBody json(Object o, [int status = 200, Map<String, List<String>>? extra]) =>
    ResponseBody.fromString(jsonEncode(o), status, headers: {
      'content-type': ['application/json'], ...?extra});

void main() {
  late AppDatabase db;
  late ApiClient api;
  late StubAdapter adapter;
  late RemoteContentRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = ApiClient(baseUrl: 'https://api.test', tokenStore: MemoryTokenStore());
    await api.init();
    adapter = StubAdapter((o) {
      if (o.path == '/manifest') return json(_manifest);
      if (o.path == '/chapters/CH1/qnas') return json(_page);
      if (o.path == '/images/IM1') {
        return ResponseBody.fromBytes(Uint8List.fromList([1, 2, 3, 4]), 200,
            headers: {'content-type': ['image/webp'], 'etag': ['"abc"']});
      }
      return json({'error': 'not_found'}, 404);
    });
    api.dio.httpClientAdapter = adapter;
    repo = RemoteContentRepository(api: api, db: db, specialityId: () async => 'S1');
  });

  tearDown(() => db.close());

  test('ensureChapterCached fetches pages once, then serves drift without network', () async {
    await repo.ensureChapterCached('CH1');
    final qnas = await repo.qnas('TP1');
    expect(qnas.single.id, 'QN1');
    final before = adapter.hits;

    // network dies; cached chapter still serves
    adapter.handler = (o) => throw DioException.connectionError(requestOptions: o, reason: 'down');
    await repo.ensureChapterCached('CH1'); // silent - cache is fresh enough
    final again = await repo.qnas('TP1');
    expect(again.single.id, 'QN1');
    expect(adapter.hits, greaterThanOrEqualTo(before), 'no crash offline');
  });

  test('no cache + no network -> ContentFetchException (inline retry state)', () async {
    adapter.handler = (o) => throw DioException.connectionError(requestOptions: o, reason: 'down');
    expect(repo.ensureChapterCached('CH1'), throwsA(isA<ContentFetchException>()));
  });

  test('imageBytes caches; second read hits drift, not the network', () async {
    await repo.ensureChapterCached('CH1');
    final b1 = await repo.imageBytes('IM1');
    expect(b1, [1, 2, 3, 4]);
    final hits = adapter.hits;
    final b2 = await repo.imageBytes('IM1');
    expect(b2, [1, 2, 3, 4]);
    expect(adapter.hits, hits, 'served from image_blobs');
  });

  test('content_version bump invalidates the chapter cache on next ensure', () async {
    await repo.ensureChapterCached('CH1');
    var v2manifest = Map<String, dynamic>.from(_manifest);
    v2manifest['chapters'] = [
      {...(_manifest['chapters'] as List).first as Map<String, dynamic>, 'content_version': 2}
    ];
    var v2page = Map<String, dynamic>.from(_page);
    v2page['content_version'] = 2;
    (v2page['items'] as List).first['question'] = 'Q v2?';
    adapter.handler = (o) {
      if (o.path == '/manifest') return json(v2manifest);
      if (o.path == '/chapters/CH1/qnas') return json(v2page);
      return json({'error': 'not_found'}, 404);
    };
    await repo.ensureChapterCached('CH1');
    final qnas = await repo.qnas('TP1');
    expect(qnas.single.question, 'Q v2?', 'stale rows replaced in one transaction');
  });
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/remote/remote_content_repository_test.dart`

- [ ] **Step 3: Implement**

`app/lib/data/remote/remote_content_repository.dart` - the shape (write it in full; every method is a straight translation of the Interfaces block above):

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../db/app_db.dart';
import '../repos/content_repository.dart';
import 'api_client.dart';

class RemoteContentRepository implements ContentRepository {
  RemoteContentRepository(
      {required this.api, required this.db, required this.specialityId});
  final ApiClient api;
  final AppDatabase db;
  final Future<String?> Function() specialityId; // caller's chosen track

  bool _isNetwork(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout;

  Future<void> _refreshManifest() async {
    final spec = await specialityId();
    final res = await api.dio.get('/manifest',
        queryParameters: spec == null ? null : {'speciality': spec});
    await db.upsertManifest(res.data as Map<String, dynamic>);
  }

  @override
  Future<List<SpecialityRow>> specialities() async {
    try {
      await _refreshManifest();
    } on DioException catch (e) {
      if (!_isNetwork(e)) rethrow; // cache serves below on network failure
    }
    return db.readSpecialities();
  }

  @override
  Future<List<ChapterRow>> chapters(String specialityId) async {
    try {
      await _refreshManifest();
    } on DioException catch (e) {
      if (!_isNetwork(e)) rethrow;
    }
    return db.readChapters(specialityId);
  }

  @override
  Future<void> ensureChapterCached(String chapterId) async {
    final cached = await db.cachedChapterVersion(chapterId);
    int? remote;
    try {
      await _refreshManifest();
      remote = await db.manifestChapterVersion(chapterId);
    } on DioException catch (e) {
      if (!_isNetwork(e)) rethrow;
      if (cached != null) return; // transparent cache: serve what we have
      throw ContentFetchException(chapterId);
    }
    if (cached != null && cached == remote) return;

    try {
      final items = <Map<String, dynamic>>[];
      var page = 1, pages = 1, version = remote ?? 0;
      do {
        final res = await api.dio
            .get('/chapters/$chapterId/qnas', queryParameters: {'page': page});
        final body = res.data as Map<String, dynamic>;
        pages = body['pages'] as int;
        version = body['content_version'] as int;
        items.addAll((body['items'] as List).cast<Map<String, dynamic>>());
        page++;
      } while (page <= pages);
      // ONE transaction per chapter refresh; an open QnA stays in memory.
      await db.replaceChapterContent(chapterId, version, items);
    } on DioException catch (e) {
      if (_isNetwork(e) && cached != null) return;
      if (_isNetwork(e)) throw ContentFetchException(chapterId);
      rethrow;
    }
  }

  @override
  Future<List<TopicRow>> topics(String chapterId) => db.readTopics(chapterId);

  @override
  Future<List<QnaRow>> qnas(String topicId) => db.readQnas(topicId);

  @override
  Future<QnaRow?> qna(String qnaId) => db.readQna(qnaId);

  @override
  Future<Uint8List> imageBytes(String imageId) async {
    final cached = await db.readImageBlob(imageId);
    if (cached != null) return cached;
    final res = await api.dio.get<List<int>>('/images/$imageId',
        options: Options(responseType: ResponseType.bytes));
    final bytes = Uint8List.fromList(res.data!);
    await db.writeImageBlob(imageId, bytes);
    return bytes;
  }
}
```

The drift helpers (`upsertManifest`, `readSpecialities`, `readChapters`, `cachedChapterVersion`, `manifestChapterVersion`, `replaceChapterContent`, `readTopics`, `readQnas`, `readQna`, `readImageBlob`, `writeImageBlob`) are DECLARED by plan 5 Task 1 on `AppDatabase`; if a helper is missing when this task runs, add it to `app_db.dart` as a thin drift query in the same commit (each is a 3-8 line insert/select; `replaceChapterContent` wraps `db.transaction(() { delete chapter topics/qnas; insert all; upsert cached_chapters(version); })`).

- [ ] **Step 4: Run, expect PASS, commit**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/remote/remote_content_repository_test.dart`

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/data/remote app/lib/data/db app/test/remote
git commit -m "feat(app): RemoteContentRepository - on-demand fetch, one-transaction refresh, image cache"
```

---

### Task 4: Real SyncService - backoff + jitter, poison handling, bookmarks LWW (ENG-T10)

**Files:**

- Create: `app/lib/data/remote/remote_sync_service.dart`
- Test: `app/test/remote/remote_sync_service_test.dart`

**Interfaces:**

- Consumes: `ApiClient`; plan-5 `AppDatabase` pending tables (`pending_review_events`, `pending_app_events` - rows carry a `sync_attempts` counter - and `bookmarks` local rows + `local_settings` for `last_synced_at`); plan-4 `SyncService`.
- Produces: `RemoteSyncService implements SyncService`:
  - `flush()`: POST pending review events (batch), then app events, then `PUT /me/bookmarks` with all local rows; on `{inserted, rejected}` - delete synced rows, increment `sync_attempts` on rejected rows and DROP any row after 5 rejections (poison never wedges - T4); merge the bookmark response back (server truth incl. tombstones); stamp `local_settings.last_synced_at`.
  - Backoff: on 401/5xx/network, `flush()` records the failure and the NEXT allowed attempt = `now + min(2^n, 32) minutes +/- 25% jitter`; calls inside the window return immediately (no retry storm). 401 additionally signals the auth layer (callback `onAuthExpired`).
  - `lastSyncedAt()`: stream from `local_settings`.

- [ ] **Step 1: Write the failing test** - four cases: (a) happy flush drains both pending tables + stamps last_synced_at; (b) rejected poison row increments attempts and is dropped after 5; (c) 500 response arms the backoff window (second `flush()` inside the window performs zero HTTP calls - assert via adapter hit count); (d) bookmark tombstone from the server response overwrites a stale local un-delete. Build the test exactly like Task 3's (StubAdapter + in-memory AppDatabase); seed pending rows through plan-5's `StudyRepository.recordRating` or direct drift inserts.

`app/test/remote/remote_sync_service_test.dart` - write all four tests following the Task 3 stub pattern; the response for `/sync/review-events` is `{"inserted":1,"rejected":[]}` in (a) and `{"inserted":0,"rejected":[{"id":"<uuid>","error":"review_events_rating_check"}]}` in (b); `/me/bookmarks` returns `{"bookmarks":[{"content_id":"QN1","updated_at":"2026-07-04T11:00:00Z","deleted":true}]}` in (d).

- [ ] **Step 2: Run, expect FAIL**

Run: `cd /Users/nirmit/Codebases/DiploMate/app && flutter test test/remote/remote_sync_service_test.dart`

- [ ] **Step 3: Implement `RemoteSyncService`** with the exact policy above; keep the backoff state in memory (`DateTime? _nextAttempt; int _failures = 0;`) plus an injectable `now()` for tests; jitter via `Random(seed)` injected in tests. Reset `_failures = 0` on any successful flush. Bookmark merge: server response rows upsert into drift by `(content_id)` keeping server `updated_at`/`deleted`.

- [ ] **Step 4: Run, expect PASS, commit**

```bash
cd /Users/nirmit/Codebases/DiploMate
git add app/lib/data/remote/remote_sync_service.dart app/test/remote
git commit -m "feat(app): RemoteSyncService - drain pending, poison drop after 5, backoff + jitter, LWW merge-back"
```

---

### Task 5: main.dart wiring + starter funnel + report/online providers + Reader controller binding (DESIGN-T3 funnel, plan-4 seam swap, plan-5 ReaderController -> ReaderScreen)

**Files:**

- Modify: `app/lib/main.dart`
- Create: `app/lib/data/remote/remote_providers.dart`
- Modify: `app/lib/ui/reader/reader_screen.dart` (swap the plan-4 fixture state for the `ReaderController` binding; rename the `queuePlaceholder` constructor to `queue` with a real body; delete the stale L16-17 "Plan 5 Task 8 replaces the fixture" comment)
- Modify: `app/lib/router.dart` (line 51: `/reader/queue` builds `const ReaderScreen.queue()`, not `ReaderScreen.queuePlaceholder()`)
- Modify: `app/test/ui/reader_surface_test.dart` (line 102 toast assertion -> hyphen copy + pump for the awaited persist; see reader-binding rules)
- Test: `app/test/remote/wiring_test.dart`
- Test: `app/test/ui/reader/reader_queue_wiring_test.dart` (new: a `rate()` in the screen persists a `pending_review_events` row - Task 8's activation-path foundation)

**Interfaces:**

- Consumes: every remote class (Tasks 1-4); plan-4 seams (`contentRepositoryProvider`, `authRepositoryProvider`, `syncServiceProvider`, `isOnlineProvider`, `reportErrorProvider`, `sessionUserProvider`); plan-5 `appDatabaseProvider` + notification init; plan-5 `ReaderController` (`app/lib/ui/reader/reader_controller.dart`: `.queue({repo, queue, now})` / `.browse({repo, qnaId, topicQnaIds, now})`; `reveal()`, `rate(WireRating)`, `nextInTopic()`; getters `mode`/`currentQnaId`/`position`/`total`/`revealed`/`ratingInFlight`/`complete`/`hasNextInTopic`), `dueQueueProvider` + `studyRepositoryProvider` (`app/lib/providers/study_providers.dart`), the existing `ReaderView` slots (`overline`, `revealed`, `rated`, `onReveal`, `onRate`, `onNextInTopic` - unchanged), and `WireRating`/`uiLabelForWire` (`app/lib/domain/models.dart`).
- Produces: `remoteOverrides({required String apiBaseUrl, required String serverClientId})` -> `List<Override>` used in `main()`; `API_BASE_URL` + `GOOGLE_SERVER_CLIENT_ID` via `--dart-define` (document: `flutter run --dart-define=API_BASE_URL=https://diplomate-api.herokuapp.com --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com`).

Wiring rules:

- `reportErrorProvider` -> `(qnaId, message) => api.dio.post('/qna/$qnaId/report', data: {'message': message})`.
- `isOnlineProvider` -> updated by a dio interceptor: any successful response sets true; connection errors set false (no new dependency - `ponytail:` dio-observed connectivity; add connectivity_plus only if this proves too coarse).
- App start sequence in `main()`: init Sentry (Task 6) -> ApiClient.init (reads stored JWT) -> `restoreSession()` -> set `sessionUserProvider` -> runApp; router redirect (plan 4) then lands Sign-in / Speciality / Home correctly.
- Starter funnel (no auto-download): after onboarding commit, Home's pinned row (plan 4 `resumeChapterProvider`) already targets the highest-exam-weight chapter; `SyncService.flush()` fires on app start and on `AppLifecycleState.paused` (registered here); `topic_opened`/session events flow via plan 5.
- Speciality-commit merge: fix the Task 2 note - screen call site merges `setSpeciality` result into the current `SessionUser` with `copyWith`.

Reader controller binding (plan-5 `ReaderController` -> plan-4 `ReaderScreen`; PLAN-6 HANDOFF - no other task in plan 5 or 6 owns this seam, and Task 8's activation path cannot pass without it):

- **Queue mode.** `/reader/queue` stops rendering the hard-coded placeholder ("Recall queue arrives with the study loop." at reader_screen.dart ~L132-138); rename the `queuePlaceholder` constructor to `queue` and give it a real body. On entry (`initState`, fresh per entry - the recall gate resets) construct `ReaderController.queue(repo: ref.read(studyRepositoryProvider), queue: ref.read(dueQueueProvider))`, listen via `AnimatedBuilder`/`addListener`, and render `ReaderView` for the current card:
  - `overline: 'Suggestion · ${controller.position} of ${controller.total}'` (middle dot U+00B7, word "Suggestion" per design F-series; `ReaderView` uppercases it).
  - `onReveal: controller.reveal` (controller no-ops repeat reveals); `onRate: (r) async { await controller.rate(r); if (mounted) showDmToast(context, '✓ Rated ${uiLabelForWire[r]} - next answer'); }` - the toast fires ONLY after the awaited persist (D4 pre-ack). `onNextInTopic: null` (queue auto-advances inside `rate()`); the double-tap guard is controller-owned (T8 debounce), so no extra button-disable.
  - When `controller.complete`, render the designed end-of-queue state (design F8) in place of `ReaderView` (`currentQnaId` is null once complete). Home's primary CTA (home_screen.dart:65) already routes here.
- **Browse mode.** Keep the `ReaderScreen.browse(qnaId:, topicId:)` public signature intact - several existing widget tests (reader_actions, reader_surface, a11y, responsive) pump it; do not change its API. After `_fetch()` loads the topic QnAs, construct `ReaderController.browse(repo: ref.read(studyRepositoryProvider), qnaId: widget.qnaId!, topicQnaIds: [for (final q in _topicQnas) q.id])`. Route `onReveal`/`onRate` through it (rate-then-stay: after the awaited `rate()`, flip a local `rated` flag so `ReaderView` swaps the tray for "Next in topic"); `onNextInTopic: controller.hasNextInTopic ? () { controller.nextInTopic(); setState(() => rated = false); } : null` (replaces the fixture `_next`/`context.go` hop).
- **Content stays on-demand.** Resolve `controller.currentQnaId` to a `QnaRow` via `ref.read(contentRepositoryProvider).qna(id)` (drift-backed read model); reuse the screen's EXISTING loading spinner + "Couldn't load this - retry" affordance for a null/failed resolve (no new error UI). Search / bookmark / report rows are unchanged.
- **Toast copy (resolves N4).** The plan-4 screen showed `✓ Rated <tier> · next answer` (middle dot); align it to the T8/contract copy `✓ Rated <tier> - next answer` (plain hyphen). This ripples one existing assertion: `reader_surface_test.dart:102` -> `'✓ Rated Easy - next answer'`, and its trailing `pump()` becomes `pumpAndSettle()` (the toast now follows an awaited drift write). Delete the stale `reader_screen.dart:16-17` fixture comment as part of the swap.

- [ ] **Step: failing wiring test** (ProviderScope with `remoteOverrides` + stub adapter boots to Sign-in with no stored JWT; with a stored JWT + stubbed `/manifest` 200 + silent re-auth it lands Home) - follow the exact test harness pattern of Tasks 2/3.
- [ ] **Step: failing reader-binding test** `app/test/ui/reader/reader_queue_wiring_test.dart` - pump `const ReaderScreen.queue()` inside a `ProviderScope` overriding `appDatabaseProvider` -> `AppDatabase(NativeDatabase.memory())`, `contentRepositoryProvider` -> a fake serving one seeded `QnaRow`, and `dueQueueProvider` -> `['QN1']`; tap "Reveal model answer" -> "Easy" -> `pumpAndSettle`; assert exactly one row in `db.pendingReviewEvents` (proves `onRate` routed through `ReaderController.rate` -> `StudyRepository.recordRating`, not the deleted fixture `_rated` flag) and the `✓ Rated Easy - next answer` toast appears only after the persist. Mirror the in-memory-drift harness in `app/test/ui/reader/rating_debounce_widget_test.dart`. This is the unit-level foundation Task 8's E2E activation path builds on.
- [ ] **Implement both (production wiring + reader binding), run, PASS, commit** - follow the exact test harness pattern of Tasks 2/3.

```bash
git commit -m "feat(app): production wiring - remote overrides, dart-define config, lifecycle flush"
git commit -m "feat(app): wire ReaderController into ReaderScreen - real queue view, persist-before-toast rate, browse rate-then-stay"
```

---

### Task 6: Sentry init + scrub test (ENG-T9 slice)

**Files:**

- Modify: `app/lib/main.dart` (SentryFlutter.init wraps runApp)
- Create: `app/lib/sentry_scrub.dart`
- Test: `app/test/sentry_scrub_test.dart`

**Interfaces:**

- Consumes: nothing new (sentry_flutter).
- Produces: `FutureOr<SentryEvent?> scrubEvent(SentryEvent event, Hint hint)` set as `options.beforeSend`; `options.beforeBreadcrumb` strips request/response bodies.

Scrub rules (licensed IP + tokens must never leave the device): drop `event.request`; walk `event.exceptions/values`, `message`, `breadcrumbs`, `extra`, `contexts` and redact any string matching `RegExp(r'Bearer [A-Za-z0-9._-]+')` -> `Bearer [redacted]`; drop any breadcrumb whose `data` contains keys `body`, `sections`, `body_md`, `question` (answer text); cap breadcrumb messages at 200 chars.

- [ ] **Step 1: failing test** - build a `SentryEvent` carrying (a) a breadcrumb with `data: {'body': '<answer text>'}`, (b) an exception value containing `Bearer eyJhbGciOi...`, (c) `extra: {'question': 'Describe the TAP block'}`; assert the scrubbed event contains none of: `TAP block`, `Bearer ey`, the answer text; assert an unrelated message survives.
- [ ] **Step 2-4:** implement `scrubEvent`, wire `SentryFlutter.init((o) { o.dsn = const String.fromEnvironment('SENTRY_DSN'); o.beforeSend = scrubEvent; ... }, appRunner: ...)`; PASS; commit `feat(app): sentry with IP/JWT scrubbing (no answer text, no tokens)`.

---

### Task 7: Play signing + OAuth clients + compliance checklist (ENG-T4, ENG-T19 rest)

**Files:**

- Create: `docs/release-checklist.md`

No code - a checklist with EXACT console steps; each line is checkable and blocking for the internal-track rollout. Content (write all of it):

1. **Google Cloud Console -> Credentials**: one WEB client (its id = server `GOOGLE_WEB_CLIENT_ID` config var AND the app's `GOOGLE_SERVER_CLIENT_ID` dart-define); one ANDROID client per signing key: package `com.diplomate.diplomate`, debug SHA-1 (`cd android && ./gradlew signingReport` -> `SHA1` of `debug`), AND the **Play App Signing** SHA-1 (Play Console -> Setup -> App integrity -> App signing key certificate -> SHA-1). Missing the Play SHA-1 = sign-in works locally, DEVELOPER_ERROR for every beta tester (ENG-T4).
2. **OAuth consent screen: PUBLISHED**, not Testing (Testing 401s any non-allowlisted Gmail - would brick week-one sign-ins; outside voice #5). Scopes: openid/email/profile only.
3. **Play Console**: app created; **account-type check** - a NEW personal developer account carries a 12-tester/14-day closed-testing gate before production; verify which account type this is and record the implication for the TODOS 4 recruiting clock.
4. **Data Safety form** answers (write them in the checklist verbatim): collects email + name + photo (account management), app activity = study events (analytics, app functionality), no location, no ads, data encrypted in transit, deletion path = in-app + `https://<app>.herokuapp.com/account/delete`.
5. **Store listing**: privacy policy URL = `https://<app>.herokuapp.com/legal/privacy`; listing checklist rows (title, short/full description, screenshots from the built app, category Education).
6. **Release smoke** (blocks every rollout): upload internal-track AAB -> install via Play link on a real device -> sign in with a NON-allowlisted Gmail -> speciality pick -> open a topic -> first recall -> verify the events row count grew (`heroku pg:psql -c "SELECT count(*) FROM review_events"`). This is the T2/T4 DEVELOPER_ERROR canary.
7. **Deploy smoke** (server, after every `git push heroku main`): `curl -fsS https://<app>.herokuapp.com/health`; migrations applied in order; then step 6's app pass.

- [ ] **Step: write the file, review against ENG-T19/T4 sources, commit** `docs(release): Play signing, consent, Data Safety, smoke checklists`.

---

### Task 8: Activation-path integration test + metrics E2E sanity (deploy smoke rehearsal)

**Files:**

- Create: `app/integration_test/activation_path_test.dart`
- Create: `server/test/e2e_metrics_sanity.test.js`
- Create: `.github/workflows/app-ci.yml`

**Interfaces:**

- Consumes: everything.
- Produces: the CI-checkable activation path; the lane-D exit criterion.

- [ ] **Step 1: `app/integration_test/activation_path_test.dart`** - runs against a LOCAL server (`node server/src/index.js` with the test DB seeded by the ingestion fixture publisher) using `remoteOverrides(apiBaseUrl: 'http://10.0.2.2:3000', ...)` and a `FakeGoogle` override injecting a stubbed Google verifier token accepted by a test-mode server flag - simpler and honest: override ONLY `authRepositoryProvider` with the fake (auth E2E is covered by the release smoke on a real device, checklist Task 7 step 6); everything else real. Flow asserted: boot -> Sign-in -> (fake) continue -> Speciality pick (Anaesthesiology) -> Home shows the funnel row -> tap "Start here" -> Topics loads (real `/chapters` fetch) -> open QnA -> reveal -> rate Easy (the Reader screen routes reveal/rate through plan-5's `ReaderController` -> `StudyRepository.recordRating`, wired in Task 5) -> `SyncService.flush()` -> assert `POST /sync/review-events` landed (query the test DB through the server or expose the stub's hit log). Wall-clock budget assertion: the browse-to-first-recall stretch completes without any 35s timeout firing (the <3min budget's automatable slice; the real 4G measurement is checklist step 6).
- [ ] **Step 2: `server/test/e2e_metrics_sanity.test.js`** - seed one honest user journey through the REAL sync endpoints (supertest), then execute all three `sql/metrics/*.sql` files and assert: activation 1, valid_recall_topics 1, d7 0 - proving the pack runs against API-shaped data, not just hand-inserted rows.
- [ ] **Step 3: `.github/workflows/app-ci.yml`** - `flutter test` on push to `app/**` (integration_test runs on a maintainer machine/emulator, not CI - note it in the workflow comment; CI/CD to Play stays deferred, TODOS 1).
- [ ] **Step 4: run both suites, PASS, commit** `test: activation-path integration + metrics E2E sanity + app CI`.

---

## Coverage

| Source task / lock                                                                                                                                                                            | Plan task(s)                                                                         |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| ENG-T7 auth hardening (state machine FIRST, google_sign_in v7 + serverClientId, secure storage, weeks-offline 401 -> re-auth -> queued events survive)                                        | Tasks 1, 2 (survival of queued events: Task 4 drains drift regardless of auth epoch) |
| ENG-T1 (as amended by NO OFFLINE DOWNLOADS): on-demand paginated fetch, lazy images with If-None-Match, one-transaction chapter refresh, inline retry; NO atomic-install/resume/RSS machinery | Task 3                                                                               |
| ENG-T10 sync backoff + jitter on 401/5xx, no retry storm; egress/plan-limit + dyno-tier notes                                                                                                 | Task 4 (backoff), Task 7 + server README (ops notes)                                 |
| ENG-T4 Play App Signing SHA-1 registered; release smoke = sign-in on Play-signed build                                                                                                        | Task 7 (steps 1, 6)                                                                  |
| ENG-T19 (rest): Data Safety, consent PUBLISHED, account-type gate, listing checklist                                                                                                          | Task 7                                                                               |
| DESIGN-T3 funnel (as amended): land Home post-onboarding, "Start here" into highest-weight chapter, <3min budget (automatable slice + device measurement)                                     | Tasks 5, 8                                                                           |
| ENG-T9 Sentry scrub (no answer text, no JWTs)                                                                                                                                                 | Task 6                                                                               |
| D5 addendum client half: X-Refreshed-Token stored mid-batch without interrupting                                                                                                              | Tasks 1 (interceptor), 4 (batch continues)                                           |
| T4/T5 test-plan rows: poison-row fallback client side, long-offline re-auth + queued-event survival, backoff + jitter                                                                         | Tasks 2, 4                                                                           |
| Deploy smoke (2A): push -> /health -> sign-in + one chapter fetch on the deployed dyno                                                                                                        | Task 7 (steps 6-7), Task 8 (rehearsal)                                               |
| Metrics pack E2E (CEO-T3 validation)                                                                                                                                                          | Task 8                                                                               |
| Offline-rating persistence rows ("rate offline -> persists -> syncs")                                                                                                                         | plan 5 owns persistence; Task 4 proves the sync half                                 |

Out of scope (owned by neighboring plans):

- Screens/theme/a11y: `2026-07-04-flutter-shell-screens.md`. drift schema, Leitner, ReaderController, notification, event writers: `2026-07-04-study-loop-srs.md`. API + contract suite + metrics SQL: `2026-07-04-server-api.md`. DDL + seed: `2026-07-04-day1-content-ddl.md`. Content publishing: `2026-07-04-ingestion-pipeline.md`.
- Founder-only: CEO-T1 term sheet, CEO-T6..T9, TODOS 1-5/7 (billing+CI/CD to Play, FSRS, watermark decision, recruiting, object-storage migration) - deferred slices, no tasks here.
