#!/usr/bin/env bash
# UTF-8 (no BOM)
# Detect local executable/app paths and persist once to llm-wiki/detected-paths.json

DETECTED_OBSIDIAN_PATH=""

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
  local key cmd p

  if [[ -n "${APPDATA:-}" ]]; then
    appdata_posix="$(_windows_to_posix_path "$APPDATA" 2>/dev/null || true)"
  fi

  clear_detected_ai_agent_paths
  for key in $(ai_agent_keys); do
    cmd="$(agent_field "$key" command)"
    p="$(_resolve_cmd_path_windows "$cmd" || true)"
    if [[ -z "$p" ]]; then
      p="$(_first_existing_file \
        "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/$cmd}" \
        "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/$cmd.cmd}" \
        "${win_user:+/c/Users/$win_user/AppData/Roaming/npm/$cmd.exe}" \
        "${appdata_posix:+$appdata_posix/npm/$cmd}" \
        "${appdata_posix:+$appdata_posix/npm/$cmd.cmd}" \
        "${appdata_posix:+$appdata_posix/npm/$cmd.exe}" \
      )" || true
    fi
    set_agent_detected_path "$key" "$p"
  done
}

detect_agent_paths_posix() {
  local key cmd p

  clear_detected_ai_agent_paths
  for key in $(ai_agent_keys); do
    cmd="$(agent_field "$key" command)"
    p="$(_resolve_cmd_path "$cmd" || true)"
    set_agent_detected_path "$key" "$p"
  done
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
      clear_detected_ai_agent_paths
      ;;
  esac
}

persist_detected_paths_once() {
  local repo_root="$1"
  local cfg_dir="$repo_root/llm-wiki"
  local cfg_file="$cfg_dir/detected-paths.json"
  local root_gitignore="$repo_root/.gitignore"
  local ignore_entry="/llm-wiki/detected-paths.json"
  local ts
  local obsidian_path
  local selected_key selected_name selected_path
  local key agent_key agent_path

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
  selected_key="$(_json_escape "${SELECTED_AI_AGENT_KEY:-}")"
  selected_name="$(_json_escape "${SELECTED_AI_AGENT_NAME:-}")"
  selected_path="$(_json_escape "${SELECTED_AI_AGENT_PATH:-}")"

  {
    printf '{\n'
    printf '  "platform": "%s",\n' "${OS:-unknown}"
    printf '  "detected_at": "%s",\n' "$ts"
    printf '  "obsidian": {\n'
    printf '    "path": "%s"\n' "$obsidian_path"
    printf '  },\n'
    printf '  "agents": {\n'
    printf '    "selected": {\n'
    printf '      "key": "%s",\n' "$selected_key"
    printf '      "name": "%s",\n' "$selected_name"
    printf '      "path": "%s"\n' "$selected_path"
    printf '    }'

    for key in $(ai_agent_keys); do
      agent_key="$(_json_escape "$key")"
      agent_path="$(_json_escape "$(agent_detected_path "$key" 2>/dev/null || true)")"
      printf ',\n'
      printf '    "%s": {\n' "$agent_key"
      printf '      "path": "%s"\n' "$agent_path"
      printf '    }'
    done
    printf '\n'
    printf '  }\n'
    printf '}\n'
  } > "$cfg_file"
}

