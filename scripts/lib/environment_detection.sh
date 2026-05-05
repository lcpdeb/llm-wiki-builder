#!/usr/bin/env bash
# UTF-8 (no BOM)

detect_os() {
  case "$(uname -s)" in
    Darwin*) OS="macos" ;;
    Linux*) OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
    *) fail "Unsupported OS: $(uname -s)" ;;
  esac

  if [[ "$OS" == "macos" ]]; then
    if command -v brew &>/dev/null; then
      PKG_MGR="brew"
      HAS_BREW=true
    fi
  elif [[ "$OS" == "linux" ]]; then
    if command -v apt-get &>/dev/null; then PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then PKG_MGR="dnf"
    elif command -v pacman &>/dev/null; then PKG_MGR="pacman"
    fi
    if [[ -z "$PKG_MGR" ]]; then
      warn "No supported Linux package manager (apt/dnf/pacman) detected - tools will require manual install."
    fi
  elif [[ "$OS" == "windows" ]]; then
    if command -v winget &>/dev/null; then PKG_MGR="winget"
    elif command -v choco &>/dev/null; then PKG_MGR="choco"
    elif command -v scoop &>/dev/null; then PKG_MGR="scoop"
    fi
    if [[ -z "$PKG_MGR" ]]; then
      warn "No supported Windows package manager (winget/choco/scoop) detected - tools will require manual install. Get winget: https://aka.ms/getwinget"
    fi
  fi

  return 0
}

detect_installed() {
  if declare -F detect_runtime_paths >/dev/null 2>&1; then
    detect_runtime_paths
  fi

  if command -v git &>/dev/null; then
    HAS_GIT=true
    VER_GIT=$(git --version 2>/dev/null | awk '{print $3}')
  fi

  [[ "$OS" == "macos" ]] && command -v brew &>/dev/null && HAS_BREW=true

  if command -v node &>/dev/null; then
    HAS_NODE=true
    VER_NODE=$(node --version 2>/dev/null)
  fi

  command -v claude &>/dev/null && HAS_CLAUDE_CODE=true

  if [[ -n "${DETECTED_OBSIDIAN_PATH:-}" ]]; then
    HAS_OBSIDIAN=true
  elif [[ "$OS" == "macos" && -d "/Applications/Obsidian.app" ]]; then
    HAS_OBSIDIAN=true
  elif [[ "$OS" == "linux" ]] && command -v obsidian &>/dev/null; then
    HAS_OBSIDIAN=true
  elif [[ "$OS" == "windows" ]]; then
    local win_user="${USER:-${USERNAME:-}}"
    if [[ -n "$win_user" && -d "/c/Users/$win_user/AppData/Local/obsidian" ]] || [[ -d "${LOCALAPPDATA:-}/obsidian" ]] || command -v obsidian &>/dev/null; then
      HAS_OBSIDIAN=true
    fi
  fi

  local agents_dir="$HOME/.agents/skills"
  local skills_dir="$HOME/.claude/skills"
  local plugins_dir="$HOME/.claude/plugins/marketplaces"

  if [[ -d "$agents_dir/obsidian-markdown" || -d "$agents_dir/obsidian-cli" || -d "$skills_dir/obsidian-markdown" || -d "$skills_dir/obsidian-cli" ]]; then
    HAS_OBSIDIAN_SKILLS=true
  fi
  if [[ -d "$agents_dir/excalidraw-diagram" || -d "$agents_dir/obsidian-canvas-creator" || -d "$skills_dir/excalidraw-diagram" || -d "$skills_dir/obsidian-canvas-creator" || -d "$plugins_dir/axton-obsidian-visual-skills/excalidraw-diagram" ]]; then
    HAS_VISUAL_SKILLS=true
  fi
}

print_detection_results() {
  printf "\n"
  $HAS_CLAUDE_CODE && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed${RESET}\n" "Claude Code" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}recommended AI agent${RESET}\n" "Claude Code"
  $HAS_NODE && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}%s${RESET}\n" "Node.js" "$VER_NODE" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}required for Claude Code${RESET}\n" "Node.js"
  $HAS_OBSIDIAN && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed${RESET}\n" "Obsidian" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}wiki editor${RESET}\n" "Obsidian"
  $HAS_OBSIDIAN_SKILLS && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed${RESET}\n" "Obsidian Skills" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}kepano/obsidian-skills${RESET}\n" "Obsidian Skills"
  $HAS_VISUAL_SKILLS && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed${RESET}\n" "Visual Skills" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}excalidraw / canvas / mermaid${RESET}\n" "Visual Skills"
  $HAS_GIT && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}%s${RESET}\n" "Git" "$VER_GIT" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}optional, for versioning${RESET}\n" "Git"
  printf "  ${GREEN}→${RESET}  %-20s ${DIM}auto-configured with wiki${RESET}\n" "Obsidian Plugins"
  printf "\n"
  if declare -F print_detected_paths_summary >/dev/null 2>&1; then
    print_detected_paths_summary
  fi
}

is_all_installed() {
  $HAS_OBSIDIAN && $HAS_NODE && $HAS_CLAUDE_CODE && $HAS_OBSIDIAN_SKILLS && $HAS_VISUAL_SKILLS && $HAS_GIT
}

print_manual_guide() {
  printf "\n  ${BOLD}Manual install guide:${RESET}\n\n"
  $HAS_OBSIDIAN || printf "  %-20s ${DIM}${UNDERLINE}https://obsidian.md${RESET}\n" "Obsidian"
  $HAS_NODE || printf "  %-20s ${DIM}${UNDERLINE}https://nodejs.org${RESET}\n" "Node.js"
  if ! $HAS_CLAUDE_CODE; then
    printf "  %-20s ${DIM}${UNDERLINE}https://claude.ai/claude-code${RESET}\n" "Claude Code"
    printf "  %-20s ${GREEN}npm install -g @anthropic-ai/claude-code${RESET}\n" ""
  fi
  $HAS_OBSIDIAN_SKILLS || printf "  %-20s ${DIM}${UNDERLINE}https://github.com/kepano/obsidian-skills${RESET}\n" "Obsidian Skills"
  $HAS_VISUAL_SKILLS || printf "  %-20s ${DIM}${UNDERLINE}https://github.com/axtonliu/axton-obsidian-visual-skills${RESET}\n" "Visual Skills"
  $HAS_GIT || printf "  %-20s ${DIM}${UNDERLINE}https://git-scm.com${RESET}\n" "Git"
  printf "  %-20s ${DIM}${UNDERLINE}https://obsidian.md/clip${RESET} ${DIM}(save web pages to wiki)${RESET}\n" "Web Clipper"
  printf "\n"
}
