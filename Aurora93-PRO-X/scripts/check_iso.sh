#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 path/to/image.iso" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
iso="$1"
[[ -f "$iso" ]] || { echo "ERROR: ISO not found: $iso" >&2; exit 1; }

for cmd in xorriso objdump file grep awk; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required command is missing: $cmd" >&2
    exit 1
  }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf '%s\n' '== ISO file =='
file "$iso"

printf '%s\n' '== El Torito boot entries =='
if ! xorriso -indev "$iso" -report_el_torito plain >"$tmp/el-torito.txt" 2>&1; then
  cat "$tmp/el-torito.txt" >&2
  echo "ERROR: xorriso could not read the El Torito catalog" >&2
  exit 1
fi
cat "$tmp/el-torito.txt"

# xorriso's plain report labels entries as BIOS/UEFI in the
# "El Torito boot img" rows. Accept the explicit PlatformId form too.
if ! grep -Eiq '^El Torito boot img[[:space:]]*:[[:space:]]*[0-9]+[[:space:]]+BIOS([[:space:]]|$)|PlatformId:[[:space:]]*0x00([[:space:]]|$)' "$tmp/el-torito.txt"; then
  echo "ERROR: Legacy BIOS El Torito entry (platform 0x00) was not found" >&2
  exit 1
fi
if ! grep -Eiq '^El Torito boot img[[:space:]]*:[[:space:]]*[0-9]+[[:space:]]+UEFI([[:space:]]|$)|PlatformId:[[:space:]]*0xEF([[:space:]]|$)' "$tmp/el-torito.txt"; then
  echo "ERROR: UEFI El Torito entry (platform 0xEF) was not found" >&2
  exit 1
fi

printf '%s\n' '== EFI fallback executable architecture =='
for spec in 'BOOTIA32.EFI:pei-i386' 'BOOTX64.EFI:pei-x86-64'; do
  name="${spec%%:*}"
  expected="${spec#*:}"
  extracted="$tmp/$name"
  if ! xorriso -osirrox on -indev "$iso" -extract "/EFI/BOOT/$name" "$extracted" >/dev/null 2>&1; then
    echo "ERROR: missing or unreadable /EFI/BOOT/$name" >&2
    exit 1
  fi
  if ! format="$(objdump -f "$extracted" 2>/dev/null | awk '/file format/ {print $NF; exit}')"; then
    format=""
  fi
  if [[ "$format" != "$expected" ]]; then
    echo "ERROR: $name has format '${format:-unknown}', expected '$expected'" >&2
    file "$extracted" >&2 || true
    exit 1
  fi
  printf '[OK] %s: %s\n' "$name" "$format"
done

printf '%s\n' 'PASS: ISO contains BIOS + UEFI El Torito entries and correctly typed IA32/x86-64 EFI fallback binaries.'
