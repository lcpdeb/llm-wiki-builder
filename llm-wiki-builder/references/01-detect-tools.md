# Detection protocol

## Command presence

Use `command -v <tool>` for CLI tools. Do not use `which` (not POSIX-portable on Windows Git Bash).

- `command -v node` — Node.js
- `command -v git` — Git
- `command -v jq` — jq
- `command -v curl` — curl
- `command -v claude` — Claude Code
- `command -v codex` — Codex CLI
- `command -v gemini` — Gemini CLI
- `command -v opencode` — OpenCode

For the installer's AI Agent requirement, Claude Code, Codex, Gemini, and OpenCode are the supported checks. If multiple are found, choose interactively and use this default priority: Claude Code > Codex > Gemini > OpenCode. Do not treat Claude Code as missing when Codex, Gemini, or OpenCode is already available.

If a command is missing, its exit status is non-zero; use this in shell logic:

```bash
if command -v node &>/dev/null; then
  echo "✓ Node.js $(node --version)"
else
  echo "✗ Node.js missing"
fi
```

## Obsidian app

- macOS: `[[ -d "/Applications/Obsidian.app" ]]`
- Linux: `command -v obsidian &>/dev/null`
- Windows: `[[ -d "$LOCALAPPDATA/obsidian" ]]` or `[[ -d "/c/Users/$USER/AppData/Local/obsidian" ]]` or `command -v obsidian`

## Agent Skills (kepano/obsidian-skills)

Detection is scoped to the currently selected AI agent. Do not count
`$HOME/.agents/skills` as installed; it is only the global store used by the
`skills` CLI before the installer links skills into the selected agent.

Installed only when all managed Obsidian skills are present as symlinks under
the selected agent skills directory (`~/.claude/skills`, `~/.codex/skills`,
`~/.gemini/skills`, or `~/.config/opencode/skills`) and each symlink points to
`$HOME/.agents/skills/<skill>`:

1. `<selected-agent-skills>/defuddle`
2. `<selected-agent-skills>/json-canvas`
3. `<selected-agent-skills>/obsidian-bases`
4. `<selected-agent-skills>/obsidian-cli`
5. `<selected-agent-skills>/obsidian-markdown`

## Agent Skills (axtonliu/visual-skills)

Installed only when all managed Visual skills are present as symlinks under the
selected agent skills directory and each symlink points to
`$HOME/.agents/skills/<skill>`:

1. `<selected-agent-skills>/excalidraw-diagram`
2. `<selected-agent-skills>/mermaid-visualizer`
3. `<selected-agent-skills>/obsidian-canvas-creator`

## Web Clipper browser extension

Obsidian Web Clipper Chrome extension ID: `cnjifjpddelmedmihgijeibhnjfabmlc`.

Installed if ANY of:

- macOS: `~/Library/Application Support/Google/Chrome/Default/Extensions/cnjifjpddelmedmihgijeibhnjfabmlc/`
- macOS Edge: `~/Library/Application Support/Microsoft Edge/Default/Extensions/cnjifjpddelmedmihgijeibhnjfabmlc/`
- Linux Chrome: `~/.config/google-chrome/Default/Extensions/cnjifjpddelmedmihgijeibhnjfabmlc/`
- Linux Edge: `~/.config/microsoft-edge/Default/Extensions/cnjifjpddelmedmihgijeibhnjfabmlc/`
- Windows Chrome: `$LOCALAPPDATA/Google/Chrome/User Data/Default/Extensions/cnjifjpddelmedmihgijeibhnjfabmlc/`
- Windows Edge: `$LOCALAPPDATA/Microsoft/Edge/User Data/Default/Extensions/cnjifjpddelmedmihgijeibhnjfabmlc/`
- Firefox (any OS): any `*.xpi` under `~/.mozilla/firefox/*/extensions/` named `*obsidian*web*clipper*` — Firefox does not use fixed IDs

## Obsidian plugin

A plugin is installed if `<wiki>/.obsidian/plugins/<plugin_id>/` exists AND contains `manifest.json` of non-zero size.

## Package manager

On macOS:
- `command -v brew` → have brew.

On Linux:
- `command -v apt-get` / `command -v dnf` / `command -v pacman` — in that order.

On Windows (Git Bash or native cmd):
- `command -v winget` / `command -v choco` / `command -v scoop` — in that order.

If no supported package manager on Linux / Windows, report: "No supported package manager detected — you will install tools manually" and continue with what you can.
