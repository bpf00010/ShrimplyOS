#!/usr/bin/env bash
# 🦐 Shrimply OS: ISO Build Progress Watcher 🦐
set -euo pipefail

LOG_FILE="${1:-build/logs/iso-build.log}"
REFRESH_SECONDS="${REFRESH_SECONDS:-1}"
BAR_WIDTH="${BAR_WIDTH:-46}"

declare -a PHASE_PATTERNS=(
  "Configuring live-build profile|lb config"
  "lb_bootstrap|Retrieving Packages|Base system installed successfully"
  "lb_chroot|chroot_archives|chroot_apt"
  "lb_binary_rootfs|mksquashfs"
  "lb_binary_iso|xorriso"
  "ISO build complete"
)

declare -a PHASE_PROGRESS=(
  8
  30
  62
  82
  95
  100
)

declare -a PHASE_LABELS=(
  "Configuring live-build"
  "Bootstrapping Debian rootfs"
  "Applying chroot customizations"
  "Assembling compressed rootfs"
  "Generating ISO image"
  "Completed"
)

repeat_char() {
  local count="$1"
  local symbol="$2"
  if (( count <= 0 )); then
    printf ''
    return
  fi
  printf '%*s' "$count" '' | tr ' ' "$symbol"
}

compute_progress_from_log() {
  local progress=0
  local label="Waiting for build log"

  if [[ ! -f "$LOG_FILE" ]]; then
    printf '%s|%s' "$progress" "$label"
    return
  fi

  local log_tail
  log_tail="$(tail -n 500 "$LOG_FILE" 2>/dev/null || true)"

  for index in "${!PHASE_PATTERNS[@]}"; do
    if grep -Eq "${PHASE_PATTERNS[$index]}" <<<"$log_tail"; then
      progress="${PHASE_PROGRESS[$index]}"
      label="${PHASE_LABELS[$index]}"
    fi
  done

  if grep -Eq "ISO build complete" <<<"$log_tail"; then
    progress=100
    label="Completed"
  fi

  if grep -Eq "\b(ERROR|Error|error)\b|^E:\s|Expected ISO not found|No such file or directory" <<<"$log_tail"; then
    label="Failed (check log tail)"
  fi

  printf '%s|%s' "$progress" "$label"
}

is_build_process_active() {
  pgrep -af "lb build|05-build-boot-image.sh|mksquashfs|xorriso" >/dev/null 2>&1
}

render_line() {
  local progress="$1"
  local state_label="$2"
  local active_label="$3"

  local filled
  filled=$(( progress * BAR_WIDTH / 100 ))
  local empty
  empty=$(( BAR_WIDTH - filled ))

  local bar_filled
  bar_filled="$(repeat_char "$filled" '#')"
  local bar_empty
  bar_empty="$(repeat_char "$empty" '-')"

  printf '\r[%s%s] %3d%% | %s | %s' "$bar_filled" "$bar_empty" "$progress" "$state_label" "$active_label"
}

printf '🦐 Watching ISO build progress from: %s\n' "$LOG_FILE"
printf 'Press Ctrl+C to exit watcher.\n\n'

while true; do
  progress_and_label="$(compute_progress_from_log)"
  current_progress="${progress_and_label%%|*}"
  current_label="${progress_and_label#*|}"

  if is_build_process_active; then
    activity="build-running"
  else
    activity="idle"
  fi

  render_line "$current_progress" "$current_label" "$activity"

  if [[ "$current_progress" -ge 100 && "$activity" == "idle" ]]; then
    printf '\n✅ ISO build finished successfully.\n'
    break
  fi

  if [[ "$current_label" == "Failed (check log tail)" && "$activity" == "idle" ]]; then
    printf '\n❌ ISO build appears to have failed. Last 40 log lines:\n\n'
    tail -n 40 "$LOG_FILE" 2>/dev/null || true
    exit 1
  fi

  sleep "$REFRESH_SECONDS"
done
