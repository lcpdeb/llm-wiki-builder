#!/usr/bin/env bash
set -euo pipefail

check_file_utf8_no_bom() {
  local file="$1"
  python - "$file" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
data = path.read_bytes()
if data.startswith(b"\xef\xbb\xbf"):
    print(f"FAIL: BOM found in {path}")
    sys.exit(1)
try:
    data.decode("utf-8")
except UnicodeDecodeError as e:
    print(f"FAIL: not valid UTF-8: {path} ({e})")
    sys.exit(1)
print(f"OK: {path}")
PY
}

check_file_utf8_no_bom "install.sh"
for f in scripts/lib/*.sh; do
  check_file_utf8_no_bom "$f"
done
