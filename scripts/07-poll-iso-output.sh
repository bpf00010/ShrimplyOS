#!/usr/bin/env bash
set -euo pipefail

ART_DIR="${1:-/root/src/ShrimplyOS-run/build/artifacts}"
LOG_FILE="${2:-/root/src/ShrimplyOS-run/build/logs/iso-build.log}"
CHECK_SECONDS="${CHECK_SECONDS:-15}"
MAX_CHECKS="${MAX_CHECKS:-80}"

for _ in $(seq 1 "$MAX_CHECKS"); do
  iso_file="$(find "$ART_DIR" -maxdepth 3 -type f -name '*.iso' | head -n 1 || true)"
  sha_file="$(find "$ART_DIR" -maxdepth 3 -type f -name '*.sha256' | head -n 1 || true)"

  if [[ -n "$iso_file" ]]; then
    echo "ISO_READY:$iso_file"
    if [[ -n "$sha_file" ]]; then
      echo "SHA_READY:$sha_file"
    else
      echo "SHA_READY:pending"
    fi
    ls -lah "$ART_DIR"
    exit 0
  fi

  if ! pgrep -af '05-build-boot-image.sh' >/dev/null 2>&1; then
    echo "BUILD_STOPPED_NO_ISO"
    tail -n 80 "$LOG_FILE" 2>/dev/null || true
    exit 2
  fi

  echo "[$(date -u +%H:%M:%S)] waiting_for_iso"
  sleep "$CHECK_SECONDS"
done

echo "POLL_TIMEOUT_NO_ISO"
tail -n 60 "$LOG_FILE" 2>/dev/null || true
exit 3
