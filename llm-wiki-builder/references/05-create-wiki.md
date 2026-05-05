# Stage 5: Initialize Embedded `llm-wiki`

This stage initializes the current project as the source material and writes generated wiki scaffold files under `<project>/llm-wiki`.

It must not create a separate `repo-wiki` directory and must not create or require `raw/`.

## Inputs

Use host CLI prompts unless values were supplied by parameters.

1. **Project root** - `--dir <project>`, `LLM_WIKI_DIR`, or the current directory.
2. **Language** - `en` or `zh`.
3. **Wiki display name** - `--name`, otherwise the project directory name.

Compute:

```bash
PROJECT_ROOT="<resolved project root>"
WIKI_TARGET="$PROJECT_ROOT/llm-wiki"
```

## Template Copy

Download or locate the starter template, then copy only missing scaffold files:

```bash
mkdir -p "$WIKI_TARGET"
cp -Rn "$TEMPLATE_ROOT/$LANG/wiki/." "$WIKI_TARGET/"
cp -Rn "$TEMPLATE_ROOT/$LANG/templates/." "$WIKI_TARGET/templates/"
```

Do not overwrite existing user analysis pages. Re-runs should only backfill missing files.

## Required Directories

For `lang=zh`:

```bash
mkdir -p "$WIKI_TARGET"/{概念,资料摘要,综合分析,归档,assets/excalidraw,canvas,templates}
```

For `lang=en`:

```bash
mkdir -p "$WIKI_TARGET"/{concepts,summaries,synthesis,archived,assets/excalidraw,canvas,templates}
```

There must be no `llm-wiki/wiki/` and no `raw/`.

## Placeholder Replacement

Replace `<Wiki Name>`, `<wiki-name>`, and `{{date}}` only in files that were copied into `llm-wiki/`.

Chinese files:

- `llm-wiki/知识库概览.md`
- `llm-wiki/Wiki 目录.md`
- `llm-wiki/操作日志.md`

English files:

- `llm-wiki/Overview.md`
- `llm-wiki/Index.md`
- `llm-wiki/Changelog.md`

## `AGENTS.md`

If `AGENTS.md` does not exist in the project root, create it with the llm-wiki managed block.

If it already exists, use a managed block:

```html
<!-- llm-wiki-builder:start -->
...
<!-- llm-wiki-builder:end -->
```

Interactive mode should ask the user to choose:

1. Append a managed block or update the existing managed block.
2. Back up and replace `AGENTS.md`.
3. Write sidecar rules to `AGENTS.llm-wiki.md`.

Non-interactive `--yes` defaults to append/update and must not overwrite user content.

The managed block must say:

- The project root is the source material.
- Output goes under `llm-wiki/`.
- Exclude `llm-wiki/`, `.git/`, `.obsidian/`, dependencies, build outputs, binaries, and secrets.
- Do not modify project source unless explicitly asked.
- If `--with-graphify` is enabled, `graphify-out/` is the project map layer and `llm-wiki/` remains the durable wiki layer. Agents should read `graphify-out/GRAPH_REPORT.md` first for architecture and relationship questions, then write verified durable conclusions under `llm-wiki/`.

## Verify

After this stage:

- `<project>/llm-wiki` exists.
- `<project>/AGENTS.md` exists or sidecar mode wrote `AGENTS.llm-wiki.md`.
- `llm-wiki/wiki/` does not exist.
- `raw/` was not created.
- Re-running does not duplicate the managed block.
- With Graphify enabled, `.graphifyignore` exists and Graphify rules are present in the managed block.

