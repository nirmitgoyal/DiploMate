# Release checklist

Blocking checklist for every internal-track rollout of DiploMate. Every step
is a hard gate - if a box isn't checked, the rollout is not internal-track
ready. Placeholders: `<app>` = the Heroku app name (e.g. `diplomate-api`,
giving `https://diplomate-api-05ad7adbd176.herokuapp.com`); `<web-client-id>` = the Google
Cloud WEB OAuth client id (e.g. `<web-client-id>.apps.googleusercontent.com`).

This checklist covers ENG-T4 (Play App Signing SHA-1) and the rest of
ENG-T19 (Data Safety, consent screen, account-type gate, store listing).

## 1. Google Cloud Console -> Credentials

- [ ] Exactly one **WEB** OAuth client exists in Google Cloud Console ->
      APIs & Services -> Credentials -> OAuth 2.0 Client IDs.
- [ ] The WEB client id is set as the server's `GOOGLE_WEB_CLIENT_ID` config
      var: `heroku config:get GOOGLE_WEB_CLIENT_ID --app <app>` returns the
      same id shown in the console.
- [ ] The WEB client id is also the app's `GOOGLE_SERVER_CLIENT_ID`
      dart-define value used at build time:
      `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com`.
- [ ] One **ANDROID** OAuth client exists for package `com.diplomate.app`
      with the **debug** signing key's SHA-1 registered. Get it with
      `cd android && ./gradlew signingReport`. Copy the `SHA1:` value from
      the `debug` variant block and confirm it matches the SHA-1
      fingerprint on the ANDROID client in Google Cloud Console.
- [ ] The **upload keystore's** SHA-1 is also registered on the ANDROID
      OAuth client. Get it with
      `keytool -list -v -keystore ~/keystores/diplomate-upload.jks -alias upload | grep "SHA1:"`
      (see `docs/android-release-runbook.md` section 1).
- [ ] A second **ANDROID** OAuth client entry (or an additional SHA-1 on the
      same client) exists for the **Play App Signing** key's SHA-1. Get it
      from Play Console -> Setup -> App integrity -> App signing key
      certificate -> SHA-1 certificate fingerprint. Confirm it matches an
      entry in Google Cloud Console.
- [ ] **Blocking fact, verify it explicitly:** if the Play App Signing SHA-1
      is missing, sign-in works on every local/debug build but fails with
      `DEVELOPER_ERROR` for every beta tester who installs from the Play
      Store, because Play re-signs the AAB with its own key before
      distributing it (ENG-T4). Do not skip this step because local sign-in
      already works.
- [ ] An **iOS** OAuth client exists for bundle id `com.diplomate.app`, and
      its client id matches both `GIDClientID` and the reversed-id URL
      scheme in `app/ios/Runner/Info.plist` (see
      `docs/android-release-runbook.md` section 2).

## 2. OAuth consent screen

- [ ] OAuth consent screen publishing status is **PUBLISHED**, not
      **Testing**. Check at Google Cloud Console -> APIs & Services -> OAuth
      consent screen -> Publishing status.
- [ ] Confirm the reason this matters: in **Testing** status, Google returns
      a 401 for any Gmail account not explicitly added to the test-user
      allowlist. That would brick sign-in for every beta tester in the first
      week, since testers are not pre-added to any allowlist.
- [ ] Scopes configured on the consent screen are exactly `openid`, `email`,
      and `profile` - no additional scopes requested.

## 3. Play Console: app + account-type gate

- [ ] The app is created in Play Console under package
      `com.diplomate.app`.
- [ ] **Account-type check (blocking, do not skip):** open Play Console ->
      Settings -> Developer account -> Account details and record whether
      this is a **personal** or **organization** developer account, and
      whether the account is **new** (created on or after the 2023 policy
      change).
- [ ] If the account is a **new personal developer account**, it is subject
      to a mandatory closed-testing gate before any production release: at
      least **12 testers** opted in continuously for at least **14 days**
      before Play allows a production track submission.
- [ ] Record the outcome of this check against TODOS item 4 (cohort
      recruiting plan). If the gate applies, the 12-tester/14-day closed
      track window must run concurrently with (not after) the 45-50 install
      recruiting push, or the production release date slips by the length
      of the gate.

## 4. Data Safety form

Fill in the Play Console -> App content -> Data safety form with exactly
these answers:

- [ ] **Data collected:** email address, name, and profile photo, declared
      under the **Account management** purpose.
- [ ] **App activity collected:** study events (topic opens, recall
      ratings), declared under both the **Analytics** and **App
      functionality** purposes.
- [ ] **Location data collected:** None. Confirm the location section is
      answered "No" / left empty.
- [ ] **Advertising or marketing data:** None. Confirm the ads section is
      answered "No" / left empty.
- [ ] **Data encryption in transit:** Yes, all collected data is encrypted
      in transit (HTTPS only).
- [ ] **Data deletion:** a path is provided both in-app (account deletion
      action inside app settings) and via web at
      `https://<app>.herokuapp.com/account/delete`. Both paths are declared
      on the form.

## 5. Store listing

- [ ] Privacy policy URL is set to `https://<app>.herokuapp.com/legal/privacy`
      in Play Console -> App content -> Privacy policy, and the URL
      resolves (not a 404) when opened in a browser.
- [ ] Store listing title is filled in.
- [ ] Store listing short description is filled in.
- [ ] Store listing full description is filled in.
- [ ] Screenshots are uploaded from the actual built app (not mockups or
      placeholder art) - at minimum the phone screenshot set required by
      Play Console.
- [ ] App category is set to **Education**.

## 6. Release smoke (blocks every rollout)

Run this end to end before promoting or announcing any internal-track
build. This is the T2/T4 `DEVELOPER_ERROR` canary - if sign-in fails here,
stop and fix section 1 before doing anything else.

- [ ] Upload the internal-track AAB to Play Console -> Testing -> Internal
      testing.
- [ ] Install the app via the Play Console internal-testing opt-in link on
      a real physical device (not an emulator).
- [ ] Sign in with a Gmail account that is **NOT** on the OAuth consent
      screen's test-user allowlist and is **NOT** a Google account already
      used on that device for development.
- [ ] Confirm sign-in succeeds (no `DEVELOPER_ERROR`, no 401).
- [ ] Pick a speciality.
- [ ] Open a topic.
- [ ] Complete a first recall (rate a card).
- [ ] Verify the event was written server-side - row count increased. Run
      `heroku pg:psql --app <app> -c "SELECT count(*) FROM review_events"`
      once before the recall and once after; confirm the count grew by at
      least 1.

## 7. Deploy smoke (server, after every `git push heroku main`)

Run this after every server deploy, before running section 6's app pass.

- [ ] Health check returns success. Run
      `curl -fsS https://<app>.herokuapp.com/health` and expect
      `{"ok":true}`.
- [ ] Every numbered migration file under `sql/` has been applied, in
      order, in this release (no skipped or out-of-order file numbers).
      Record the applied file numbers in the release notes.
- [ ] Immediately after the two checks above pass, run section 6's release
      smoke (release install -> non-allowlisted sign-in -> speciality pick
      -> topic open -> first recall -> `review_events` row count grew) to
      confirm the deploy didn't regress the client-facing path.
