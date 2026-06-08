# Domain Docs

How engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- `CONTEXT.md` at the repo root, if it exists.
- `CONTEXT-MAP.md` at the repo root, if it exists.
- `docs/adr/`, if it exists.

If these files do not exist, proceed silently. Do not flag their absence or create them upfront.

## Layout

This is a single-context Flutter application:

```text
/
├── AGENTS.md
├── CLAUDE.md
├── lib/
├── test/
└── docs/
    └── agents/
```

## Domain vocabulary

- **Search source**: A user-configurable URL template containing `{query}`.
- **Bookshelf**: The local saved list of books.
- **Chapter**: A lazily loaded reading unit with optional `nextUrl`.
- **Paged catalog**: A chapter list that spans several catalog pages; service code follows catalog "next page" links and merges chapters before saving a book.
- **Reader settings**: Font, line height, theme, and horizontal page-turn animation settings.
- **Reader controls**: The app bar and previous/next chapter controls are hidden by default and toggled from the center tap zone.

Prefer these terms in issues, implementation notes, and future refactors.
