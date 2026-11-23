#!/usr/bin/env bash
# Fail-closed boot-path planner for a DIGMA Citi 1804 Stage 105 hardware report.
# Reads a report only; it does not build, install, flash, or modify boot entries.
set -euo pipefail
usage(){ echo "Usage: $0 HARDWARE_REPORT.txt" >&2; }
[[ "${1:-}" == "--help" ]] && { usage; exit 0; }
[[ $# -eq 1 ]] || { usage; exit 2; }
report="$1"
[[ -f "$report" && -r "$report" ]] || { echo "BLOCKED: report is missing or unreadable: $report" >&2; exit 2; }

expected_header='VIS OS Aurora 93 PRO X — DIGMA Citi 1804 hardware report'
IFS= read -r header < "$report" || header=''
[[ "$header" == "$expected_header" ]] || {
  echo "BLOCKED: report signature does not match the Stage 105 DIGMA hardware report." >&2
  exit 3
}

# Require exactly one non-empty instance of each consumed field. This prevents
# a malformed report from hiding contradictory duplicate values after the first.
field(){
 local key="$1" count value
 count="$(awk -v key="$key" 'index($0,key ": ")==1 {n++} END {print n+0}' "$report")"
 [[ "$count" == 1 ]] || {
  echo "BLOCKED: expected exactly one '$key' field, found $count." >&2
  return 1
 }
 value="$(awk -v key="$key" 'index($0,key ": ")==1 {print substr($0,length(key)+3); exit}' "$report")"
 [[ -n "$value" ]] || {
  echo "BLOCKED: field '$key' is empty." >&2
  return 1
 }
 printf '%s' "$value"
}

vendor="$(field 'System vendor')"
product="$(field 'Product name')"
lm="$(field 'CPU long-mode flag (lm)')"
fw_iface="$(field 'UEFI sysfs interface')"
fw_arch=''
if [[ "$fw_iface" == 'present' ]]; then
 fw_arch="$(field 'Firmware architecture')"
fi
norm(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' '; }
vendor_n="$(norm "$vendor")"; product_n="$(norm "$product")"
if [[ "$vendor_n" != *digma* || ( "$product_n" != *"citi 1804"* && "$product_n" != *"citi1804"* ) ]]; then
 echo "BLOCKED: report does not positively identify DIGMA Citi 1804 (vendor='${vendor:-missing}', product='${product:-missing}')." >&2; exit 3
fi
[[ "$lm" == "yes" ]] || { echo "BLOCKED: CPU long-mode capability is not confirmed (value='${lm:-missing}')." >&2; exit 3; }
[[ "$fw_iface" == "present" ]] || { echo "BLOCKED: UEFI sysfs interface is not present. This does not prove Legacy-only firmware; boot Linux Live explicitly in UEFI mode and collect a new report." >&2; exit 3; }
case "$fw_arch" in
 "32-bit IA32")
 cat <<'REPORT'
VIS OS Aurora 93 PRO X — BOOT PATH DECISION
Target: DIGMA Citi 1804
Evidence: DIGMA DMI identity; CPU long-mode flag=yes; UEFI sysfs interface=present; firmware=32-bit IA32.

EFI application candidate: /EFI/BOOT/BOOTIA32.EFI
EFI application architecture: IA32 (PEI-i386)
CPU capability: x86_64 long mode reported
Kernel selection: BLOCKED — not authorized by this report.
Mixed-mode status: REQUIRED if attempting an x86_64 kernel through IA32 UEFI; not proven.

Required next validation:
1. Verify the physical device's firmware architecture from a Linux Live boot.
2. Verify the IA32 EFI loader binary with objdump/file.
3. Test a supported IA32-UEFI-to-x86_64-kernel mixed-mode path on this device.
4. Until that succeeds, do not label a 64-bit-kernel ISO as compatible.

BIOS path: NOT DETERMINED by this UEFI report; validate separately.
ISO status: NOT BUILT / NOT BOOT-TESTED.
REPORT
 ;;
 "64-bit x86-64")
 cat <<'REPORT'
VIS OS Aurora 93 PRO X — BOOT PATH DECISION
Target: DIGMA Citi 1804
Evidence: DIGMA DMI identity; CPU long-mode flag=yes; UEFI sysfs interface=present; firmware=64-bit x86-64.

EFI application candidate: /EFI/BOOT/BOOTX64.EFI
EFI application architecture: x86-64 (PEI-x86-64)
Kernel architecture candidate: x86_64
Kernel/driver compatibility: NOT PROVEN; must be built and tested.

Required next validation:
1. Verify the physical device's firmware architecture from a Linux Live boot.
2. Verify the EFI binary architecture with objdump/file.
3. Build a non-destructive test image and boot it from USB on the target device.
4. Test storage, display, touch, keyboard/trackpad, Wi-Fi, audio, battery and sleep/wake separately.

BIOS path: NOT DETERMINED by this UEFI report; validate separately.
ISO status: NOT BUILT / NOT BOOT-TESTED.
REPORT
 ;;
 *) echo "BLOCKED: firmware architecture is unknown or unsupported ('${fw_arch:-missing}'). Do not choose IA32 or x64 EFI binaries yet." >&2; exit 3 ;;
esac
