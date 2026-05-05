#!/usr/bin/env bash
# UTF-8 (no BOM)
# Detect local executable/app paths and persist once to .llm-wiki/detected-paths.json

DETECTED_OBSIDIAN_PATH=""
DETECTED_AGENT_CLAUDE_PATH=""
DETECTED_AGENT_CODEX_PATH=""
DETECTED_AGENT_GEMINI_PATH=""

_first_existing_file() {
  local p
  for p in "$@"; do
    [[ -n "$p" && -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

_resolve_cmd_path() {
  local cmd="$1"
  local p=""
  p="$(command -v "$cmd" 2>/dev/null || true)"
  [[ -n "$p" ]] && printf '%s\n' "$p"
}

_windows_to_posix_path() {
  local win_path="${1:-}"
  local drive_letter rest

  [[ -z "$win_path" ]] && return 1

  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$win_path" 2>/dev/null
    return $?
  fi

  if [[ "$win_path" =~ ^([A-Za-z]):\\(.*)$ ]]; then
    drive_letter="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
    rest="${BASH_REMATCH[2]//\\//}"
    printf '/%s/%s\n' "$drive_letter" "$rest"
    return 0
  fi

  printf '%s\n' "$win_path"
  return 0
}

_resolve_cmd_path_windows() {
  local cmd="$1"
  local p="" raw=""

  p="$(_resolve_cmd_path "$cmd")"
  if [[ -n "$p" && -f "$p" ]]; then
    printf '%s\n' "$p"
    return 0
  fi

  if command -v where.exe >/dev/null 2>&1; then
    raw="$(where.exe "$cmd" 2>/dev/null | tr -d '\r' | head -n 1 || true)"
    if [[ -n "$raw" ]]; then
      p="$(_windows_to_posix_path "$raw" 2>/dev/null || true)"
      if [[ -n "$p" && -f "$p" ]]; then
        printf '%s\n' "$p"
        return 0
      fi
    fi
  fi

  return 1
}

_resolve_windows_app_path_registry() {
  local exe_name="$1"
  local key raw p
  local -a keys

  command -v reg.exe >/dev/null 2>&1 || return 1

  keys=(
    "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\$exe_name"
    "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\$exe_name"
    "HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\App Paths\\$exe_name"
  )

  for key in "${keys[@]}"; do
    raw="$(reg.exe query "$key" /ve 2>/dev/null | tr -d '\r' | sed -n 's/.*REG_SZ[[:space:]]*//p' | head -n 1 || true)"
    [[ -z "$raw" ]] && continue
    p="$(_windows_to_posix_path "$raw" 2>/dev/null || true)"
    if [[ -n "$p" && -f "$p" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done

  return 1
}

_json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

detect_obsidian_path_windows() {
  local p=""
  local win_user="${USER:-${USERNAME:-}}"
  local localappdata_posix=""
  local user_local_obsidian=""
  local user_local_programs_obsidian=""
  local drive_root=""
  local -a common_candidates

  if [[ -n "$win_user" ]]; then
    user_local_obsidian="/c/Users/$win_user/AppData/Local/Obsidian/Obsidian.exe"
    user_local_programs_obsidian="/c/Users/$win_user/AppData/Local/Programs/Obsidian/Obsidian.exe"
  fi
  if [[ -n "${LOCALAPPDATA:-}" ]]; then
    localappdata_posix="$(_windows_to_posix_path "$LOCALAPPDATA" 2>/dev/null || true)"
  fi

  # Priority 1: automatic executable detection (includes PATH, but not limited to it)
  p="$(_resolve_cmd_path_windows obsidian || true)"
  if [[ -n "$p" ]]; then
    DETECTED_OBSIDIAN_PATH="$p"
    return 0
  fi

  p="$(_resolve_windows_app_path_registry "Obsidian.exe" || true)"
  if [[ -n "$p" ]]; then
    DETECTED_OBSIDIAN_PATH="$p"
    return 0
  fi

  # Priority 2: common install locations
  common_candidates=(
    "$user_local_obsidian"
    "$user_local_programs_obsidian"
    "${localappdata_posix:+$localappdata_posix/Obsidian/Obsidian.exe}"
    "${localappdata_posix:+$localappdata_posix/Programs/Obsidian/Obsidian.exe}"
    "/c/Program Files/Obsidian/Obsidian.exe"
    "/c/Program Files (x86)/Obsidian/Obsidian.exe"
    "/d/Obsidian/Obsidian.exe"
  )

  for drive_root in /[a-z]; do
    [[ -d "$drive_root" ]] || continue
    common_candidates+=(
      "$drive_root/Obsidian/Obsidian.exe"
      "$drive_root/Program Files/Obsidian/Obsidian.exe"
      "$drive_root/Program Files (x86)/Obsidian/Obsidian.exe"
    )
  done

  p="$(_first_existing_file "${common_candidates[@]}")" || true

  if [[ -n "$p" ]]; then
    DETECTED_OBSIDIAN_PATH="$p"
    return 0
  fi

  DETECTED_OBSIDIAN_PATH=""
  return 1
}

detect_obsidian_path_macos() {
  local p=""
  p="$(_resolve_cmd_path obsidian)"
  if [[ -n "$p" ]]; then
    DETECTED_OBSIDIAN_PATH="$p"
    return 0
  fi
  if [[ -d "/Applications/Obsidian.app" ]]; then
    DETECTED_OBSIDIAN_PATH="/Applications/Obsidian.app"
    return 0
  fi
  DETECTED_OBSIDIAN_PATH=""
  return 1
}

detect_obsidian_path_linux() {
  local p=""
  p="$(_resolve_cmd_path obsidian)"
  if [[ -n "$p" ]]; then
    DETECTED_OBSIDIAN_PATH="$p"
    return 0
  fi
  p="$(_first_existing_file \
    "/usr/bin/obsidian" \
    "/usr/local/bin/obsidian" \
    "/var/lib/flatpak/exports/bin/md.obsidian.Obsidian" \
  )" || true
  if [[ -n "$p" ]]; then
    DETECTED_OBSIDIAN_PATH="$p"
    return 0
  fi
  DETECTED_OBSIDIAN_PATH=""
  return 1
}

detect_agent_paths_windows() {
  local win_user="${USER:-${USERNAME:-}}"
  local appdata_posix=""

  if [[ -n "${APPDATA:-}" ]]; then
    appdata_posix="$(_windows_to_posix_path "$APPDATA" 2>/dev/null || true)"
  fi

  DETECTED_AGENT_CLAUDE_PATH="$(_resolve_cmd_path_windows claude || true)"
  DETECTED_AGENT_CODEX_PATH="$(_resolve_cmd_path_windows codex || true)"
  DETECTED_AGENT_GEMINI_PATH="$(_resolve_cmd_path_windows gemini || true)"

  if [[ -z "$DETECTED_AGENT_CLAUDE_PATH" ]]; then
    DETECTED_AGENT_CLAUDE_PATH="$(_first_existing_file \
      "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/claude}" \
      "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/claude.cmd}" \
      "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/claude.exe}" \
      "${appdata_posix:+$appdata_posix/npm/claude}" \
      "${appdata_posix:+$appdata_posix/npm/claude.cmd}" \
      "${appdata_posix:+$appdata_posix/npm/claude.exe}" \
    )" || true
  fi

  if [[ -z "$DETECTED_AGENT_CODEX_PATH" ]]; then
    DETECTED_AGENT_CODEX_PATH="$(_first_existing_file \
      "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/codex}" \
      "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/codex.cmd}" \
      "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/codex.exe}" \
      "${appdata_posix:+$appdata_posix/npm/codex}" \
      "${appdata_posix:+$appdata_posix/npm/codex.cmd}" \
      "${appdata_posix:+$appdata_posix/npm/codex.exe}" \
    )" || true
  fi

  if [[ -z "$DETECTED_AGENT_GEMINI_PATH" ]]; then
    DETECTED_AGENT_GEMINI_PATH="$(_first_existing_file \
      "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/gemini}" \
      "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/gemini.cmd}" \
      "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/gemini.exe}" \
      "${appdata_posix:+$appdata_posix/npm/gemini}" \
      "${appdata_posix:+$appdata_posix/npm/gemini.cmd}" \
      "${appdata_posix:+$appdata_posix/npm/gemini.exe}" \
    )" || true
  fi
}

