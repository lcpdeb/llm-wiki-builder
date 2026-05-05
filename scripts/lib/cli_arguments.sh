#!/usr/bin/env bash
# UTF-8 (no BOM)

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)            WIKI_NAME="$2"; shift 2 ;;
      --dir)             WIKI_DIR="$2"; shift 2 ;;
      --lang)
        case "$2" in
          zh|en) WIKI_LANG="$2" ;;
          *) fail "Invalid language: $2 (use 'zh' or 'en')" ;;
        esac
        shift 2
        ;;
      --skip-install)    SKIP_INSTALL=true; shift ;;
      --only-tools)      ONLY_TOOLS=true; shift ;;
      --only-obsidian)   ONLY_OBSIDIAN=true; shift ;;
      --only-wiki)       ONLY_WIKI=true; shift ;;
      --help|-h)         usage; exit 0 ;;
      --version|-v)      echo "llm-wiki-builder v$VERSION"; exit 0 ;;
      *)                 fail "Unknown option: $1" ;;
    esac
  done

  local mode_count=0
  $ONLY_TOOLS && mode_count=$((mode_count + 1))
  $ONLY_OBSIDIAN && mode_count=$((mode_count + 1))
  $ONLY_WIKI && mode_count=$((mode_count + 1))
  if [[ $mode_count -gt 1 ]]; then
    fail "Cannot use multiple mode flags together (--only-tools, --only-obsidian, --only-wiki)"
  fi
}

usage() {
  cat <<'EOF'
llm-wiki-builder - Create an LLM Wiki knowledge base in one command

Usage:
  curl -fsSL https://raw.githubusercontent.com/eleven-net-cn/llm-wiki-starter/main/install.sh | bash
  bash install.sh [OPTIONS]
  bash install.sh --only-tools [OPTIONS]
  bash install.sh --only-obsidian [--dir <project>] [OPTIONS]
  bash install.sh --only-wiki [--dir <project>] [--name <name>] [OPTIONS]

Modes:
  Default              Install tools -> Initialize .llm-wiki -> Configure Obsidian
  --only-tools         Install all tools only (no wiki creation)
                       Use: Add tools to existing environment without creating wiki
  --only-obsidian      Install Obsidian software + plugins + config in project root
                       Use: Configure Obsidian for the current project
  --only-wiki          Initialize embedded .llm-wiki and AGENTS.md only
                       Use: Fast project wiki setup when tools already installed

Options:
  --name <name>        Wiki display name (default: project directory name)
  --dir <directory>    Project directory (default: current directory)
  --lang <zh|en>       Wiki language (default: en)
  --skip-install       Skip tool installation in default mode
  --help               Show this help
  --version            Show version

Environment:
  LLM_WIKI_DIR         Project directory (same as --dir)

Examples:
  bash install.sh
  bash install.sh --only-tools
  bash install.sh --only-obsidian --dir ~/code/my-project
  bash install.sh --only-wiki --dir ~/code/my-project --name my-project-wiki

Configuration Merge (--only-obsidian):
  When target has existing Obsidian config, new settings are merged:
  - Obsidian software:   Install if not detected
  - Plugins:             Download and install from GitHub releases
  - hotkeys.json:        Add new shortcuts, preserve user's existing shortcuts
  - app.json:            Override specified fields, preserve others
  - community-plugins.json: Merge plugin lists, deduplicate
EOF
}
