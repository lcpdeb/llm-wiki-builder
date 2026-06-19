#!/usr/bin/env bash
# Thin entrypoint: loads modular installer libs and starts execution.

set -euo pipefail
export LC_MESSAGES=C

VERSION="1.0.1"
TEMPLATE_REPO="${TEMPLATE_REPO:-lcpdeb/llm-wiki-builder}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
if [[ -f "$SCRIPT_DIR/install.sh" ]]; then
  REPO_ROOT="$SCRIPT_DIR"
else
  REPO_ROOT="$(pwd)"
fi

MODULE_TMPDIR=""

cleanup_module_tmpdir() {
  [[ -n "$MODULE_TMPDIR" ]] && rm -rf "$MODULE_TMPDIR" 2>/dev/null || true
}
trap cleanup_module_tmpdir EXIT

load_lib_or_remote() {
  local file="$1"
  local local_path="$REPO_ROOT/scripts/lib/$file"

  if [[ -f "$local_path" ]]; then
    # shellcheck source=/dev/null
    source "$local_path"
    return 0
  fi

  MODULE_TMPDIR="${MODULE_TMPDIR:-$(mktemp -d)}"
  local remote_path="$MODULE_TMPDIR/$file"
  local remote_url="https://raw.githubusercontent.com/$TEMPLATE_REPO/main/scripts/lib/$file"

  if curl -fsSL "$remote_url" -o "$remote_path" 2>/dev/null; then
    # shellcheck source=/dev/null
    source "$remote_path"
    return 0
  fi

  printf "ERROR: Failed to load module: %s\n" "$file" >&2
  printf "  Tried local:  %s\n" "$local_path" >&2
  printf "  Tried remote: %s\n" "$remote_url" >&2
  return 1
}

# Core function set and progressive overrides.
load_lib_or_remote "ai_agent_registry.sh"
load_lib_or_remote "install_workflow.sh"
load_lib_or_remote "runtime_path_registry.sh"
load_lib_or_remote "environment_detection.sh"
load_lib_or_remote "obsidian_config_merge.sh"
load_lib_or_remote "cli_arguments.sh"

parse_args "$@"
main
