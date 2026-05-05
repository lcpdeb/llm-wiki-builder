#!/usr/bin/env bash
# llm-wiki-builder — Initialize an embedded project LLM Wiki in one command
# Author: eleven-net-cn
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/eleven-net-cn/llm-wiki-starter/main/install.sh | bash
#   bash install.sh [OPTIONS]
#
# Modes:
#   Default:      Install tools → Initialize .llm-wiki → Configure Obsidian
#   --only-tools: Install all tools only (no project changes)
#   --only-obsidian: Configure Obsidian plugins/config in project root
#   --only-wiki:  Initialize .llm-wiki and AGENTS.md only
#
# Flow: Detect → Install Tools → Initialize .llm-wiki → Configure Obsidian → Finalize

set -euo pipefail
export LC_MESSAGES=C

VERSION="1.0.1"
TEMPLATE_REPO="eleven-net-cn/llm-wiki-starter"
TEMPLATE_REPO_URL="https://github.com/$TEMPLATE_REPO"

# ─── State ────────────────────────────────────────────────────────────────────

OS=""
PKG_MGR=""
LOCAL_TEMPLATE=""
NON_INTERACTIVE=false
SKIP_INSTALL=false
WIKI_NAME=""
WIKI_DIR=""
WIKI_LANG=""
WIKI_TARGET=""
PROJECT_ROOT=""
TEMPLATE_TMPDIR=""
CLONE_STATUS=""
LLM_WIKI_DIR="${LLM_WIKI_DIR:-}"  # Backward-compatible alias for project directory

# Mode flags
ONLY_TOOLS=false
ONLY_OBSIDIAN=false
ONLY_WIKI=false

# Detection flags (set by detect_installed)
HAS_GIT=false
HAS_NODE=false
HAS_BREW=false
HAS_OBSIDIAN=false
HAS_CLAUDE_CODE=false
HAS_OBSIDIAN_SKILLS=false
HAS_VISUAL_SKILLS=false

# Version strings (set by detect_installed)
VER_GIT=""
VER_NODE=""

# ─── Colors (auto-disable for non-TTY) ───────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
SUCCESS='\033[0;92m'    # bright green (distinct from GREEN)
YELLOW='\033[0;33m'
BLUE='\033[0;94m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
RESET='\033[0m'

[[ ! -t 1 ]] && RED='' GREEN='' SUCCESS='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE='' BOLD='' DIM='' UNDERLINE='' RESET=''

info()    { printf "${GREEN}→${RESET} %b\n" "$1"; }
success() { printf "${GREEN}✓${RESET} %b\n" "$1"; }
warn()    { printf "${YELLOW}⚠${RESET} %b\n" "$1"; }
fail()    { printf "${RED}✗ %b${RESET}\n" "$1" >&2; exit 1; }
stepn()   { printf "\n${BOLD}${GREEN}[%s/%s]${RESET} ${BOLD}%b${RESET}\n" "$1" "$2" "$3"; }
rel_path() { local p="$1" cwd="$(pwd)"; echo "${p#$cwd/}"; }

# ─── Interactive Prompts (bash 3.2 compatible) ────────────────────────────────

prompt_input() {
  local question="$1" default="$2" result
  if $NON_INTERACTIVE; then echo "$default"; return; fi
  printf "  ${GREEN}>${RESET} ${BOLD}%s${RESET} ${DIM}(Default: %s)${RESET}: " "$question" "$default" >&2
  read -r result < /dev/tty
  echo "${result:-$default}"
}

prompt_confirm() {
  local question="$1" default="${2:-Y}" result lower
  if $NON_INTERACTIVE; then
    [[ "$default" == "Y" ]] && return 0 || return 1
  fi
  if [[ "$default" == "Y" ]]; then
    printf "  ${BOLD}%s${RESET} [${GREEN}Y${RESET}/n]: " "$question"
  else
    printf "  ${BOLD}%s${RESET} [y/${RED}N${RESET}]: " "$question"
  fi
  read -r result < /dev/tty
  result="${result:-$default}"
  lower=$(echo "$result" | tr '[:upper:]' '[:lower:]')
  [[ "$lower" == "y" || "$lower" == "yes" ]]
}

# Prompt wiki name with duplicate detection
prompt_wiki_name() {
  local default_name="$1" result target_dir

  if $NON_INTERACTIVE; then
    echo "$default_name"
    return 0
  fi

  while true; do
    printf "  ${GREEN}>${RESET} ${BOLD}Please enter wiki name${RESET} ${DIM}(Default: %s)${RESET}: " "$default_name" >&2
    read -r result < /dev/tty
    result="${result:-$default_name}"

    # Determine target directory
    if [[ -n "$WIKI_DIR" ]]; then
      target_dir="$WIKI_DIR"
    elif [[ -n "$LLM_WIKI_DIR" ]]; then
      target_dir="$LLM_WIKI_DIR"
    else
      target_dir="$(pwd)/$result"
    fi

    # Check if directory already exists
    if [[ -d "$target_dir" ]]; then
      if [[ -f "$target_dir/CLAUDE.md" ]]; then
        printf "  ${YELLOW}⚠${RESET} Directory ${CYAN}$target_dir${RESET} already contains an LLM Wiki\n" >&2
      else
        printf "  ${YELLOW}⚠${RESET} Directory ${CYAN}$target_dir${RESET} already exists\n" >&2
      fi
      printf "  ${YELLOW}Please choose a different name, or use --dir to specify a different location${RESET}\n" >&2
      # Keep same default, don't suggest new name
      continue
    else
      echo "$result"
      return 0
    fi
  done
}

prompt_language() {
  if [[ -n "$WIKI_LANG" ]]; then echo "$WIKI_LANG"; return; fi
  if $NON_INTERACTIVE; then echo "en"; return; fi

  printf "\n  ${GREEN}>${RESET} ${BOLD}Wiki language / Wiki 语言:${RESET}\n" >&2
  printf "    ${GREEN}1${RESET}) English ${DIM}(default)${RESET}\n" >&2
  printf "    ${GREEN}2${RESET}) 中文\n" >&2
  printf "  ${GREEN}>${RESET} ${BOLD}Choose${RESET} ${DIM}(Default: 1)${RESET}: " >&2
  local choice
  read -r choice < /dev/tty
  case "$choice" in
    2|zh|chinese) echo "zh" ;;
    *) echo "en" ;;
  esac
}

resolve_project_context() {
  local requested="${WIKI_DIR:-${LLM_WIKI_DIR:-$(pwd)}}"

  [[ -d "$requested" ]] || fail "Project directory does not exist: $requested"

  PROJECT_ROOT="$(cd "$requested" && pwd)"
  WIKI_TARGET="$PROJECT_ROOT/.llm-wiki"
  WIKI_NAME="${WIKI_NAME:-$(basename "$PROJECT_ROOT")}"
}

prompt_wiki_title() {
  local default_name="$1"
  if $NON_INTERACTIVE; then
    echo "$default_name"
    return 0
  fi
  prompt_input "Wiki display name" "$default_name"
}

copy_tree_missing() {
  local src="$1" dest="$2"
  [[ -d "$src" ]] || return 0
  mkdir -p "$dest"
  cp -Rn "$src/." "$dest/" 2>/dev/null || true
}

# ─── OS Detection ─────────────────────────────────────────────────────────────

