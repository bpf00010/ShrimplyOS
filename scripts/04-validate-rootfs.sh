#!/usr/bin/env bash
# 🦐 Shrimply OS: RootFS Validation Script 🦐
set -euo pipefail

TARGET_DIR="${1:-/mnt/shrimply-os}"
OUTPUT_FORMAT="${2:-text}"

pass_count=0
warn_count=0
fail_count=0
declare -a PASS_ITEMS=()
declare -a WARN_ITEMS=()
declare -a FAIL_ITEMS=()

pass() {
  echo "[PASS] $1"
  pass_count=$((pass_count + 1))
  PASS_ITEMS+=("$1")
}

warn() {
  echo "[WARN] $1"
  warn_count=$((warn_count + 1))
  WARN_ITEMS+=("$1")
}

fail() {
  echo "[FAIL] $1"
  fail_count=$((fail_count + 1))
  FAIL_ITEMS+=("$1")
}

json_escape() {
  local raw="$1"
  raw="${raw//\\/\\\\}"
  raw="${raw//\"/\\\"}"
  raw="${raw//$'\n'/\\n}"
  printf '%s' "$raw"
}

print_json_array() {
  local -n arr_ref=$1
  local first=1
  printf '['
  for item in "${arr_ref[@]}"; do
    if [[ $first -eq 0 ]]; then
      printf ','
    fi
    first=0
    printf '"%s"' "$(json_escape "$item")"
  done
  printf ']'
}

emit_summary() {
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    printf '{\n'
    printf '  "target_dir": "%s",\n' "$(json_escape "$TARGET_DIR")"
    printf '  "pass": %d,\n' "$pass_count"
    printf '  "warn": %d,\n' "$warn_count"
    printf '  "fail": %d,\n' "$fail_count"
    printf '  "status": "%s",\n' "$([[ "$fail_count" -gt 0 ]] && echo fail || echo pass)"
    printf '  "pass_items": '
    print_json_array PASS_ITEMS
    printf ',\n  "warn_items": '
    print_json_array WARN_ITEMS
    printf ',\n  "fail_items": '
    print_json_array FAIL_ITEMS
    printf '\n}\n'
  else
    echo ""
    echo "🦐 Validation summary: pass=$pass_count warn=$warn_count fail=$fail_count"
  fi
}

check_file() {
  local file_path="$1"
  local description="$2"
  if [[ -e "$file_path" ]]; then
    pass "$description"
  else
    fail "$description (missing: $file_path)"
  fi
}

check_grep() {
  local file_path="$1"
  local pattern="$2"
  local description="$3"
  if sed -e 's/\r$//' "$file_path" | grep -Eq "$pattern"; then
    pass "$description"
  else
    fail "$description (pattern not found in $file_path)"
  fi
}

echo "🦐 Starting Shrimply OS rootfs validation..."

[[ -d "$TARGET_DIR" ]] || {
  fail "Target directory does not exist: $TARGET_DIR"
  emit_summary
  exit 2
}

check_file "$TARGET_DIR/bin/bash" "Base shell present"
check_file "$TARGET_DIR/usr/bin/apt-get" "APT present"
check_file "$TARGET_DIR/etc/systemd/system/default.target" "Systemd default target link present"
check_file "$TARGET_DIR/etc/lightdm/lightdm.conf" "LightDM main config present"
check_file "$TARGET_DIR/etc/lightdm/lightdm-gtk-greeter.conf" "LightDM greeter config present"
check_file "$TARGET_DIR/tmp/scripts/02-hardware-detect.sh" "Hardware detection script copied"

if [[ -L "$TARGET_DIR/etc/systemd/system/default.target" ]]; then
  target_resolved="$(readlink -f "$TARGET_DIR/etc/systemd/system/default.target" || true)"
  if [[ "$target_resolved" == */multi-user.target ]]; then
    pass "Default target is multi-user.target (TUI-first)"
  else
    fail "Default target is not multi-user.target (actual: $target_resolved)"
  fi
else
  fail "Default target symlink is missing or invalid"
fi

check_grep "$TARGET_DIR/etc/lightdm/lightdm.conf" '^user-session=xfce$' "LightDM defaults to XFCE session"
check_grep "$TARGET_DIR/etc/lightdm/lightdm.conf" '^allow-guest=false$' "LightDM guest login disabled"
check_grep "$TARGET_DIR/etc/lightdm/lightdm.conf" '^xserver-allow-tcp=false$' "LightDM disables X TCP listener"

if [[ -x "$TARGET_DIR/tmp/scripts/02-hardware-detect.sh" ]]; then
  pass "Hardware detection script is executable"
else
  warn "Hardware detection script is not executable inside target"
fi

if grep -Eq '/tmp/scripts/02-hardware-detect.sh' "$TARGET_DIR/root/.profile"; then
  pass "Root profile launches hardware detection flow"
else
  warn "Root profile does not launch hardware detection flow"
fi

echo ""
emit_summary

if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi

exit 0
