#!/usr/bin/env bash
# UTF-8 (no BOM)

merge_json() {
  local target_file="$1" template_file="$2"
  if command -v jq &>/dev/null; then
    jq -s '.[0] * .[1]' "$target_file" "$template_file" > "${target_file}.merged" 2>/dev/null
    mv "${target_file}.merged" "$target_file"
    return 0
  fi

  warn "jq not available - backing up user config and using template"
  cp "$target_file" "${target_file}.bak"
  cp "$template_file" "$target_file"
}

merge_hotkeys() {
  local target_dir="$1" template_dir="$2"
  local target="$target_dir/.obsidian/hotkeys.json"
  local template="$template_dir/.obsidian/hotkeys.json"
  [[ ! -f "$target" ]] && { cp "$template" "$target"; return 0; }
  merge_json "$target" "$template"
}

merge_plugins() {
  local target_dir="$1" new_plugins="$2"
  local target="$target_dir/.obsidian/community-plugins.json"
  [[ ! -f "$target" ]] && { echo "$new_plugins" > "$target"; return 0; }

  if command -v jq &>/dev/null; then
    echo "$(cat "$target") $new_plugins" | jq -s 'add | unique' > "$target"
    return 0
  fi

  local all
  all=$(grep -oE '"[^"]+"' "$target" "$new_plugins" | tr -d '"' | sort -u | tr '\n' ' ')
  all=$(echo "$all" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  local result="["
  local first=true
  local id
  for id in $all; do
    if $first; then first=false; else result+=","; fi
    result+="\"$id\""
  done
  result+="]"
  echo "$result" > "$target"
}
