#!/usr/bin/env bash
# UTF-8 (no BOM)

# key|display_name|command|skills_slug|skills_dir|install_url|install_cmd
# Order defines default priority.
AI_AGENT_REGISTRY=(
  "claude|Claude Code|claude|claude-code|~/.claude/skills|https://claude.ai/claude-code|npm install -g @anthropic-ai/claude-code"
  "codex|Codex|codex|codex|~/.codex/skills|https://github.com/openai/codex|npm install -g @openai/codex"
  "gemini|Gemini|gemini|gemini-cli|~/.gemini/skills|https://github.com/google-gemini/gemini-cli|npm install -g @google/gemini-cli"
)

AVAILABLE_AI_AGENT_KEYS=()
DETECTED_AI_AGENT_PATHS=()
HAS_AI_AGENT=false
AI_AGENT_SELECTION_DONE=false
SELECTED_AI_AGENT_KEY=""
SELECTED_AI_AGENT_NAME=""
SELECTED_AI_AGENT_PATH=""

OBSIDIAN_SKILLS_TOTAL=0
OBSIDIAN_SKILLS_GLOBAL_FOUND=0
OBSIDIAN_SKILLS_SELECTED_SYMLINK=0
OBSIDIAN_SKILLS_SELECTED_NON_SYMLINK=0
OBSIDIAN_SKILLS_MISSING=0

VISUAL_SKILLS_TOTAL=0
VISUAL_SKILLS_GLOBAL_FOUND=0
VISUAL_SKILLS_SELECTED_SYMLINK=0
VISUAL_SKILLS_SELECTED_NON_SYMLINK=0
VISUAL_SKILLS_MISSING=0

agent_expand_path() {
  local value="${1:-}"
  case "$value" in
    "~/"*) printf '%s/%s\n' "$HOME" "${value#\~/}" ;;
    "\$HOME/"*) printf '%s/%s\n' "$HOME" "${value#\$HOME/}" ;;
    *) printf '%s\n' "$value" ;;
  esac
}

agent_field() {
  local wanted_key="$1" wanted_field="$2"
  local entry key display_name command skills_slug skills_dir install_url install_cmd

  for entry in "${AI_AGENT_REGISTRY[@]}"; do
    IFS='|' read -r key display_name command skills_slug skills_dir install_url install_cmd <<EOF
$entry
EOF
    [[ "$key" == "$wanted_key" ]] || continue
    case "$wanted_field" in
      key) printf '%s\n' "$key" ;;
      display_name|name) printf '%s\n' "$display_name" ;;
      command|cmd) printf '%s\n' "$command" ;;
      skills_slug|agent_slug) printf '%s\n' "$skills_slug" ;;
      skills_dir|skills_root) agent_expand_path "$skills_dir" ;;
      install_url|url) printf '%s\n' "$install_url" ;;
      install_cmd|install_command) printf '%s\n' "$install_cmd" ;;
      *) return 1 ;;
    esac
    return 0
  done

  return 1
}

ai_agent_keys() {
  local entry key rest
  for entry in "${AI_AGENT_REGISTRY[@]}"; do
    IFS='|' read -r key rest <<EOF
$entry
EOF
    printf '%s\n' "$key"
  done
}

default_ai_agent_key() {
  local entry key rest
  entry="${AI_AGENT_REGISTRY[0]:-}"
  [[ -n "$entry" ]] || return 1
  IFS='|' read -r key rest <<EOF
$entry
EOF
  printf '%s\n' "$key"
}

agent_names_joined() {
  local sep="${1:- / }"
  local key name first=true
  for key in $(ai_agent_keys); do
    name="$(agent_field "$key" display_name)"
    if $first; then
      first=false
    else
      printf '%s' "$sep"
    fi
    printf '%s' "$name"
  done
  printf '\n'
}

clear_detected_ai_agent_paths() {
  DETECTED_AI_AGENT_PATHS=()
}

set_agent_detected_path() {
  local key="$1" path="${2:-}"
  local entry existing_key existing_path
  local -a next_paths

  next_paths=()
  for entry in "${DETECTED_AI_AGENT_PATHS[@]}"; do
    IFS='|' read -r existing_key existing_path <<EOF
$entry
EOF
    [[ "$existing_key" == "$key" ]] && continue
    next_paths+=("$entry")
  done
  next_paths+=("$key|$path")
  DETECTED_AI_AGENT_PATHS=("${next_paths[@]}")
}