detect_agent_paths_posix() {
  DETECTED_AGENT_CLAUDE_PATH="$(_resolve_cmd_path claude || true)"
  DETECTED_AGENT_CODEX_PATH="$(_resolve_cmd_path codex || true)"
  DETECTED_AGENT_GEMINI_PATH="$(_resolve_cmd_path gemini || true)"
}

detect_runtime_paths() {
  case "${OS:-}" in
    windows)
      detect_obsidian_path_windows || true
      detect_agent_paths_windows
      ;;
    macos)
      detect_obsidian_path_macos || true
      detect_agent_paths_posix
      ;;
    linux)
      detect_obsidian_path_linux || true
      detect_agent_paths_posix
      ;;
    *)
      DETECTED_OBSIDIAN_PATH=""
      DETECTED_AGENT_CLAUDE_PATH=""
      DETECTED_AGENT_CODEX_PATH=""
      DETECTED_AGENT_GEMINI_PATH=""
      ;;
  esac
}

persist_detected_paths_once() {
  local repo_root="$1"
  local cfg_dir="$repo_root/.llm-wiki"
  local cfg_file="$cfg_dir/detected-paths.json"
  local root_gitignore="$repo_root/.gitignore"
  local ignore_entry="/.llm-wiki/detected-paths.json"
  local ts
  local obsidian_path claude_path codex_path gemini_path

  # Keep detected local paths out of VCS at project root scope.
  if [[ -f "$root_gitignore" ]]; then
    grep -Fxq "$ignore_entry" "$root_gitignore" || printf '\n%s\n' "$ignore_entry" >> "$root_gitignore"
  else
    printf '%s\n' "$ignore_entry" > "$root_gitignore"
  fi

  [[ -f "$cfg_file" ]] && return 0
  mkdir -p "$cfg_dir"

  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")"
  obsidian_path="$(_json_escape "$DETECTED_OBSIDIAN_PATH")"
  claude_path="$(_json_escape "$DETECTED_AGENT_CLAUDE_PATH")"
  codex_path="$(_json_escape "$DETECTED_AGENT_CODEX_PATH")"
  gemini_path="$(_json_escape "$DETECTED_AGENT_GEMINI_PATH")"

  cat > "$cfg_file" <<EOF
{
  "platform": "${OS:-unknown}",
  "detected_at": "$ts",
  "obsidian": {
    "path": "${obsidian_path}"
  },
  "agents": {
    "claude": {
      "path": "${claude_path}"
    },
    "codex": {
      "path": "${codex_path}"
    },
    "gemini": {
      "path": "${gemini_path}"
    }
  }
}
EOF
}

print_detected_paths_summary() {
  declare -F info >/dev/null 2>&1 || return 0
  info "Detected Obsidian path: ${CYAN}${DETECTED_OBSIDIAN_PATH:-<not found>}${RESET}"
  info "Detected claude path: ${CYAN}${DETECTED_AGENT_CLAUDE_PATH:-<not found>}${RESET}"
  info "Detected codex path: ${CYAN}${DETECTED_AGENT_CODEX_PATH:-<not found>}${RESET}"
  info "Detected gemini path: ${CYAN}${DETECTED_AGENT_GEMINI_PATH:-<not found>}${RESET}"
}
