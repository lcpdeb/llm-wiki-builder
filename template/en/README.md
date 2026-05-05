# <Wiki Name>

This project uses an embedded `.llm-wiki/` workspace based on the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

The current project directory is the source material. AI-generated summaries, concepts, diagrams, and synthesis pages live in `.llm-wiki/`.

## Quick Start

1. Open the project root in [Obsidian](https://obsidian.md).
2. Start your AI agent in the project root.
3. Ask it to analyze this repository and update `.llm-wiki/`.

## Operations

### Analyze

```text
Analyze this repository and update .llm-wiki
Summarize the architecture of this project
Create concept pages for the main domain terms
```

### Query

```text
What does this repository do?
How does module A depend on module B?
Compare the current implementation options
```

### Lint

```text
Run a health check on .llm-wiki
Find stale pages and missing links
```

## Structure

- `.llm-wiki/` - AI-maintained analysis output
- `.llm-wiki/concepts/` - concept pages
- `.llm-wiki/summaries/` - source summaries
- `.llm-wiki/synthesis/` - cross-cutting analysis
- `.llm-wiki/assets/` - attachments and diagrams
- `.llm-wiki/canvas/` - Obsidian Canvas files
- `.obsidian/` - Obsidian config and plugins
- `AGENTS.md` - shared rules for AI agents
