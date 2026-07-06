# TODOS

Deferred work captured by /plan-eng-review (2026-07-03). Each item was
explicitly accepted by the founder - these are scheduled slices, not wishes.
Source plan: `~/.gstack/projects/nirmitgoyal-DiploMate/nirmit-main-design-20260702-234555.md`.

## 1. Billing + CI/CD slice (gates open beta)

- **What:** Integrate in-app billing (Play Billing or alternative under Google's 2026 billing programs) + paywall UI + automated GitHub Actions → Play Console pipeline.
- **Why:** Approved eng-review scope trim (D2) deferred both out of v1 closed beta. Open beta cannot charge strangers or sustain release cadence without them.
- **Pros:** Charge users at open-beta scale; every merge auto-lands on testers' phones; removes founder-in-the-loop for entitlements.
- **Cons:** ~1-2 weeks (human) / ~2-3 days (CC); billing review adds Play submission risk; needs pricing decision (doc's Open Question 3) resolved first.
- **Context:** v1 beta uses manual UPI pre-payments + hand-set entitlement flags in Heroku Postgres (T5 ops runbook) + manual `flutter build appbundle` uploads. The entitlement flag is in the schema from day one - this slice only adds payment rails and automation, no data-model change.
- **Depends on / blocked by:** Study-loop validation (leading metric green on ≥30 activated users); pricing model decision; content licensing signed.

## 2. FSRS migration (post-v1 scheduler upgrade)

- **What:** Replace the 3-bucket Leitner scheduler with FSRS via the official Dart `fsrs` package (pub.dev/packages/fsrs), replaying each user's full `review_events` log to initialize card state.
- **Why:** FSRS schedules measurably better than Leitner; the append-only event log (D4) was chosen specifically so this upgrade costs no user their history.
- **Pros:** Better retention-per-review for exam-critical users; no cold start - log replay preserves every user's scheduling state; well-maintained upstream algorithm.
- **Cons:** ~2-3 days (human) / ~0.5 day (CC); rating scale mapping (wire enum `{again,hard,good}` - UI "Hard/Medium/Easy" since 2026-07-04 - onto FSRS's 4-point) needs a decision; changes review-load feel mid-product for existing users.
- **Context:** v1 Leitner spec is locked in the design doc (D10): B1=1d, B2=3d, B3=interval×2, 4am local rollover. `review_events` is immutable and idempotent (client UUID), so replay is deterministic.
- **Depends on / blocked by:** v1 shipped; enough review history to make FSRS meaningfully better (~weeks of usage data).

## 3. Piracy posture: per-user watermarking decision

- **What:** Decide and (if yes) implement lightweight per-user watermarking of rendered content (e.g., account email faintly overlaid on answer views / diagram scans).
- **Why:** Content already leaks free on Telegram (doc's Open Question 5). The rights-holder will ask what deters paying users from re-dumping. Watermarking is the cheap deterrent short of DRM theater.
- **Pros:** Traceable leaks deter casual redistribution; cheap (~1 day CC); signals seriousness to the licensor in negotiations.
- **Cons:** Trivially cropped/blurred by determined pirates; slight visual noise on the product; can feel accusatory to honest users if heavy-handed.
- **Context:** v1 anti-scrape baseline is already locked: unpurchased packs never reach the device, no bulk export, offline/revocation grace policy (T6). Perfect DRM is explicitly out of scope. This TODO is only the watermark yes/no + implementation.
- **Depends on / blocked by:** Licensing agreement terms (licensor may require or reject it); T6 policy doc.

## 4. Cohort recruiting plan (≥30 activated users)

- **What:** A written plan to recruit ≥30 activated beta users (opened ≥1 topic) from Telegram/Instagram/WhatsApp channels where DNB Anaesthesia PYQ PDFs already circulate. **Recruiting target = 45-50 installs (2026-07-04 eng review, outside voice #1):** activation is <100% and empty-track picks are cohort-excluded, so a 30-install recruit cannot start TD4's decision clock ("4 weeks after the 30th activated user"). Name a channel owner per channel.
- **Why:** Codex (adopted, D11): the 40% recall / D7≥30% success metrics are statistically meaningless on 5 users. Below 30 activated users, numbers are qualitative only - the experiment needs a real cohort to conclude anything.
- **Pros:** Makes the ONE experiment v1 runs actually decidable; forces the go-to-market channel work early (it's the distribution plan anyway); tester list doubles as the pre-sale pipeline.
- **Cons:** Founder time in channels (~days, not delegable to CC); risks exposing the product to content-dump communities pre-launch; Play closed-beta tester list management overhead.
- **Context:** The 5-finalist Assignment (watch them use hide→reveal, get one pre-payment) stays qualitative and happens BEFORE code. This TODO is the quantitative cohort for the in-app metric, recruited via the "Conceptual Anesthesia" audience per the distribution plan.
- **Depends on / blocked by:** The Assignment's pre-sale signal (don't recruit 30 before 1 person pre-pays); closed beta build on Play internal track.

## 5. Migrate diagram images from Postgres bytea to object storage

- **What:** Move WebP diagram scans out of Heroku Postgres bytea columns into object storage (Cloudflare R2 or S3) with entitlement-checked delivery; bundle semantics on the client stay identical.
- **Why:** The bytea decision (2026-07-03, carried through the 2026-07-04 Heroku revision) keeps ALL content (text + images) behind one server-side gate with zero extra services - correct for beta scale, but bytea images have a ceiling: DB size growth and egress cost as users × specialities grow.
- **Pros:** Cheaper egress at scale (R2 egress is free); smaller database (Heroku Postgres plans are size-capped); faster bundle downloads via CDN.
- **Cons:** Reintroduces a second storage system + a signed-URL component (the API itself or a CF Worker); migration script for existing content; two delivery paths during transition.
- **Context:** Design doc D3 (revised) carries the `ponytail:` ceiling note. Trigger: dyno bandwidth / Postgres plan-size line item becomes noticeable, OR speciality count × pack size makes bundle fetches slow. Client repository pattern isolates the change - only the bundle-fetch implementation swaps. **Trigger moved up (2026-07-04 eng review):** Heroku Postgres Essential-0 caps storage at 1GB - beta Anaesthesia bytea (≤~360MB) fits, but the full-catalog load (billing slice, per TD3 sequencing) exceeds it. Interim remedy = Postgres plan upgrade (Essential-1 10GB) at catalog load; decide plan-upgrade vs this R2/S3 migration at that point, not during beta.
- **Depends on / blocked by:** Real scale signal (do NOT do this during beta).
- **Content-pass intersection (2026-07-06 eng review):** the book-grounded answer pass adds scanned Miller figures (WebP ≤200KB each) to bytea for every populated chapter (~150 max). The pilot chapter measures figure bytes/chapter; project that number × populated chapters against the Essential-0 1GB cap BEFORE the full pass publishes. If projection exceeds ~700MB, decide Essential-1 upgrade vs this migration at that point.

## 6. Design-review deferrals (2026-07-04 /design-review pass)

Fixed in that pass (14 commits, `58bad81`…`3c5070c`): touch targets ≥44px,
teal-as-text law, type scale (7 steps, zero drift), overline tracking, 18px
gutter + 8px topbar, CTA glow removal, 8/12 radii, tabular-nums coverage,
200ms reveal motion, dark `--ink-3` AA (`#908878`), marks reconciliation,
18-chapter one-truth data, one diagram affordance, DESIGN.md↔spec alignment.
Full report: `~/.gstack/projects/nirmitgoyal-DiploMate/designs/design-audit-20260703/`.

Deferred, in priority order:

- **Night Desk demo surface** (medium, color): `.dir-c` tokens are defined and
  now AA-verified but unreachable in the prototype (founder-descoped: "ships
  via D20 tokens"). When Flutter lands the theme toggle, re-run contrast QA on
  the real dark surfaces.
- **Flutter a11y: rows must be real focusable widgets** (medium, interaction):
  prototype syllabus/topics/bookmarks rows are `div.row` with cursor:pointer -
  no keyboard/TalkBack path. Speciality rows (`button role="radio"`) model the
  correct pattern. D20 TalkBack order is non-negotiable in the build.
  _Expanded by /autoplan design review (2026-07-04) into the executable pack:_
  visible focus styles; roving radio focus + arrow keys on the speciality
  list; `aria-current` on nav; toast + auto-advance announcements; diagram
  content descriptions; fullscreen-viewer focus trap + restore; per-screen
  TalkBack semantic order; keyboard acceptance tests; **48dp is the build
  floor** (44px was the HTML-demo compromise).
  _Landed as DESIGN.md "A11y Executable Pack" + lane-B test suite
  (2026-07-04 plan `2026-07-04-flutter-shell-screens.md`)._
- **Second authored QnA for the demo loop** (polish, content): rating "Easy"
  toasts "next answer" then reloads the same TAP-block question (overline
  stuck at "Suggestion · 3 of 12"). One more authored answer makes the recall
  loop demo honest end-to-end. (2026-07-04: the "Due today" chip and done/due
  counter no longer exist - only the stuck overline remains as the tell.)
- **Internal-padding regrid to the 4px scale** (polish, spacing): census still
  has 6/9/10/13/14px internal paddings. Named-law violations are fixed; do the
  blanket regrid in Flutter where the spacing scale is enforced at widget level.
- **Dead code sweep in prototype** (polish): `.dir-a` theme (lacks
  `--exam-red`), `.lz.done/.upd/.fail` lozenges (`.lz.upd` amber-on-amber =
  4.32:1 - fails AA if ever used), `.sheet .support`, `.agenda .sub`, unused
  icons (down/mic/sync/hd/fail). Flagged, not deleted (pre-existing).

## 7. Strategy work from /autoplan CEO review (2026-07-04)

Cross-model CEO findings the founder must feed with data no model has. All
are plan-doc additions, not code. Source: autoplan Phase 1 (subagent
F5/F8/F12/F14 + Codex #7/#9); tasks-ceo-review JSONL T6-T9.

- **Market-math table** (P3, founder ~2h): finalists/cycle × current PDF price
  × realistic attach, for Anaesthesia and expansion axis-2 (incl. the MD/MS
  university-exam cohort question). Both models: "people pay" is category
  evidence, not a number; the 61-track intent (PG2) makes per-track economics
  the roadmap's denominator.
- **Exam-calendar back-schedule** (P3, founder ~1h): name the target DNB
  session; back-schedule beta-live, cohort recruiting (TODO 4), and the
  experiment decision date from it. Persona is countdown-defined; missing the
  session resets the cohort ~6 months.
- **B2B2C channel one-pager** (P3, founder ~2h): hospital coordinators /
  coaching brands as cohort-scale distribution; one friendly pilot could
  satisfy TODO 4's ≥30-user floor outright. Decide alongside the licensing
  term sheet (brand architecture: DiploMate vs co-brand).
- **NExT regulatory watch + incumbent response note** (P3, ~15min): any NExT
  progress pulls Marrow/PrepLadder into exit-exam prep wholesale; strategy =
  speed + exclusivity (PG1) + recall-history switching cost (PG4). One
  paragraph in the plan; revisit quarterly.

## 8. Embedding retrieval index for the answer generator (trigger-gated)

- **What:** Build an embedding index over the Miller page index and switch Stage 3 retrieval from keyword/section matching to hybrid (keyword + vector) retrieval.
- **Why:** Content-pass design (2026-07-06) Open Q2: if the pilot's flag rate is inflated by retrieval MISSES (the book covers the question but keyword retrieval never surfaces the page) rather than true coverage gaps, keyword-only retrieval is leaving answerable questions in the manual queue.
- **Pros:** Recovers answerable questions from the flag queue without manual authoring; one-time offline cost, no runtime component; shrinks founder's manual-writing backlog.
- **Cons:** ~0.5-1 day (CC); adds an embedding dependency + index artifact to the generator; useless if the pilot shows flags are true coverage gaps (Indian protocols, guidelines Miller doesn't cover).
- **Context:** Generator retrieval is deliberately lazy (keyword over pdftotext page index). The pilot chapter measures flag rate AND flag reasons; only `no-source-coverage` flags where a human can point at the covering Miller page count as retrieval misses. Start: generator's retrieval module, swap behind the same interface.
- **Depends on / blocked by:** Pilot flag-rate data with reason taxonomy; only build if retrieval-miss share is material.

## 9. Figure-crop batch review UI (trigger-gated)

- **What:** A minimal local web UI for reviewing model-proposed figure crop boxes in bulk: page render + proposed bbox overlay, approve/adjust/reject per figure, writes crops to the chapter's images/ dir.
- **Why:** Content-pass Stage 3 has a human verifying every figure crop (model proposes bbox, human confirms). Fine for the pilot chapter; at ~150 populated chapters the per-figure click cost may dominate the founder's review time.
- **Pros:** Turns hours of image-editor fiddling into an approve/adjust queue; keeps the human-verified guarantee the design requires; reusable for future books/specialities.
- **Cons:** ~1 day (CC) building tooling that may never be needed if figures-per-chapter is low; another local tool to maintain; design explicitly scoped it out until proven necessary (Open Q6).
- **Context:** Pilot measures figures-per-chapter and per-figure review seconds. Trigger: projected total figure-review time exceeds ~a founder-day. Start: generator's figure sub-task output (page PNG + bbox JSON) is already the exact input this UI needs.
- **Depends on / blocked by:** Pilot throughput data; figure pipeline landed (content-pass Stage 3).
