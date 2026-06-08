# AGENTS.md

This file provides guidance to Codex and other coding agents working in this repository.

## Project overview

不用搜书 (buyong-soushu) is a Flutter novel search and reading app. Users search books through configurable web search sources, parse generic novel websites, add books to a local bookshelf, and read chapters with horizontal page turns.

## Common commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues for `ZZzz1314520/buyong-soushu`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default five-label triage vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context Flutter app. Read root `CONTEXT.md` and `docs/adr/` if they exist, then proceed silently when they do not. See `docs/agents/domain.md`.

## Implementation notes

- State is owned by `AppController` and exposed through `ControllerScope`.
- Search sources are `SearchSource` values with a `{query}` URL template. `LocalLibrary.loadSources()` merges saved user sources with the built-in catalog so upgrades receive newly added defaults.
- `NovelParser` is intentionally generic. Prefer selector scoring, redirect unwrapping, and boilerplate filtering over site-specific parsing rules.
- Reading is horizontal page turning only. Legacy persisted `verticalScroll` and `tapSides` values are migrated to `horizontalFlip`.