detect_os() {
  case "$(uname -s)" in
    Darwin*)          OS="macos" ;;
    Linux*)           OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows" ;;  # Git Bash on Windows
    *)                fail "Unsupported OS: $(uname -s)" ;;
  esac

  if [[ "$OS" == "macos" ]]; then
    command -v brew &>/dev/null && { PKG_MGR="brew"; HAS_BREW=true; }
  elif [[ "$OS" == "linux" ]]; then
    if   command -v apt-get &>/dev/null; then PKG_MGR="apt"
    elif command -v dnf     &>/dev/null; then PKG_MGR="dnf"
    elif command -v pacman  &>/dev/null; then PKG_MGR="pacman"
    fi
    if [[ -z "$PKG_MGR" ]]; then
      warn "No supported Linux package manager (apt/dnf/pacman) detected — tools will require manual install."
    fi
  elif [[ "$OS" == "windows" ]]; then
    # Windows package managers: winget, chocolatey, scoop
    if   command -v winget    &>/dev/null; then PKG_MGR="winget"
    elif command -v choco     &>/dev/null; then PKG_MGR="choco"
    elif command -v scoop     &>/dev/null; then PKG_MGR="scoop"
    fi
    if [[ -z "$PKG_MGR" ]]; then
      warn "No supported Windows package manager (winget/choco/scoop) detected — tools will require manual install. Get winget: https://aka.ms/getwinget"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 1: Detect
# ═══════════════════════════════════════════════════════════════════════════════

detect_installed() {
  # Git
  if command -v git &>/dev/null; then
    HAS_GIT=true
    VER_GIT=$(git --version 2>/dev/null | awk '{print $3}')
  fi

  # Homebrew (macOS only)
  [[ "$OS" == "macos" ]] && command -v brew &>/dev/null && HAS_BREW=true

  # Node.js
  if command -v node &>/dev/null; then
    HAS_NODE=true
    VER_NODE=$(node --version 2>/dev/null)
  fi

  # Claude Code
  command -v claude &>/dev/null && HAS_CLAUDE_CODE=true

  # Obsidian
  if [[ "$OS" == "macos" && -d "/Applications/Obsidian.app" ]]; then
    HAS_OBSIDIAN=true
  elif [[ "$OS" == "linux" ]] && command -v obsidian &>/dev/null; then
    HAS_OBSIDIAN=true
  elif [[ "$OS" == "windows" ]]; then
    # Check common Windows install locations
    local win_user="${USER:-${USERNAME:-}}"
    if [[ -n "$win_user" && -d "/c/Users/$win_user/AppData/Local/obsidian" ]] || \
       [[ -d "${LOCALAPPDATA:-}/obsidian" ]] || \
       command -v obsidian &>/dev/null; then
      HAS_OBSIDIAN=true
    fi
  fi

  # Claude Code Skills — check ~/.agents/skills/ (preferred), ~/.claude/skills/, and plugins/marketplaces/
  local agents_dir="$HOME/.agents/skills"
  local skills_dir="$HOME/.claude/skills"
  local plugins_dir="$HOME/.claude/plugins/marketplaces"

  if [[ -d "$agents_dir/obsidian-markdown" || -d "$agents_dir/obsidian-cli" || \
        -d "$skills_dir/obsidian-markdown" || -d "$skills_dir/obsidian-cli" ]]; then
    HAS_OBSIDIAN_SKILLS=true
  fi
  if [[ -d "$agents_dir/excalidraw-diagram" || -d "$agents_dir/obsidian-canvas-creator" || \
        -d "$skills_dir/excalidraw-diagram" || -d "$skills_dir/obsidian-canvas-creator" || \
        -d "$plugins_dir/axton-obsidian-visual-skills/excalidraw-diagram" ]]; then
    HAS_VISUAL_SKILLS=true
  fi
}

print_detection_results() {
  printf "\n"

  # Claude Code
  if $HAS_CLAUDE_CODE; then
    printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed${RESET}\n" "Claude Code"
  else
    printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}recommended AI agent${RESET}\n" "Claude Code"
  fi

  # Node.js
  if $HAS_NODE; then
    printf "  ${GREEN}✓${RESET}  %-20s ${DIM}%s${RESET}\n" "Node.js" "$VER_NODE"
  else
    printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}required for Claude Code${RESET}\n" "Node.js"
  fi

  # Obsidian
  if $HAS_OBSIDIAN; then
    printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed${RESET}\n" "Obsidian"
  else
    printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}wiki editor${RESET}\n" "Obsidian"
  fi

  # Obsidian Skills
  if $HAS_OBSIDIAN_SKILLS; then
    printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed${RESET}\n" "Obsidian Skills"
  else
    printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}kepano/obsidian-skills${RESET}\n" "Obsidian Skills"
  fi

  # Visual Skills
  if $HAS_VISUAL_SKILLS; then
    printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed${RESET}\n" "Visual Skills"
  else
    printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}excalidraw / canvas / mermaid${RESET}\n" "Visual Skills"
  fi

  # Git
  if $HAS_GIT; then
    printf "  ${GREEN}✓${RESET}  %-20s ${DIM}%s${RESET}\n" "Git" "$VER_GIT"
  else
    printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}optional, for versioning${RESET}\n" "Git"
  fi

  # Obsidian Plugins (always installed per-wiki)
  printf "  ${GREEN}→${RESET}  %-20s ${DIM}auto-configured with wiki${RESET}\n" "Obsidian Plugins"

  printf "\n"
}

is_all_installed() {
  $HAS_OBSIDIAN && $HAS_NODE && $HAS_CLAUDE_CODE && \
  $HAS_OBSIDIAN_SKILLS && $HAS_VISUAL_SKILLS && $HAS_GIT
}

print_manual_guide() {
  printf "\n  ${BOLD}Manual install guide:${RESET}\n\n"

  $HAS_OBSIDIAN || \
    printf "  %-20s ${DIM}${UNDERLINE}https://obsidian.md${RESET}\n" "Obsidian"

  $HAS_NODE || \
    printf "  %-20s ${DIM}${UNDERLINE}https://nodejs.org${RESET}\n" "Node.js"

  if ! $HAS_CLAUDE_CODE; then
    printf "  %-20s ${DIM}${UNDERLINE}https://claude.ai/claude-code${RESET}\n" "Claude Code"
    printf "  %-20s ${GREEN}npm install -g @anthropic-ai/claude-code${RESET}\n" ""
  fi

  $HAS_OBSIDIAN_SKILLS || \
    printf "  %-20s ${DIM}${UNDERLINE}https://github.com/kepano/obsidian-skills${RESET}\n" "Obsidian Skills"

  $HAS_VISUAL_SKILLS || \
    printf "  %-20s ${DIM}${UNDERLINE}https://github.com/axtonliu/axton-obsidian-visual-skills${RESET}\n" "Visual Skills"

  $HAS_GIT || \
    printf "  %-20s ${DIM}${UNDERLINE}https://git-scm.com${RESET}\n" "Git"

  # Web Clipper (manual install only)
  printf "  %-20s ${DIM}${UNDERLINE}https://obsidian.md/clip${RESET} ${DIM}(save web pages to wiki)${RESET}\n" "Web Clipper"

  printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 2: Install Tools
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Manual Install Guide (fallback) ─────────────────────────────────────────

print_manual_install() {
  local tool="$1" url="$2" notes="$3"
  printf "\n  ${BOLD}${YELLOW}Manual install required:${RESET}\n"
  printf "  ${BOLD}Tool:${RESET}     %s\n" "$tool"
  printf "  ${BOLD}Official:${RESET}  ${UNDERLINE}%s${RESET}\n" "$url"
  [[ -n "$notes" ]] && printf "  ${BOLD}Notes:${RESET}    ${DIM}%s${RESET}\n" "$notes"
  printf "\n"
}

# ─── Homebrew (macOS only) ───────────────────────────────────────────────────

ensure_brew() {
  [[ "$OS" != "macos" ]] && return 0
  $HAS_BREW && return 0

  info "Installing ${GREEN}Homebrew${RESET}..."
  if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1; then
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)" || true
    PKG_MGR="brew"
    HAS_BREW=true
    success "Homebrew installed"
  else
    print_manual_install "Homebrew" "https://brew.sh" "Required for auto-install on macOS"
    return 1
  fi
}

# ─── Obsidian ────────────────────────────────────────────────────────────────

