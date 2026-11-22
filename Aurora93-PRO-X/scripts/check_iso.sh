#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path/to/image.iso" >&2
  exit 2
fi
iso="$1"
[[ -f "$iso" ]] || { echo "ISO not found: $iso" >&2; exit 1; }
command -v xorriso >/dev/null || { echo "xorriso is required" >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "== File =="
file "$iso"
echo "== El Torito boot report =="
xorriso -indev "$iso" -report_el_torito plain 2>&1 || true
echo "== EFI fallback files =="
xorriso -osirrox on -indev "$iso" -extract /EFI "$tmp/EFI" >/dev/null 2>&1 || true
for f in "$tmp/EFI/BOOT/BOOTIA32.EFI" "$tmp/EFI/BOOT/BOOTX64.EFI"; do
  if [[ -f "$f" ]]; then
    printf '[FOUND] %s\n' "${f##*/}"
    file "$f"
  else
    printf '[MISSING] %s\n' "${f##*/}"
  fi
done
