# Stage 2: Install Agent Skills

Two packages are installed with the vercel-labs/skills CLI via `npx`; no global
skills CLI install is needed.

The `skills` CLI global store is `$HOME/.agents/skills`. After each package is
installed, link the managed skill directories from that global store into the
currently selected agent skills directory (`~/.claude/skills`, `~/.codex/skills`,
`~/.gemini/skills`, or `~/.config/opencode/skills`).

Before running `npx`, check whether every managed skill for that package already
exists in `$HOME/.agents/skills`. If the global store is already complete, skip
the install command and only link the managed skills into the selected agent
directory. If symlink creation fails, ask the user before any copy fallback.

## kepano/obsidian-skills

Install:

```bash
npx -y skills add kepano/obsidian-skills -g -y
```

Managed skills:

```text
defuddle
json-canvas
obsidian-bases
obsidian-cli
obsidian-markdown
```

Detect before / verify after:

```bash
for s in defuddle json-canvas obsidian-bases obsidian-cli obsidian-markdown; do
  [[ -L "$SELECTED_AGENT_SKILLS/$s" ]] || exit 1
done
```

## axtonliu/axton-obsidian-visual-skills

Install:

```bash
npx -y skills add axtonliu/axton-obsidian-visual-skills -g -y
```

Managed skills:

```text
excalidraw-diagram
mermaid-visualizer
obsidian-canvas-creator
```

Detect before / verify after:

```bash
for s in excalidraw-diagram mermaid-visualizer obsidian-canvas-creator; do
  [[ -L "$SELECTED_AGENT_SKILLS/$s" ]] || exit 1
done
```

## Canvas Operations Constraint

`json-canvas` is installed, but the vault's `AGENTS.md` template instructs all
`.canvas` creation to go through `obsidian-canvas-creator` from
`axtonliu/visual-skills`. Do not delete `json-canvas`; `skills update` may pull
it back. The constraint lives in `AGENTS.md`.

## Failure Handling

If either `npx` install fails due to network or registry issues:

- Record the package in the manual-install list.
- Tell the user to run the matching `npx skills add ... -g -y` command.
- Then link the relevant directories from `$HOME/.agents/skills` into the
  selected agent skills directory as symlinks.
- If symlink creation fails, ask the user before any copy fallback.
- Continue to Stage 3; skills are not critical-path for creating the wiki.