install_obsidian() {
  $HAS_OBSIDIAN && return 0

  info "Installing ${GREEN}Obsidian${RESET}..."
  local installed=false

  case "$OS" in
    macos)
      # Try brew first, fallback to manual
      if command -v brew &>/dev/null; then
        if brew install --cask obsidian 2>&1; then
          installed=true
        fi
      fi
      ;;
    linux)
      # Try snap, then flatpak, then AppImage hint
      if command -v snap &>/dev/null; then
        if sudo snap install obsidian --classic 2>&1; then
          installed=true
        fi
      fi
      if ! $installed && command -v flatpak &>/dev/null; then
        if flatpak install -y flathub md.obsidian.Obsidian 2>&1; then
          installed=true
        fi
      fi
      ;;
    windows)
      # Try winget, then choco, then scoop
      if command -v winget &>/dev/null; then
        if winget install --id Obsidian.Obsidian --accept-source-agreements --accept-package-agreements 2>&1; then
          installed=true
        fi
      fi
      if ! $installed && command -v choco &>/dev/null; then
        if choco install obsidian -y 2>&1; then
          installed=true
        fi
      fi
      if ! $installed && command -v scoop &>/dev/null; then
        if scoop install obsidian 2>&1; then
          installed=true
        fi
      fi
      ;;
  esac

  if $installed; then
    HAS_OBSIDIAN=true
    success "Obsidian installed"
  else
    print_manual_install "Obsidian" "https://obsidian.md/download" \
      "Download the installer for your platform, or use your system's app store"
    return 1
  fi
}

# ─── Node.js ─────────────────────────────────────────────────────────────────

install_node() {
  $HAS_NODE && return 0

  info "Installing ${GREEN}Node.js${RESET}..."
  local installed=false

  case "$OS" in
    macos)
      if command -v brew &>/dev/null; then
        if brew install node 2>&1; then
          installed=true
        fi
      fi
      ;;
    linux)
      if command -v apt-get &>/dev/null; then
        if sudo apt-get update -qq && sudo apt-get install -y -qq nodejs npm 2>&1; then
          installed=true
        fi
      elif ! $installed && command -v dnf &>/dev/null; then
        if sudo dnf install -y -q nodejs npm 2>&1; then
          installed=true
        fi
      elif ! $installed && command -v pacman &>/dev/null; then
        if sudo pacman -S --noconfirm nodejs npm 2>&1; then
          installed=true
        fi
      fi
      ;;
    windows)
      if command -v winget &>/dev/null; then
        if winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements 2>&1; then
          installed=true
        fi
      fi
      if ! $installed && command -v choco &>/dev/null; then
        if choco install nodejs-lts -y 2>&1; then
          installed=true
        fi
      fi
      if ! $installed && command -v scoop &>/dev/null; then
        if scoop install nodejs-lts 2>&1; then
          installed=true
        fi
      fi
      ;;
  esac

  if $installed && command -v node &>/dev/null; then
    HAS_NODE=true
    success "Node.js installed ($(node --version))"
  else
    print_manual_install "Node.js (LTS version recommended)" "https://nodejs.org" \
      "Download the LTS installer, or use 'nvm' for version management"
    return 1
  fi
}

install_jq() {
  command -v jq &>/dev/null && return 0

  info "Installing ${GREEN}jq${RESET} (JSON processor)..."
  local installed=false

  case "$OS" in
    macos)
      if command -v brew &>/dev/null; then
        if brew install jq 2>&1; then
          installed=true
        fi
      fi
      ;;
    linux)
      if command -v apt-get &>/dev/null; then
        if sudo apt-get install -y -qq jq 2>&1; then
          installed=true
        fi
      elif ! $installed && command -v dnf &>/dev/null; then
        if sudo dnf install -y -q jq 2>&1; then
          installed=true
        fi
      elif ! $installed && command -v pacman &>/dev/null; then
        if sudo pacman -S --noconfirm jq 2>&1; then
          installed=true
        fi
      fi
      ;;
    windows)
      if command -v winget &>/dev/null; then
        if winget install jqlang.jq --accept-source-agreements --accept-package-agreements 2>&1; then
          installed=true
        fi
      fi
      if ! $installed && command -v choco &>/dev/null; then
        if choco install jq -y 2>&1; then
          installed=true
        fi
      fi
      if ! $installed && command -v scoop &>/dev/null; then
        if scoop install jq 2>&1; then
          installed=true
        fi
      fi
      ;;
  esac

  if $installed && command -v jq &>/dev/null; then
    success "jq installed ($(jq --version 2>/dev/null | head -1))"
  else
    warn "jq installation failed — will use Python fallback for JSON merge"
    return 1
  fi
}

# ─── Claude Code ─────────────────────────────────────────────────────────────

install_claude_code() {
  $HAS_CLAUDE_CODE && return 0

  # Requires Node.js + npm
  if ! command -v npm &>/dev/null; then
    warn "npm not available — install Node.js first"
    print_manual_install "Claude Code" "https://claude.ai/claude-code" \
      "Requires Node.js. After Node is installed: npm install -g @anthropic-ai/claude-code"
    return 1
  fi

  info "Installing ${GREEN}Claude Code${RESET}..."
  if npm install -g @anthropic-ai/claude-code 2>&1 | tail -5; then
    # Verify installation
    sleep 2  # Give npm time to update PATH
    if command -v claude &>/dev/null; then
      HAS_CLAUDE_CODE=true
      success "Claude Code installed"
    else
      warn "Install succeeded but 'claude' command not found"
      print_manual_install "Claude Code" "https://claude.ai/claude-code" \
        "May need to restart terminal or add npm global bin to PATH"
      return 1
    fi
  else
    print_manual_install "Claude Code" "https://claude.ai/claude-code" \
      "Run manually: npm install -g @anthropic-ai/claude-code"
    return 1
  fi
}

# ─── Git ─────────────────────────────────────────────────────────────────────

install_git() {
  $HAS_GIT && return 0

  info "Installing ${GREEN}Git${RESET}..."
  local installed=false

  case "$OS" in
    macos)
      # Prefer brew (faster, CLI-based), fallback to xcode-select
      if command -v brew &>/dev/null; then
        if brew install git 2>&1; then
          installed=true
        fi
      fi
      # Fallback to Xcode CLI Tools (includes Git + other dev tools)
      if ! $installed; then
        info "Installing via Xcode CLI Tools (includes Git)..."
        xcode-select --install 2>&1 || true
        if ! $NON_INTERACTIVE; then
          printf "  ${DIM}Xcode CLI Tools installer opened. Press Enter after it completes...${RESET}"
          read -r < /dev/tty
        fi
        installed=true  # Assume success after user confirmation
      fi
      ;;
    linux)
      if command -v apt-get &>/dev/null; then
        if sudo apt-get update -qq && sudo apt-get install -y -qq git 2>&1; then
          installed=true
        fi
      elif ! $installed && command -v dnf &>/dev/null; then
        if sudo dnf install -y -q git 2>&1; then
          installed=true
        fi
      elif ! $installed && command -v pacman &>/dev/null; then
        if sudo pacman -S --noconfirm git 2>&1; then
          installed=true
        fi
      fi
      ;;
    windows)
      # Git Bash usually includes Git; try package managers as fallback
      if command -v winget &>/dev/null; then
        if winget install Git.Git --accept-source-agreements --accept-package-agreements 2>&1; then
          installed=true
        fi
      fi
      if ! $installed && command -v choco &>/dev/null; then
        if choco install git -y 2>&1; then
          installed=true
        fi
      fi
      if ! $installed && command -v scoop &>/dev/null; then
        if scoop install git 2>&1; then
          installed=true
        fi
      fi
      ;;
  esac

  # Verify Git is actually available
  if command -v git &>/dev/null; then
    HAS_GIT=true
    success "Git installed ($(git --version | awk '{print $3}'))"
  else
    print_manual_install "Git" "https://git-scm.com/downloads" \
      "Download installer for your platform, or use your system's package manager"
    return 1
  fi
}

