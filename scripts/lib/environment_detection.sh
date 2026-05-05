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
    if [[ "${MSYS:-}" != *winsymlinks:* ]]; then
      export MSYS="${MSYS:+$MSYS }winsymlinks:nativestrict"
      info "MSYS symlink mode: ${CYAN}winsymlinks:nativestrict${RESET}"
    fi
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
  HAS_GIT=false
  HAS_NODE=false
  HAS_OBSIDIAN=false
  HAS_AI_AGENT=false
  HAS_OBSIDIAN_SKILLS=false
  HAS_VISUAL_SKILLS=false
  AVAILABLE_AI_AGENT_KEYS=()
  VER_GIT=""
  VER_NODE=""

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

  detect_ai_agents
  select_ai_agent || true

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

  detect_selected_agent_skills
}

print_detection_results() {
  printf "\n"
  $HAS_AI_AGENT && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed: %s${RESET}\n" "AI Agent" "$SELECTED_AI_AGENT_NAME" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}recommended: %s${RESET}\n" "AI Agent" "$(agent_names_joined " / ")"
  $HAS_NODE && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}%s${RESET}\n" "Node.js" "$VER_NODE" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}required for skills / agent CLIs${RESET}\n" "Node.js"
  $HAS_OBSIDIAN && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}installed${RESET}\n" "Obsidian" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}wiki editor${RESET}\n" "Obsidian"
  $HAS_OBSIDIAN_SKILLS && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}%s${RESET}\n" "Obsidian Skills" "$(skills_status_text "OBSIDIAN")" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}%s${RESET}\n" "Obsidian Skills" "$(skills_status_text "OBSIDIAN")"
  $HAS_VISUAL_SKILLS && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}%s${RESET}\n" "Visual Skills" "$(skills_status_text "VISUAL")" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}%s${RESET}\n" "Visual Skills" "$(skills_status_text "VISUAL")"
  $HAS_GIT && printf "  ${GREEN}✓${RESET}  %-20s ${DIM}%s${RESET}\n" "Git" "$VER_GIT" || printf "  ${YELLOW}✗${RESET}  %-20s ${CYAN}optional, for versioning${RESET}\n" "Git"
  printf "  ${GREEN}→${RESET}  %-20s ${DIM}auto-configured with wiki${RESET}\n" "Obsidian Plugins"
  printf "\n"
}

is_all_installed() {
  $HAS_OBSIDIAN && $HAS_NODE && $HAS_AI_AGENT && $HAS_OBSIDIAN_SKILLS && $HAS_VISUAL_SKILLS && $HAS_GIT
}

print_manual_guide() {
  printf "\n  ${BOLD}Manual install guide:${RESET}\n\n"
  $HAS_OBSIDIAN || printf "  %-20s ${DIM}${UNDERLINE}https://obsidian.md${RESET}\n" "Obsidian"
  $HAS_NODE || printf "  %-20s ${DIM}${UNDERLINE}https://nodejs.org${RESET}\n" "Node.js"
  if ! $HAS_AI_AGENT; then
    local default_agent_key="" default_agent_url="" default_agent_cmd="" agent_names=""
    default_agent_key="$(default_ai_agent_key 2>/dev/null || true)"
    default_agent_url="$(agent_field "$default_agent_key" install_url 2>/dev/null || true)"
    default_agent_cmd="$(agent_field "$default_agent_key" install_cmd 2>/dev/null || true)"
    agent_names="$(agent_names_joined " / " 2>/dev/null || true)"
    printf "  %-20s ${DIM}${UNDERLINE}%s${RESET} ${DIM}(default priority; %s supported)${RESET}\n" "AI Agent" "$default_agent_url" "$agent_names"
    printf "  %-20s ${GREEN}%s${RESET}\n" "" "$default_agent_cmd"
  fi
  $HAS_OBSIDIAN_SKILLS || printf "  %-20s ${DIM}${UNDERLINE}https://github.com/kepano/obsidian-skills${RESET}\n" "Obsidian Skills"
  if ! $HAS_OBSIDIAN_SKILLS && $HAS_AI_AGENT; then
    local skills_root="" global_skills_root=""
    skills_root="$(selected_skills_root_dir 2>/dev/null || true)"
    global_skills_root="$(global_skills_root_dir 2>/dev/null || true)"
    printf "  %-20s ${GREEN}npx skills add kepano/obsidian-skills -g -y${RESET}\n" ""
    printf "  %-20s ${DIM}link %s/<skill> -> %s/<skill>${RESET}\n" "" "${global_skills_root:-~/.agents/skills}" "${skills_root:-<selected agent skills dir>}"
  fi
  $HAS_VISUAL_SKILLS || printf "  %-20s ${DIM}${UNDERLINE}https://github.com/axtonliu/axton-obsidian-visual-skills${RESET}\n" "Visual Skills"
  if ! $HAS_VISUAL_SKILLS && $HAS_AI_AGENT; then
    local skills_root_v="" global_skills_root_v=""
    skills_root_v="$(selected_skills_root_dir 2>/dev/null || true)"
    global_skills_root_v="$(global_skills_root_dir 2>/dev/null || true)"
    printf "  %-20s ${GREEN}npx skills add axtonliu/axton-obsidian-visual-skills -g -y${RESET}\n" ""
    printf "  %-20s ${DIM}link %s/<skill> -> %s/<skill>${RESET}\n" "" "${global_skills_root_v:-~/.agents/skills}" "${skills_root_v:-<selected agent skills dir>}"
  fi
  $HAS_GIT || printf "  %-20s ${DIM}${UNDERLINE}https://git-scm.com${RESET}\n" "Git"
  printf "  %-20s ${DIM}${UNDERLINE}https://obsidian.md/clip${RESET} ${DIM}(save web pages to wiki)${RESET}\n" "Web Clipper"
  printf "\n"
}
