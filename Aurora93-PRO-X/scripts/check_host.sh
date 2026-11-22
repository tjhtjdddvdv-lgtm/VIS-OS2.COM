#!/usr/bin/env bash
set -euo pipefail
echo "== VIS OS Aurora 93 PRO X: build host check =="
for cmd in xorriso grub-mkrescue grub-mkstandalone grub-file mcopy; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '[OK]   %s: %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf '[MISS] %s\n' "$cmd"
  fi
done
echo
echo "Debian 13 package candidates:"
for pkg in xorriso grub-common grub-pc-bin grub-efi-ia32-bin grub-efi-amd64-bin mtools; do
  apt-cache policy "$pkg" 2>/dev/null | sed -n '1,3p' || true
done
echo
echo "This script checks tools only; it does not build or certify a bootable ISO."