# ─── Claude Code Skills ──────────────────────────────────────────────────────

install_skills() {
  # Requires Node.js + npx
  if ! command -v npx &>/dev/null; then
    warn "npx not available — install Node.js first"
    return 1
  fi

  # Obsidian Skills (kepano)
  if ! $HAS_OBSIDIAN_SKILLS; then
    info "Installing ${GREEN}kepano/obsidian-skills${RESET}..."
    if npx -y skills add kepano/obsidian-skills -g -y 2>&1 | tail -3; then
      # Re-check detection
      if [[ -d "$HOME/.agents/skills/obsidian-markdown" ]] || \
         [[ -d "$HOME/.agents/skills/obsidian-cli" ]] || \
         [[ -d "$HOME/.claude/skills/obsidian-markdown" ]] || \
         [[ -d "$HOME/.claude/skills/obsidian-cli" ]]; then
        HAS_OBSIDIAN_SKILLS=true
        success "kepano/obsidian-skills installed"
      else
        warn "Install succeeded but skills not detected in expected locations"
      fi
    else
      warn "Failed to install kepano/obsidian-skills"
      print_manual_install "obsidian-skills" "https://github.com/kepano/obsidian-skills" \
        "Run manually: npx skills add kepano/obsidian-skills -g"
    fi
  fi

  # Visual Skills (axtonliu)
  if ! $HAS_VISUAL_SKILLS; then
    info "Installing ${GREEN}axtonliu/axton-obsidian-visual-skills${RESET}..."
    if npx -y skills add axtonliu/axton-obsidian-visual-skills -g -y 2>&1 | tail -3; then
      # Re-check detection
      if [[ -d "$HOME/.agents/skills/excalidraw-diagram" ]] || \
         [[ -d "$HOME/.agents/skills/obsidian-canvas-creator" ]] || \
         [[ -d "$HOME/.claude/skills/excalidraw-diagram" ]] || \
         [[ -d "$HOME/.claude/skills/obsidian-canvas-creator" ]] || \
         [[ -d "$HOME/.claude/plugins/marketplaces/axton-obsidian-visual-skills/excalidraw-diagram" ]]; then
        HAS_VISUAL_SKILLS=true
        success "axtonliu/visual-skills installed"
      else
        warn "Install succeeded but skills not detected in expected locations"
      fi
    else
      warn "Failed to install axtonliu/axton-obsidian-visual-skills"
      print_manual_install "axton-obsidian-visual-skills" "https://github.com/axtonliu/axton-obsidian-visual-skills" \
        "Run manually: npx skills add axtonliu/axton-obsidian-visual-skills -g"
    fi
  fi
}

# ─── Run All Installs ────────────────────────────────────────────────────────