agent_detected_path() {
  local wanted_key="$1"
  local entry key path

  for entry in "${DETECTED_AI_AGENT_PATHS[@]}"; do
    IFS='|' read -r key path <<EOF
$entry
EOF
    if [[ "$key" == "$wanted_key" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  done

  return 1
}

agent_command_exists() {
  local key="$1" command path
  path="$(agent_detected_path "$key" 2>/dev/null || true)"
  if [[ -n "$path" ]]; then
    return 0
  fi

  command="$(agent_field "$key" command 2>/dev/null || true)"
  [[ -n "$command" ]] || return 1
  command -v "$command" >/dev/null 2>&1
}

detect_ai_agents() {
  local key command path

  AVAILABLE_AI_AGENT_KEYS=()
  for key in $(ai_agent_keys); do
    path="$(agent_detected_path "$key" 2>/dev/null || true)"
    if [[ -z "$path" ]]; then
      command="$(agent_field "$key" command)"
      path="$(command -v "$command" 2>/dev/null || true)"
      [[ -n "$path" ]] && set_agent_detected_path "$key" "$path"
    fi

    if agent_command_exists "$key"; then
      AVAILABLE_AI_AGENT_KEYS+=("$key")
    fi
  done

  if [[ "${#AVAILABLE_AI_AGENT_KEYS[@]}" -gt 0 ]]; then
    HAS_AI_AGENT=true
  else
    HAS_AI_AGENT=false
    SELECTED_AI_AGENT_KEY=""
    SELECTED_AI_AGENT_NAME=""
    SELECTED_AI_AGENT_PATH=""
  fi
}

ai_agent_is_available() {
  local wanted_key="$1" key
  for key in "${AVAILABLE_AI_AGENT_KEYS[@]}"; do
    [[ "$key" == "$wanted_key" ]] && return 0
  done
  return 1
}

ai_agent_name() {
  agent_field "$1" display_name 2>/dev/null || printf '%s\n' "$1"
}

ai_agent_path() {
  agent_detected_path "$1" 2>/dev/null || true
}

preferred_ai_agent_key() {
  local key
  for key in $(ai_agent_keys); do
    if ai_agent_is_available "$key"; then
      printf '%s\n' "$key"
      return 0
    fi
  done
  return 1
}

set_selected_ai_agent() {
  local key="$1"
  SELECTED_AI_AGENT_KEY="$key"
  SELECTED_AI_AGENT_NAME="$(agent_field "$key" display_name)"
  SELECTED_AI_AGENT_PATH="$(agent_detected_path "$key" 2>/dev/null || true)"
  HAS_AI_AGENT=true
}

select_ai_agent() {
  detect_ai_agents
  $HAS_AI_AGENT || return 1

  local count key default_key choice idx selected_key
  count="${#AVAILABLE_AI_AGENT_KEYS[@]}"

  if [[ -n "$SELECTED_AI_AGENT_KEY" ]] && ai_agent_is_available "$SELECTED_AI_AGENT_KEY"; then
    set_selected_ai_agent "$SELECTED_AI_AGENT_KEY"
    return 0
  fi

  default_key="$(preferred_ai_agent_key || true)"
  [[ -n "$default_key" ]] || return 1

  if [[ "$count" -eq 1 || "$NON_INTERACTIVE" == "true" ]]; then
    set_selected_ai_agent "$default_key"
    AI_AGENT_SELECTION_DONE=true
    return 0
  fi

  if $AI_AGENT_SELECTION_DONE; then
    set_selected_ai_agent "$default_key"
    return 0
  fi

  printf "\n  ${GREEN}>${RESET} ${BOLD}Multiple AI agents detected:${RESET}\n" >&2
  idx=1
  for key in "${AVAILABLE_AI_AGENT_KEYS[@]}"; do
    printf "    ${GREEN}%d${RESET}) %-12s ${DIM}%s${RESET}\n" "$idx" "$(agent_field "$key" display_name)" "$(agent_detected_path "$key" 2>/dev/null || true)" >&2
    idx=$((idx + 1))
  done
  printf "  ${GREEN}>${RESET} ${BOLD}Choose AI agent${RESET} ${DIM}(Default: 1)${RESET}: " >&2
  read -r choice < /dev/tty
  choice="${choice:-1}"

  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$count" ]]; then
    selected_key="${AVAILABLE_AI_AGENT_KEYS[$((choice - 1))]}"
  else
    selected_key="$default_key"
  fi

  set_selected_ai_agent "$selected_key"
  AI_AGENT_SELECTION_DONE=true
}

selected_skills_agent_slug() {
  [[ -n "${SELECTED_AI_AGENT_KEY:-}" ]] || return 1
  agent_field "$SELECTED_AI_AGENT_KEY" skills_slug
}

selected_skills_root_dir() {
  [[ -n "${SELECTED_AI_AGENT_KEY:-}" ]] || return 1
  agent_field "$SELECTED_AI_AGENT_KEY" skills_dir
}

global_skills_root_dir() {
  printf '%s\n' "$HOME/.agents/skills"
}

obsidian_skill_names() {
  printf '%s\n' defuddle json-canvas obsidian-bases obsidian-cli obsidian-markdown
}

visual_skill_names() {
  printf '%s\n' excalidraw-diagram mermaid-visualizer obsidian-canvas-creator
}

compute_skill_package_status() {
  local prefix="$1"
  shift
  local source_root="" target_root="" skill_name="" source_dir="" target_dir="" link_target=""
  local total=0 global_found=0 selected_symlink=0 selected_non_symlink=0 missing=0

  source_root="$(global_skills_root_dir)"
  target_root="$(selected_skills_root_dir 2>/dev/null || true)"

  for skill_name in "$@"; do
    total=$((total + 1))
    source_dir="$source_root/$skill_name"
    target_dir="$target_root/$skill_name"

    if [[ -d "$source_dir" ]]; then
      global_found=$((global_found + 1))
    fi

    if [[ -L "$target_dir" ]]; then
      link_target="$(readlink "$target_dir" 2>/dev/null || true)"
      if [[ "$link_target" == "$source_dir" && -d "$source_dir" ]]; then
        selected_symlink=$((selected_symlink + 1))
      else
        selected_non_symlink=$((selected_non_symlink + 1))
      fi
    elif [[ -e "$target_dir" ]]; then
      selected_non_symlink=$((selected_non_symlink + 1))
    else
      missing=$((missing + 1))
    fi
  done

  eval "${prefix}_SKILLS_TOTAL=$total"
  eval "${prefix}_SKILLS_GLOBAL_FOUND=$global_found"
  eval "${prefix}_SKILLS_SELECTED_SYMLINK=$selected_symlink"
  eval "${prefix}_SKILLS_SELECTED_NON_SYMLINK=$selected_non_symlink"
  eval "${prefix}_SKILLS_MISSING=$missing"
}

skills_status_text() {
  local prefix="$1"
  local total=0 global_found=0 selected_symlink=0 selected_non_symlink=0 missing=0
  local agent_key=""
  local status=""

  eval "total=\${${prefix}_SKILLS_TOTAL:-0}"
  eval "global_found=\${${prefix}_SKILLS_GLOBAL_FOUND:-0}"
  eval "selected_symlink=\${${prefix}_SKILLS_SELECTED_SYMLINK:-0}"
  eval "selected_non_symlink=\${${prefix}_SKILLS_SELECTED_NON_SYMLINK:-0}"
  eval "missing=\${${prefix}_SKILLS_MISSING:-0}"
  agent_key="${SELECTED_AI_AGENT_KEY:-selected-agent}"

  if [[ "$total" -eq 0 ]]; then
    printf 'requires selected AI agent\n'
    return 0
  fi

  if [[ "$selected_symlink" -eq "$total" ]]; then
    printf 'linked %s/%s (%s)\n' "$selected_symlink" "$total" "$agent_key"
    return 0
  fi

  status="linked ${selected_symlink}/${total}, global ${global_found}/${total}"
  if [[ "$selected_non_symlink" -gt 0 ]]; then
    status+=", non-link ${selected_non_symlink}/${total}"
  fi
  if [[ "$missing" -gt 0 ]]; then
    status+=", missing ${missing}/${total}"
  fi
  printf '%s\n' "$status"
}

detect_selected_agent_skills() {
  HAS_OBSIDIAN_SKILLS=false
  HAS_VISUAL_SKILLS=false
  OBSIDIAN_SKILLS_TOTAL=0
  OBSIDIAN_SKILLS_GLOBAL_FOUND=0
  OBSIDIAN_SKILLS_SELECTED_SYMLINK=0
  OBSIDIAN_SKILLS_SELECTED_NON_SYMLINK=0
  OBSIDIAN_SKILLS_MISSING=0
  VISUAL_SKILLS_TOTAL=0
  VISUAL_SKILLS_GLOBAL_FOUND=0
  VISUAL_SKILLS_SELECTED_SYMLINK=0
  VISUAL_SKILLS_SELECTED_NON_SYMLINK=0
  VISUAL_SKILLS_MISSING=0
  $HAS_AI_AGENT || return 0

  compute_skill_package_status "OBSIDIAN" $(obsidian_skill_names)
  compute_skill_package_status "VISUAL" $(visual_skill_names)

  if [[ "$OBSIDIAN_SKILLS_TOTAL" -gt 0 && "$OBSIDIAN_SKILLS_SELECTED_SYMLINK" -eq "$OBSIDIAN_SKILLS_TOTAL" ]]; then
    HAS_OBSIDIAN_SKILLS=true
  fi
  if [[ "$VISUAL_SKILLS_TOTAL" -gt 0 && "$VISUAL_SKILLS_SELECTED_SYMLINK" -eq "$VISUAL_SKILLS_TOTAL" ]]; then
    HAS_VISUAL_SKILLS=true
  fi
}
