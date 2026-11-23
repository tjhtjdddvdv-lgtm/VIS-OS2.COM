#!/usr/bin/env bash
# Read-only inventory of build tools and Debian package availability.
set -euo pipefail
required_commands=(xorriso objdump file grub-mkstandalone grub-mkimage mformat mcopy)
required_packages=(xorriso binutils file grub-common grub-pc-bin grub-efi-ia32-bin grub-efi-amd64-bin mtools)
missing_commands=0; missing_packages=0
printf '%s\n' 'VIS OS Aurora 93 PRO X — BUILD ENVIRONMENT AUDIT'
printf 'Host architecture: %s\n' "$(uname -m 2>/dev/null || printf unknown)"
printf 'Userspace bits: %s\n' "$(getconf LONG_BIT 2>/dev/null || printf unknown)"
printf '\n[Commands]\n'
for cmd in "${required_commands[@]}"; do
 if path="$(command -v "$cmd" 2>/dev/null)"; then printf '[FOUND] %s -> %s\n' "$cmd" "$path"
 else printf '[MISSING] %s\n' "$cmd"; missing_commands=$((missing_commands+1)); fi
done
printf '\n[Debian package metadata]\n'
if command -v dpkg-query >/dev/null 2>&1; then
 for pkg in "${required_packages[@]}"; do
  status="$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)"
  if [[ "$status" == "install ok installed" ]]; then printf '[INSTALLED] %s\n' "$pkg"
  else printf '[NOT INSTALLED / UNKNOWN] %s\n' "$pkg"; missing_packages=$((missing_packages+1)); fi
 done
else
 printf '[UNKNOWN] dpkg-query unavailable; package database not inspected.\n'
 missing_packages=${#required_packages[@]}
fi
printf '\n[Summary]\nMissing commands: %s\nMissing/unverified packages: %s\n' "$missing_commands" "$missing_packages"
if (( missing_commands == 0 && missing_packages == 0 )); then
 echo 'AUDIT: required command/package set is present. This does not prove that a target ISO can be built or booted.'
else
 echo 'AUDIT: build environment is incomplete or unverified. Do not start the final ISO build.'
fi
exit 0
