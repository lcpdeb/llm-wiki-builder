---
name: llm-wiki-builder
description: |
  Trigger when the user wants to create, scaffold, initialize, or configure an LLM Wiki for the current project.
  Chinese examples: 创建 llm-wiki 知识库, 搭建 wiki, 初始化项目 wiki, 配置 Obsidian wiki.
  English examples: create llm wiki, scaffold llm wiki, set up knowledge base, initialize project wiki, set up obsidian wiki.

  Initializes an embedded `llm-wiki/` workspace in the current project. The project root remains the source material; generated summaries, concepts, synthesis, visuals, and logs are written under `llm-wiki/`. Obsidian config and plugins are installed into the project root. The workflow does not create a separate `repo-wiki` vault and does not use `raw/`.
  Optional `--with-graphify` installs/registers Graphify as a separate project map layer under `graphify-out/` and keeps `llm-wiki/` as the durable wiki layer.

  Do not match for Lark/Feishu wiki, hosted wikis such as Notion or Confluence, or generic Obsidian note editing.
---

# llm-wiki-builder

Guide the user through setting up an embedded LLM Wiki for a project: detect installed tools, choose a supported AI agent when multiple are present, install missing dependencies where possible, initialize `llm-wiki/`, create or update `AGENTS.md`, and configure Obsidian for the project root.

The user is already running an AI agent. Do not prompt them to install another AI agent just to use this skill. For installer checks, Claude Code, Codex, Gemini, and OpenCode are supported; if more than one is installed, default priority is Claude Code > Codex > Gemini > OpenCode.

## When To Use

- Natural language requests such as "创建 llm-wiki 知识库", "搭建本地知识库", "create llm wiki", "scaffold llm wiki", or "set up knowledge base".
- Explicit command: `/llm-wiki-builder` with optional flags: `--bash`, `--name <display-name>`, `--lang <en|zh>`, `--dir <project>`, `--only-tools`, `--only-wiki`, `--only-obsidian`, `--with-graphify`, `--yes`.

If explicit parameters are provided, do not ask for those values again.

## Global Principles

1. Detect before installing. Skip anything already present.
2. Single-item failures do not block the whole run. Record clear manual follow-up items.
3. Respect the host OS and shell. Windows via Git Bash is supported first; macOS/Linux use the same public interface.
4. Use the host CLI's native prompt mechanism for interactive choices.
5. The workflow is idempotent for the project. Re-runs backfill missing `llm-wiki/` scaffold files, update the managed `AGENTS.md` block, and do not delete existing wiki pages.
6. Never ask the user to copy source material into `raw/`. The project root is the source layer.
7. Never install or configure Obsidian themes, Minimal theme, Minimal Settings, `appearance.json`, `cssTheme`, or `accentColor`.
8. Do not initialize a nested git repository for `llm-wiki/`; it belongs to the existing project.
9. Keep generated files UTF-8 with LF line endings.
10. When Graphify is enabled, keep `graphify-out/` separate from `llm-wiki/`; do not merge Graphify `--wiki` output into the embedded wiki.

## Workflow

Read the matching reference before acting on a stage.

| # | Stage | Reference |
|---|---|---|
| 0 | Entry alignment, OS detect, parameter handling | `SKILL.md` |
| 1 | Detect tools and paths | `references/01-detect-tools.md` |
| 2 | Base tools | `references/02-install-base.md` |
| 3 | Agent skills | `references/03-install-skills.md` |
| 4 | Obsidian app | `references/04-install-obsidian.md` |
| 5 | Embedded `llm-wiki` and `AGENTS.md` | `references/05-create-wiki.md` |
| 6 | Obsidian project config and plugins | `references/06-install-plugins.md` |
| 7 | Final summary | `references/07-finalize.md` |

## Stage 0: Entry Alignment

1. Detect OS with `uname -s` when bash is available. Treat Git Bash on Windows as the primary Windows shell.
2. If triggered by bare `/llm-wiki-builder` with no parameters, print one concise parameter hint:

   ```text
   Parameters (optional): --bash  --name <display-name>  --lang <en|zh>  --dir <project>  --only-tools  --only-wiki  --only-obsidian  --with-graphify
   No params given; continuing interactively.
   ```

3. Parse supported parameters. The three `--only-*` flags are mutually exclusive.
4. If `--bash` is passed, skip the skill-stage implementation and run upstream `install.sh` with `--yes`, forwarding supported flags:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/eleven-net-cn/llm-wiki-starter/main/install.sh \
     | bash -s -- --yes <forwarded params>
   ```

5. Otherwise continue through the workflow stages according to the selected mode.

## Parameter Reference

| Flag | Default | Behavior |
|---|---|---|
| `--bash` | off | Run upstream `install.sh` non-interactively and forward supported flags. |
| `--name <display-name>` | project directory name | Display title used in generated wiki pages. |
| `--lang <en|zh>` | `en` unless prompted | Template language. |
| `--dir <project>` | current directory | Project root. Output is always `<project>/llm-wiki`. |
| `--only-tools` | off | Install/detect tools only. Do not initialize `llm-wiki` or configure Obsidian. |
| `--only-wiki` | off | Initialize `llm-wiki` and `AGENTS.md` only. Do not configure Obsidian. |
| `--only-obsidian` | off | Configure Obsidian app, config, and plugins in the project root. |
| `--with-graphify` | off | Install/register Graphify, add `.graphifyignore`, and add Graphify map-layer rules to `AGENTS.md`. |
| `--yes` / `-y` | off | Use non-interactive defaults. Must not modify global config such as `~/.codex/config.toml`. |

## Agent Rule Expectations

The generated `AGENTS.md` must state:

- Project root is the source material.
- Analysis output goes directly under `llm-wiki/`.
- Exclude `llm-wiki/`, `.git/`, `.obsidian/`, `node_modules/`, build outputs, binaries, and secret files.
- Do not modify source files unless the user explicitly requests it.
- Re-running the installer must not duplicate the managed block.
- When Graphify is enabled, `graphify-out/GRAPH_REPORT.md` should be consulted first for architecture and relationship questions, then durable conclusions should still be written under `llm-wiki/`.

