# <Wiki Name> - LLM Wiki Rules

> Built on [Andrej Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
> This file defines how AI agents maintain the embedded project wiki.

## Source And Output Boundary

- The project root is the source material. Read the existing code, docs, configs, issues, and notes in this directory.
- Write generated summaries, concept pages, synthesis, diagrams, indexes, and operation logs only under `llm-wiki/`.
- Do not ask the user to copy material into `raw/`. This workflow does not use a `raw/` folder.
- Do not modify project source files or original documents unless the user explicitly asks for that.

## Default Exclusions

Ignore `llm-wiki/`, `.git/`, `.obsidian/`, `node_modules/`, `vendor/`, `dist/`, `build/`, `.next/`, `target/`, generated caches, binary files, archives, and secret files such as `.env*`.

## Graphify Map Layer (Optional)

When Graphify is enabled, `graphify-out/` is the structural map layer and `llm-wiki/` is the durable knowledge layer.

- When `graphify-out/GRAPH_REPORT.md` exists, read it first for architecture, dependency, module relationship, and cross-file connection questions.
- Use `graphify-out/graph.json` or Graphify query commands when useful, then verify important conclusions against source files.
- Do not automatically merge Graphify `--wiki` output into `llm-wiki/`.
- Store reusable, verified explanations in `llm-wiki/summaries/`, `llm-wiki/concepts/`, or `llm-wiki/synthesis/`.

## Directory Structure

```text
<project>/
├── llm-wiki/
│   ├── concepts/
│   ├── summaries/
│   ├── synthesis/
│   ├── archived/
│   ├── assets/
│   │   └── excalidraw/
│   ├── canvas/
│   ├── templates/
│   ├── Index.md
│   ├── Changelog.md
│   └── Overview.md
├── .obsidian/
├── AGENTS.md
└── <project source files>
```

## Page Format

Every maintained wiki page should include frontmatter:

```yaml
---
title: Page Title
type: entity | concept | topic | comparison | source | synthesis
tags: [tag1, tag2]
aliases: []
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: []
confidence: high | medium | low
---
```

When creating a page, read the matching file in `llm-wiki/templates/` first and follow its structure.

## Workflows

### Analyze

When asked to analyze the project:

1. Scan the project root while respecting the exclusions above.
2. Create source summaries under `llm-wiki/summaries/`.
3. Create concept pages under `llm-wiki/concepts/`.
4. Create cross-cutting analysis under `llm-wiki/synthesis/`.
5. Update `llm-wiki/Index.md` and append the operation to `llm-wiki/Changelog.md`.

### Query

When answering questions:

1. Prefer existing `llm-wiki/` pages first.
2. Read source files only when the wiki is incomplete or the user asks for fresh inspection.
3. Cite wiki pages with `[[wikilinks]]` when possible.
4. Save durable analysis under `llm-wiki/synthesis/` when the answer creates reusable knowledge.

### Lint

When asked for a health check, inspect `llm-wiki/` for stale pages, orphan pages, dead links, duplicate concepts, missing summaries, and index drift. Record the result in `llm-wiki/Changelog.md`.

## Visuals

- Store Excalidraw files under `llm-wiki/assets/excalidraw/`.
- Store Obsidian Canvas files under `llm-wiki/canvas/`.
- Use Mermaid inline for simple sequence, state, and flow diagrams.

## Safety

- Never move, rewrite, or delete source files as part of analysis.
- Never write secrets or private local paths into wiki pages unless the user asks for that explicitly.
- Treat `llm-wiki/detected-paths.json` as local configuration, not source material.

