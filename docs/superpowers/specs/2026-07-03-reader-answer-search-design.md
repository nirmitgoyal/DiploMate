# Reader in-answer search — design

Date: 2026-07-03
Scope: `prototype/index.html` only (Direction B demo).

## What

Ctrl-F-like search inside the currently open QnA's revealed answer. Typo-tolerant
substring search. One QnA at a time — no cross-answer corpus. No autocomplete
(explicitly cut by user).

## UI

- Search icon (`I.search`) in reader topbar, wrapped `after-only` — visible only
  once the answer is revealed (preserves recall gate; approved).
- Tap → search bar pinned below the crumb: text input · match counter `n/N` ·
  prev/next arrow buttons · close (✕).
- All matches wrapped in teal `<mark>`; active match styled amber; active match
  auto-scrolled into view.
- Keyboard: Enter = next match, Shift+Enter = prev, Escape = close.

## Matching

- Scope: text nodes under `.answer` — marks-scheme list (`.earn`), sections
  (`.asec`), summary. Excluded: diagram SVG text, `.rcount`, `.tray`.
- Case-insensitive. Query split on whitespace into words.
- A query word matches a target word if:
  - substring of it (covers partial words: `transv` → transversus), OR
  - Levenshtein distance ≤ 1 for target words ≥ 4 chars, ≤ 2 for ≥ 7 chars.
- Multi-word query matches a run of consecutive words where each query word
  matches in order (`muscle layers`, `tranversus abdominis` with typo).
- Matching runs per text node (words don't cross inline-tag boundaries in this
  content; accepted prototype limitation).

## Lifecycle

- Opening search snapshots each searchable element's original `innerHTML`.
- Clearing query / closing / rating a card / `setReader('before')` / leaving the
  screen restores snapshots — `<b>` formatting preserved.
- State is per-phone (one phone rendered, but code follows existing per-root
  event-delegation pattern).

## Non-goals

- Autocomplete / suggestions (cut).
- Cross-answer or global search.
- Search before reveal.
- Any dependency; vanilla JS in the existing single file.

## Verify (manual, preview server)

1. Reveal answer → search icon appears; before reveal it doesn't.
2. `tranversus` (typo) highlights **transversus**; `hydrodisection` highlights
   **hydrodissection**; `petit` highlights **Petit's**.
3. `muscle layers` phrase-matches; counter shows correct `n/N`; prev/next cycles
   and scrolls.
4. Close/rate restores answer HTML exactly (bold intact, no stray `<mark>`).
5. No console errors.