run_install() {
  [[ "$OS" == "macos" ]] && ! $HAS_BREW && ensure_brew || true

  install_node        || true
  install_claude_code || true
  install_obsidian    || true
  install_skills      || true
  install_git         || true

  # Final check — report what's still missing
  if ! $HAS_OBSIDIAN || ! $HAS_NODE || ! $HAS_CLAUDE_CODE || ! $HAS_GIT; then
    warn "\nSome tools could not be auto-installed. Check the manual install guides above."
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 3: Initialize Embedded Wiki
# ═══════════════════════════════════════════════════════════════════════════════

detect_dev_mode() {
  local script_dir candidate
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || script_dir=""

  for candidate in \
    "${REPO_ROOT:-}" \
    "$script_dir/../.." \
    "$(pwd)"; do
    [[ -n "$candidate" ]] || continue
    candidate="$(cd "$candidate" 2>/dev/null && pwd)" || continue
    if [[ -d "$candidate/template/base" ]]; then
      LOCAL_TEMPLATE="$candidate/template"
      return 0
    fi
  done

  return 1
}

download_template() {
  local tmpdir
  tmpdir=$(mktemp -d)
  TEMPLATE_TMPDIR="$tmpdir"

  local downloaded=false

  # Try git clone
  if command -v git &>/dev/null; then
    info "Downloading template via ${GREEN}git${RESET}..."
    if git clone --depth 1 "$TEMPLATE_REPO_URL" "$tmpdir/repo" 2>&1 | tail -1; then
      if [[ -d "$tmpdir/repo/template/base" ]]; then
        LOCAL_TEMPLATE="$tmpdir/repo/template"
        downloaded=true
      fi
    fi
  fi

  # Fallback to curl tarball
  if ! $downloaded; then
    info "Downloading template via ${GREEN}curl${RESET}..."
    local tarball_url="https://github.com/$TEMPLATE_REPO/archive/refs/heads/main.tar.gz"
    if curl -fsSL "$tarball_url" -o "$tmpdir/repo.tar.gz" 2>/dev/null; then
      tar -xzf "$tmpdir/repo.tar.gz" -C "$tmpdir" 2>/dev/null
      local extracted
      extracted=$(find "$tmpdir" -maxdepth 1 -type d -name 'llm-wiki-builder*' | head -1)
      if [[ -n "$extracted" && -d "$extracted/template/base" ]]; then
        LOCAL_TEMPLATE="$extracted/template"
        downloaded=true
      fi
    fi
  fi

  if ! $downloaded; then
    rm -rf "$tmpdir"
    TEMPLATE_TMPDIR=""
    fail "Failed to download template. Check your network connection."
  fi
}

render_agents_managed_block() {
  local name="$1"

  if [[ "$WIKI_LANG" == "zh" ]]; then
    cat <<EOF
<!-- llm-wiki-builder:start -->
## LLM Wiki 工作区

本项目使用 \`.llm-wiki/\` 作为内嵌 LLM Wiki。当前项目根目录就是源材料；不要要求用户把代码或文档复制到 \`raw/\`。

### 读取范围
- 读取项目根目录中的代码、文档和配置作为分析材料。
- 默认排除 \`.llm-wiki/\`、\`.git/\`、\`.obsidian/\`、\`node_modules/\`、\`vendor/\`、\`dist/\`、\`build/\`、\`.next/\`、\`target/\`、二进制大文件和 \`.env*\` 等密钥文件。

### 写入范围
- 分析输出只能写入 \`.llm-wiki/\`。
- 除非用户明确要求，不修改项目源码、原始文档或配置文件。
- 摘要放入 \`.llm-wiki/资料摘要/\`，概念页放入 \`.llm-wiki/概念/\`，综合分析放入 \`.llm-wiki/综合分析/\`，图表资源放入 \`.llm-wiki/assets/\` 或 \`.llm-wiki/canvas/\`。
- 每次分析后更新 \`.llm-wiki/Wiki 目录.md\` 和 \`.llm-wiki/操作日志.md\`。

### 项目名称
- Wiki 名称：${name}
<!-- llm-wiki-builder:end -->
EOF
  else
    cat <<EOF
<!-- llm-wiki-builder:start -->
## LLM Wiki Workspace

This project uses \`.llm-wiki/\` as an embedded LLM Wiki. The current project root is the source material; do not ask the user to copy code or docs into \`raw/\`.

### Read Scope
- Read code, docs, and configuration from the project root as source material.
- Exclude \`.llm-wiki/\`, \`.git/\`, \`.obsidian/\`, \`node_modules/\`, \`vendor/\`, \`dist/\`, \`build/\`, \`.next/\`, \`target/\`, large binaries, and secret files such as \`.env*\`.

### Write Scope
- Write analysis output only under \`.llm-wiki/\`.
- Do not modify source code, original docs, or project configuration unless the user explicitly asks.
- Put source summaries in \`.llm-wiki/summaries/\`, concept pages in \`.llm-wiki/concepts/\`, synthesis in \`.llm-wiki/synthesis/\`, and visual assets in \`.llm-wiki/assets/\` or \`.llm-wiki/canvas/\`.
- After each analysis, update \`.llm-wiki/Index.md\` and \`.llm-wiki/Changelog.md\`.

### Project Name
- Wiki name: ${name}
<!-- llm-wiki-builder:end -->
EOF
  fi
}

replace_managed_block() {
  local target_file="$1" block_file="$2" tmp
  tmp="$(mktemp)"
  awk -v start="<!-- llm-wiki-builder:start -->" \
      -v end="<!-- llm-wiki-builder:end -->" \
      -v block_file="$block_file" '
    BEGIN {
      while ((getline line < block_file) > 0) {
        block = block line ORS
      }
      in_block = 0
    }
    $0 == start {
      printf "%s", block
      in_block = 1
      next
    }
    $0 == end {
      in_block = 0
      next
    }
    !in_block { print }
  ' "$target_file" > "$tmp" && mv "$tmp" "$target_file"
}

prompt_agents_action() {
  local has_block="$1" choice

  if $NON_INTERACTIVE; then
    if [[ "$has_block" == "true" ]]; then
      echo "update"
    else
      echo "append"
    fi
    return 0
  fi

  printf "\n  ${GREEN}>${RESET} ${BOLD}AGENTS.md already exists.${RESET}\n" >&2
  if [[ "$has_block" == "true" ]]; then
    printf "    ${GREEN}1${RESET}) Update llm-wiki managed block ${DIM}(default)${RESET}\n" >&2
  else
    printf "    ${GREEN}1${RESET}) Append llm-wiki managed block ${DIM}(default)${RESET}\n" >&2
  fi
  printf "    ${GREEN}2${RESET}) Backup and replace AGENTS.md\n" >&2
  printf "    ${GREEN}3${RESET}) Write AGENTS.llm-wiki.md instead\n" >&2
  printf "  ${GREEN}>${RESET} ${BOLD}Choose${RESET} ${DIM}(Default: 1)${RESET}: " >&2
  read -r choice < /dev/tty

  case "${choice:-1}" in
    2) echo "replace" ;;
    3) echo "sidecar" ;;
    *)
      if [[ "$has_block" == "true" ]]; then echo "update"; else echo "append"; fi
      ;;
  esac
}

ensure_project_agents() {
  local project_root="$1" name="$2"
  local agents_file="$project_root/AGENTS.md"
  local sidecar_file="$project_root/AGENTS.llm-wiki.md"
  local block_file action ts has_start=false has_end=false has_block=false

  block_file="$(mktemp)"
  render_agents_managed_block "$name" > "$block_file"

  if [[ ! -f "$agents_file" ]]; then
    cp "$block_file" "$agents_file"
    rm -f "$block_file"
    success "Created AGENTS.md with llm-wiki rules"
    return 0
  fi

  grep -Fq "<!-- llm-wiki-builder:start -->" "$agents_file" && has_start=true
  grep -Fq "<!-- llm-wiki-builder:end -->" "$agents_file" && has_end=true
  if $has_start && $has_end; then
    has_block=true
  elif $has_start || $has_end; then
    rm -f "$block_file"
    fail "AGENTS.md contains an incomplete llm-wiki managed block"
  fi

  action="$(prompt_agents_action "$has_block")"
  case "$action" in
    update)
      replace_managed_block "$agents_file" "$block_file"
      success "Updated llm-wiki block in AGENTS.md"
      ;;
    append)
      {
        printf "\n"
        cat "$block_file"
      } >> "$agents_file"
      success "Appended llm-wiki block to AGENTS.md"
      ;;
    replace)
      ts="$(date +%Y%m%d%H%M%S)"
      cp "$agents_file" "$agents_file.bak.$ts"
      cp "$block_file" "$agents_file"
      success "Replaced AGENTS.md after backup"
      ;;
    sidecar)
      cp "$block_file" "$sidecar_file"
      success "Wrote AGENTS.llm-wiki.md"
      ;;
  esac

  rm -f "$block_file"
}

prepare_wiki() {
  local target="$1"

  if [[ -z "$LOCAL_TEMPLATE" ]]; then
    download_template
  fi

  info "Initializing embedded .llm-wiki..."
  mkdir -p "$target"

  # Keep existing analysis pages; only backfill missing scaffold files.
  copy_tree_missing "$LOCAL_TEMPLATE/$WIKI_LANG/wiki" "$target"
  copy_tree_missing "$LOCAL_TEMPLATE/$WIKI_LANG/templates" "$target/templates"

  # Ensure empty directories exist (git doesn't track them)
  local base_dirs=("assets/excalidraw" "canvas" "templates")
  local lang_dirs=()
  if [[ "$WIKI_LANG" == "zh" ]]; then
    lang_dirs=("概念" "资料摘要" "综合分析" "归档")
  else
    lang_dirs=("concepts" "summaries" "synthesis" "archived")
  fi
  for d in "${base_dirs[@]}" "${lang_dirs[@]}"; do
    mkdir -p "$target/$d"
  done

  if [[ ! -f "$target/.gitignore" ]]; then
    cat > "$target/.gitignore" <<'EOF'
detected-paths.json
EOF
  fi

  success "LLM Wiki initialized: ${CYAN}$(rel_path "$target")${RESET}"
}

replace_placeholders() {
  local wiki_dir="$1" name="$2"
  local today
  today=$(date +%Y-%m-%d)

  local files_to_patch=()

  if [[ "$WIKI_LANG" == "zh" ]]; then
    files_to_patch+=("知识库概览.md" "Wiki 目录.md" "操作日志.md")
  else
    files_to_patch+=("Overview.md" "Index.md" "Changelog.md")
  fi

  for f in "${files_to_patch[@]}"; do
    local fpath="$wiki_dir/$f"
    [[ -f "$fpath" ]] || continue
    if [[ "$OS" == "macos" ]]; then
      sed -i '' "s/<Wiki Name>/$name/g; s/<wiki-name>/$name/g; s/{{date}}/$today/g" "$fpath"
    else
      sed -i "s/<Wiki Name>/$name/g; s/<wiki-name>/$name/g; s/{{date}}/$today/g" "$fpath"
    fi
  done
}

# Spinner animation for download progress
_spinner() {
  local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while true; do
    printf "\r  ${CYAN}${chars:$i:1}${RESET} ${DIM}Downloading...${RESET}"
    i=$(( (i + 1) % 10 ))
    sleep 0.1
  done
}

download_plugin() {
  local repo="$1" plugin_id="$2" target_dir="$3"
  local plugin_dir="$target_dir/.obsidian/plugins/$plugin_id"
  local base_url="https://github.com/$repo/releases/latest/download"

  mkdir -p "$plugin_dir"

  # Show download indicator
  printf "  ${CYAN}↓${RESET} ${DIM}Downloading %s...${RESET}" "$plugin_id"

  local ok=true
  for file in main.js manifest.json; do
    if ! curl -fsSL --max-time 30 "$base_url/$file" -o "$plugin_dir/$file" 2>/dev/null; then
      ok=false; break
    fi
  done

  # styles.css is optional (many plugins ship none). Capture HTTP status so we
  # can distinguish "plugin has no CSS" (404) from "network hiccup" (timeout/5xx).
  local css_status
  css_status=$(curl -sSL --max-time 30 -w '%{http_code}' \
    -o "$plugin_dir/styles.css" "$base_url/styles.css" 2>/dev/null || echo "000")
  if [[ "$css_status" != "200" ]]; then
    rm -f "$plugin_dir/styles.css"
  fi

  # Clear download indicator and show result
  printf "\r%50s\r" ""  # Clear the line

  if $ok && [[ -s "$plugin_dir/manifest.json" ]]; then
    printf "    ${GREEN}✓${RESET} %s\n" "$plugin_id"
    # Warn only when styles.css fetch failed due to network, not 404 (= plugin has no CSS)
    if [[ "$css_status" != "200" && "$css_status" != "404" ]]; then
      printf "      ${YELLOW}⚠${RESET} ${DIM}styles.css not downloaded (HTTP %s) — disable/enable plugin after re-running install${RESET}\n" "$css_status"
    fi
    return 0
  else
    rm -rf "$plugin_dir"
    printf "    ${YELLOW}⚠${RESET} %s ${DIM}download failed${RESET}\n" "$plugin_id"
    return 1
  fi
}

# ─── Plugin manifest helpers ──────────────────────────────────────────────────
# Resolves the manifest path. Echoes the path or returns nonzero.
_locate_plugin_manifest() {
  local script_dir candidate
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || script_dir=""

  for candidate in \
    "${REPO_ROOT:-}" \
    "$script_dir/../.." \
    "$(dirname "${LOCAL_TEMPLATE:-}")" \
    "${TEMPLATE_TMPDIR:-}/repo"; do
    [[ -n "$candidate" && "$candidate" != "." ]] || continue
    candidate="$(cd "$candidate" 2>/dev/null && pwd)" || continue
    if [[ -f "$candidate/llm-wiki-builder/assets/plugin-manifest.json" ]]; then
      echo "$candidate/llm-wiki-builder/assets/plugin-manifest.json"
      return 0
    fi
  done

  return 1
}

# Reads plugin entries. Args: group = "core" | "ux". Echoes one "repo|id" per line.
read_plugin_manifest() {
  local group="$1"
  local manifest
  manifest="$(_locate_plugin_manifest)" || fail "plugin-manifest.json not found — expected at llm-wiki-builder/assets/"

  if command -v jq &>/dev/null; then
    jq -r --arg g "$group" '.[$g][] | "\(.repo)|\(.id)"' "$manifest"
  else
    python3 - "$manifest" "$group" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
for p in d[sys.argv[2]]:
    print(p['repo'] + '|' + p['id'])
PY
  fi
}

install_obsidian_plugins() {
  local wiki_dir="$1"
  local plugins_installed=()

  mkdir -p "$wiki_dir/.obsidian/plugins"

  add_plugin_id() {
    local id="$1" existing
    id="${id//$'\r'/}"
    [[ -n "$id" ]] || return 0
    for existing in "${plugins_installed[@]}"; do
      [[ "$existing" == "$id" ]] && return 0
    done
    plugins_installed+=("$id")
  }

  if [[ -f "$wiki_dir/.obsidian/community-plugins.json" ]]; then
    if command -v jq &>/dev/null; then
      while IFS= read -r existing_id; do
        [[ -n "$existing_id" && "$existing_id" != "null" ]] && add_plugin_id "$existing_id"
      done < <(jq -r '.[]?' "$wiki_dir/.obsidian/community-plugins.json" 2>/dev/null || true)
    else
      local existing_id
      for existing_id in $(grep -oE '"[^"]+"' "$wiki_dir/.obsidian/community-plugins.json" 2>/dev/null | tr -d '"'); do
        [[ -n "$existing_id" ]] && add_plugin_id "$existing_id"
      done
    fi
  fi

  # ─── Plugin Categories ─────────────────────────────────────────────────────
  # Core plugins: Required for llm-wiki functionality (data, templates, git, linting)
  # UX plugins:   Enhance Obsidian editing experience (toolbar, search, navigation, diagrams)
  # ────────────────────────────────────────────────────────────────────────────

  # Plugin lists: read from shared manifest at llm-wiki-builder/assets/plugin-manifest.json
  # (single source of truth shared with the llm-wiki-builder Skill).
  local core_plugins=()
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -n "$line" ]] && core_plugins+=("$line")
  done < <(read_plugin_manifest core)

  local ux_plugins=()
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -n "$line" ]] && ux_plugins+=("$line")
  done < <(read_plugin_manifest ux)

  if [[ ${#core_plugins[@]} -eq 0 || ${#ux_plugins[@]} -eq 0 ]]; then
    fail "Plugin manifest empty or unreadable at llm-wiki-builder/assets/plugin-manifest.json"
  fi

  # Skip obsidian-git if Git is not available
  if command -v git &>/dev/null; then
    HAS_GIT=true
  fi

  if ! $HAS_GIT; then
    info "Git not available — skipping ${GREEN}obsidian-git${RESET} plugin"
    local filtered=()
    for entry in "${core_plugins[@]}"; do
      [[ "$entry" == *"|obsidian-git" ]] && continue
      filtered+=("$entry")
    done
    core_plugins=("${filtered[@]}")
  fi

  printf "\n${BOLD}Obsidian Setup:${RESET}\n"

  # Install core plugins (llm-wiki core)
  printf "\n  ${DIM}Core plugins (llm-wiki core):${RESET}\n"
  for entry in "${core_plugins[@]}"; do
    local repo="${entry%%|*}" id="${entry##*|}"
    if [[ -s "$wiki_dir/.obsidian/plugins/$id/manifest.json" ]]; then
      printf "    ${GREEN}✓${RESET} %s ${DIM}(exists)${RESET}\n" "$id"
      add_plugin_id "$id"
      continue
    fi
    download_plugin "$repo" "$id" "$wiki_dir" && add_plugin_id "$id"
  done

  # Install UX plugins (Obsidian experience)
  printf "\n  ${DIM}UX plugins (Obsidian experience):${RESET}\n"
  for entry in "${ux_plugins[@]}"; do
    local repo="${entry%%|*}" id="${entry##*|}"
    if [[ -s "$wiki_dir/.obsidian/plugins/$id/manifest.json" ]]; then
      printf "    ${GREEN}✓${RESET} %s ${DIM}(exists)${RESET}\n" "$id"
      add_plugin_id "$id"
      continue
    fi
    download_plugin "$repo" "$id" "$wiki_dir" && add_plugin_id "$id"
  done

  # Write community-plugins.json
  if [[ ${#plugins_installed[@]} -gt 0 ]]; then
    local json="["
    local first=true
    for id in "${plugins_installed[@]}"; do
      if $first; then first=false; else json+=","; fi
      json+="\"$id\""
    done
    json+="]"
    echo "$json" > "$wiki_dir/.obsidian/community-plugins.json"
    printf "\n  ${GREEN}✓${RESET} ${BOLD}%d${RESET} plugins configured\n" "${#plugins_installed[@]}"
  fi

  # Disable Safe Mode so installed plugins are live on first vault open.
  local app_json="$wiki_dir/.obsidian/app.json"
  if [[ -f "$app_json" ]]; then
    if command -v jq &>/dev/null; then
      local tmp
      tmp=$(mktemp)
      jq '. + {communityPluginsEnabled: true}' "$app_json" > "$tmp" && mv "$tmp" "$app_json" || rm -f "$tmp"
    else
      python3 - "$app_json" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f:
    d = json.load(f)
d['communityPluginsEnabled'] = True
with open(p, 'w') as f:
    json.dump(d, f, indent=2)
PY
    fi
  else
    echo '{"communityPluginsEnabled": true}' > "$app_json"
  fi

  # Configure custom-sort plugin (must not be suspended)
  local cs_dir="$wiki_dir/.obsidian/plugins/custom-sort"
  if [[ -d "$cs_dir" && ! -f "$cs_dir/data.json" ]]; then
    cat > "$cs_dir/data.json" <<'CSJSON'
{"suspended":false,"statusBarEntryEnabled":true,"notificationsEnabled":true,"customSortContextSubmenu":true}
CSJSON
  fi

  printf "\n  ${DIM}Key shortcuts:${RESET}\n"
  printf "    ${GREEN}•${RESET} ${BOLD}Cmd+Shift+F${RESET}    ${DIM}→ Omnisearch (fuzzy search)${RESET}\n"
  printf "    ${GREEN}•${RESET} ${BOLD}Cmd+R${RESET}          ${DIM}→ Quick switcher (headings)${RESET}\n"
  printf "    ${GREEN}•${RESET} ${BOLD}Cmd+←/→${RESET}        ${DIM}→ Navigate back/forward${RESET}\n"
  printf "    ${GREEN}•${RESET} ${BOLD}Cmd+Shift+B${RESET}    ${DIM}→ Toggle left sidebar${RESET}\n"
  printf "    ${GREEN}•${RESET} ${BOLD}Cmd+Shift+L${RESET}    ${DIM}→ Toggle right sidebar${RESET}\n"
  printf "    ${GREEN}•${RESET} ${BOLD}Cmd+F11${RESET}        ${DIM}→ Workplace fullscreen${RESET}\n"
  printf "    ${GREEN}•${RESET} ${BOLD}Cmd+Shift+F11${RESET}  ${DIM}→ Editor fullscreen focus${RESET}\n"
  printf "\n"
}

prompt_obsidian_action() {
  local choice

  if $NON_INTERACTIVE; then
    echo "merge"
    return 0
  fi

  printf "\n  ${GREEN}>${RESET} ${BOLD}.obsidian already exists in the project root.${RESET}\n" >&2
  printf "    ${GREEN}1${RESET}) Merge config and install missing plugins ${DIM}(default)${RESET}\n" >&2
  printf "    ${GREEN}2${RESET}) Only install missing plugins\n" >&2
  printf "    ${GREEN}3${RESET}) Skip Obsidian config\n" >&2
  printf "  ${GREEN}>${RESET} ${BOLD}Choose${RESET} ${DIM}(Default: 1)${RESET}: " >&2
  read -r choice < /dev/tty

  case "${choice:-1}" in
    2) echo "plugins" ;;
    3) echo "skip" ;;
    *) echo "merge" ;;
  esac
}

merge_obsidian_project_config() {
  local project_root="$1"

  mkdir -p "$project_root/.obsidian"

  if [[ -f "$LOCAL_TEMPLATE/base/.obsidian/hotkeys.json" ]]; then
    if [[ -f "$project_root/.obsidian/hotkeys.json" ]]; then
      info "Merging ${CYAN}hotkeys.json${RESET} (existing config preserved)"
      merge_json "$project_root/.obsidian/hotkeys.json" "$LOCAL_TEMPLATE/base/.obsidian/hotkeys.json"
    else
      cp "$LOCAL_TEMPLATE/base/.obsidian/hotkeys.json" "$project_root/.obsidian/"
    fi
  fi

  if [[ -f "$LOCAL_TEMPLATE/base/.obsidian/app.json" ]]; then
    if [[ -f "$project_root/.obsidian/app.json" ]]; then
      info "Merging ${CYAN}app.json${RESET}"
      merge_json "$project_root/.obsidian/app.json" "$LOCAL_TEMPLATE/base/.obsidian/app.json"
    else
      cp "$LOCAL_TEMPLATE/base/.obsidian/app.json" "$project_root/.obsidian/"
    fi
  fi

  rm -f "$project_root/.obsidian/appearance.json" 2>/dev/null || true
}

configure_obsidian_project() {
  local project_root="$1"
  local action="merge"

  detect_dev_mode || download_template

  if [[ -d "$project_root/.obsidian" ]]; then
    action="$(prompt_obsidian_action)"
  else
    mkdir -p "$project_root/.obsidian"
  fi

  case "$action" in
    skip)
      info "Skipped Obsidian config"
      return 0
      ;;
    merge)
      merge_obsidian_project_config "$project_root"
      install_obsidian_plugins "$project_root"
      ;;
    plugins)
      install_obsidian_plugins "$project_root"
      ;;
  esac

  rm -f "$project_root/.obsidian/appearance.json" 2>/dev/null || true
}

setup_wiki() {
  [[ -n "$PROJECT_ROOT" ]] || resolve_project_context
  detect_dev_mode || true

  info "Set up embedded LLM Wiki:"
  WIKI_LANG=$(prompt_language)
  WIKI_NAME="$(prompt_wiki_title "$WIKI_NAME")"
  WIKI_TARGET="$PROJECT_ROOT/.llm-wiki"
  info "Project: ${CYAN}$(rel_path "$PROJECT_ROOT")${RESET}"
  info "Output: ${CYAN}$(rel_path "$WIKI_TARGET")${RESET}"

  prepare_wiki "$WIKI_TARGET"
  replace_placeholders "$WIKI_TARGET" "$WIKI_NAME"
  ensure_project_agents "$PROJECT_ROOT" "$WIKI_NAME"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 4: Finalize
# ═══════════════════════════════════════════════════════════════════════════════

cleanup_installer() {
  # Clean up downloaded template
  [[ -n "$TEMPLATE_TMPDIR" ]] && rm -rf "$TEMPLATE_TMPDIR" 2>/dev/null || true
}

print_success() {
  local name="$1" target="$2"
  local abs_target
  abs_target="$(cd "$target" 2>/dev/null && pwd)" || abs_target="$target"
  local abs_project="${PROJECT_ROOT:-$(pwd)}"

  printf "\n${BOLD}${SUCCESS}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
  printf "${BOLD}${SUCCESS}  ✓${RESET} %s ${BOLD}${SUCCESS}LLM Wiki is ready!${RESET}\n" "$name"
  printf "${SUCCESS}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

  printf "\n${BOLD}Operations ${DIM}(inside your AI agent)${RESET}${BOLD}:${RESET}\n\n"
  printf "  ${MAGENTA}${BOLD}1. Analyze${RESET} ${DIM}→${RESET}  ${BLUE}Analyze this repository and update .llm-wiki${RESET}\n"
  printf "             ${DIM}Use the current project as source material${RESET}\n"
  printf "  ${MAGENTA}${BOLD}2. Query${RESET}   ${DIM}→${RESET}  ${BLUE}What does this repository do?${RESET}\n"
  printf "             ${DIM}Ask questions, get answers with .llm-wiki citations${RESET}\n"
  printf "  ${MAGENTA}${BOLD}3. Lint${RESET}    ${DIM}→${RESET}  ${BLUE}Run a health check on .llm-wiki${RESET}\n"
  printf "             ${DIM}Find orphans, stale pages, and missing concepts${RESET}\n"

  printf "\n${BOLD}Quick start:${RESET}\n\n"
  local step_n=1
  if [[ "$abs_project" != "$(pwd)" ]]; then
    printf "  ${DIM}%d.${RESET} cd ${CYAN}%s${RESET}\n" "$step_n" "$abs_project"
    step_n=$((step_n + 1))
  fi
  if [[ "$OS" == "macos" ]]; then
    printf "  ${DIM}%d.${RESET} open -a Obsidian .       ${DIM}# open project as Obsidian vault${RESET}\n" "$step_n"
  elif [[ "$OS" == "windows" ]]; then
    printf "  ${DIM}%d.${RESET} obsidian .               ${DIM}# open project as Obsidian vault (Git Bash)${RESET}\n" "$step_n"
    printf "     ${DIM}or: start obsidian %s  ${DIM}# Windows CMD/PowerShell${RESET}\n" "$abs_project"
  else
    printf "  ${DIM}%d.${RESET} obsidian .               ${DIM}# open project as Obsidian vault${RESET}\n" "$step_n"
  fi
  step_n=$((step_n + 1))
  printf "  ${DIM}%d.${RESET} claude                   ${DIM}# or codex / gemini / another agent${RESET}\n" "$step_n"
  printf "  ${DIM}%d.${RESET} ${CYAN}%s${RESET}        ${DIM}# analysis output${RESET}\n" "$((step_n + 1))" "$abs_target"
  printf "\n"
}

# ─── CLI Args ─────────────────────────────────────────────────────────────────

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
      --non-interactive|--yes|-y) NON_INTERACTIVE=true; shift ;;
      --skip-install)    SKIP_INSTALL=true; shift ;;
      --only-tools)      ONLY_TOOLS=true; shift ;;
      --only-obsidian)   ONLY_OBSIDIAN=true; shift ;;
      --only-wiki)       ONLY_WIKI=true; shift ;;
      --help|-h)         usage; exit 0 ;;
      --version|-v)      echo "llm-wiki-builder v$VERSION"; exit 0 ;;
      *)                 warn "Unknown option: $1"; shift ;;
    esac
  done

  # Validate mutually exclusive mode flags
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
llm-wiki-builder — Create an LLM Wiki knowledge base in one command

Usage:
  curl -fsSL https://raw.githubusercontent.com/eleven-net-cn/llm-wiki-starter/main/install.sh | bash
  bash install.sh [OPTIONS]
  bash install.sh --only-tools [OPTIONS]
  bash install.sh --only-obsidian [--dir <project>] [OPTIONS]
  bash install.sh --only-wiki [--dir <project>] [--name <name>] [OPTIONS]

Modes:
  Default              Install tools → Initialize .llm-wiki → Configure Obsidian
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
  --yes, -y            Skip all prompts, use defaults (non-interactive mode)
  --skip-install       Skip tool installation in default mode
  --help               Show this help
  --version            Show version

Environment:
  LLM_WIKI_DIR         Project directory (same as --dir)

Examples:
  # Full interactive install
  bash install.sh

  # Non-interactive full install
  bash install.sh --yes --name my-project-wiki

  # Only install tools (no project changes)
  bash install.sh --only-tools

  # Full Obsidian setup in existing project (software + plugins + config)
  bash install.sh --only-obsidian --dir ~/code/my-project

  # Only initialize embedded wiki (tools already installed)
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

# ═══════════════════════════════════════════════════════════════════════════════
# Config Merge Helpers
# ═══════════════════════════════════════════════════════════════════════════════
# Priority: jq (best, cross-platform) → Bash (fallback)
# ──────────────────────────────────────────────────────────────────────────────

# Merge JSON: template overrides target (deep merge)
merge_json() {
  local target_file="$1" template_file="$2"

  # jq: best, cross-platform consistent
  if command -v jq &>/dev/null; then
    jq -s '.[0] * .[1]' "$target_file" "$template_file" > "${target_file}.merged" 2>/dev/null
    mv "${target_file}.merged" "$target_file"
    return 0
  fi

  # Bash fallback: backup and use template
  warn "jq not available — backing up user config and using template"
  cp "$target_file" "${target_file}.bak"
  cp "$template_file" "$target_file"
}

# Merge hotkeys.json
merge_hotkeys() {
  local target_dir="$1" template_dir="$2"
  local target="$target_dir/.obsidian/hotkeys.json"
  local template="$template_dir/.obsidian/hotkeys.json"

  [[ ! -f "$target" ]] && { cp "$template" "$target"; return 0; }
  merge_json "$target" "$template"
}

# Merge community-plugins.json: combine and deduplicate
merge_plugins() {
  local target_dir="$1" new_plugins="$2"
  local target="$target_dir/.obsidian/community-plugins.json"

  [[ ! -f "$target" ]] && { echo "$new_plugins" > "$target"; return 0; }

  # jq: merge and dedupe
  if command -v jq &>/dev/null; then
    echo "$(cat "$target") $new_plugins" | jq -s 'add | unique' > "$target"
    return 0
  fi

  # Bash: simple dedupe
  local all=$(grep -oE '"[^"]+"' "$target" "$new_plugins" | tr -d '"' | sort -u | tr '\n' ' ')
  all=$(echo "$all" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  # Format as JSON array
  local result="["
  local first=true
  for id in $all; do
    if $first; then first=false; else result+=","; fi
    result+="\"$id\""
  done
  result+="]"
  echo "$result" > "$target"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
  local url_line="By eleven-net-cn  ${TEMPLATE_REPO_URL}"
  local inner_w=73
  local border
  border=$(printf '%*s' "$inner_w" '' | tr ' ' '─')
  printf "\n${BOLD}${GREEN}┌${border}┐${RESET}\n"
  printf "${BOLD}${GREEN}│${RESET}  ${BOLD}${GREEN}LLM Wiki Builder${RESET} v%-$((inner_w - 20))s${BOLD}${GREEN}│${RESET}\n" "$VERSION"
  printf "${BOLD}${GREEN}│${RESET}  ${DIM}%-$((inner_w - 2))s${RESET}${BOLD}${GREEN}│${RESET}\n" "Embedded project wiki scaffolding"
  printf "${BOLD}${GREEN}│${RESET}  ${DIM}%-$((inner_w - 2))s${RESET}${BOLD}${GREEN}│${RESET}\n" "$url_line"
  printf "${BOLD}${GREEN}└${border}┘${RESET}\n\n"

  detect_os
  info "OS: ${CYAN}$OS${RESET}  |  Package manager: ${CYAN}${PKG_MGR:-none}${RESET}"

  if $ONLY_TOOLS; then
    info "Mode: ${GREEN}--only-tools${RESET} (install tools only)"
    detect_installed
    print_detection_results

    if is_all_installed; then
      success "All tools already installed"
    elif $NON_INTERACTIVE || prompt_confirm "Install missing tools?" "Y"; then
      run_install
    else
      print_manual_guide
    fi
    return 0
  fi

  resolve_project_context
  if declare -F detect_runtime_paths >/dev/null 2>&1 && \
     declare -F persist_detected_paths_once >/dev/null 2>&1; then
    detect_runtime_paths
    persist_detected_paths_once "$PROJECT_ROOT"
  fi

  if $ONLY_OBSIDIAN; then
    info "Mode: ${GREEN}--only-obsidian${RESET} (configure Obsidian in project root)"
    detect_installed

    if ! $HAS_OBSIDIAN; then
      info "Obsidian not installed — installing..."
      install_obsidian
    else
      success "Obsidian already installed"
    fi

    if ! command -v jq &>/dev/null; then
      info "Installing jq for JSON merge..."
      install_jq || true
    fi

    configure_obsidian_project "$PROJECT_ROOT"
    printf "\n${SUCCESS}✓${RESET} Obsidian setup complete!${RESET}\n"
    cleanup_installer
    return 0
  fi

  if $ONLY_WIKI; then
    info "Mode: ${GREEN}--only-wiki${RESET} (initialize embedded .llm-wiki only)"
    stepn "1" "2" "Initializing .llm-wiki"
    setup_wiki

    stepn "2" "2" "Finalizing"
    cleanup_installer
    print_success "$WIKI_NAME" "$WIKI_TARGET"
    return 0
  fi

  detect_installed

  local total_steps=4
  local need_install=false
  local current_step=1

  if ! $SKIP_INSTALL && ! is_all_installed; then
    need_install=true
    total_steps=5
  fi

  stepn "$current_step" "$total_steps" "Detecting installed tools"
  print_detection_results
  current_step=$((current_step + 1))

  if $SKIP_INSTALL; then
    info "Skipping tool installation ${DIM}(--skip-install)${RESET}"
  elif $need_install; then
    if prompt_confirm "Install missing items?" "Y"; then
      stepn "$current_step" "$total_steps" "Installing tools"
      run_install
      current_step=$((current_step + 1))
    else
      info "Skipped automatic installation"
      print_manual_guide
      current_step=$((current_step + 1))
    fi
  fi

  stepn "$current_step" "$total_steps" "Initializing .llm-wiki"
  setup_wiki
  current_step=$((current_step + 1))

  stepn "$current_step" "$total_steps" "Configuring Obsidian"
  configure_obsidian_project "$PROJECT_ROOT"
  current_step=$((current_step + 1))

  stepn "$current_step" "$total_steps" "Finalizing"
  cleanup_installer
  print_success "$WIKI_NAME" "$WIKI_TARGET"
}
