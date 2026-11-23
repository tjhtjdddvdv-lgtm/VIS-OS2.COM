#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
planner="$script_dir/../scripts/plan_boot_path.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
make_report(){
 local fw_iface="$1" fw_arch="$2" lm="$3" vendor="${4:-DIGMA}" product="${5:-CITI 1804}"
 cat > "$tmp/report.txt" <<REPORT
VIS OS Aurora 93 PRO X — DIGMA Citi 1804 hardware report
[Runtime]
CPU model from procfs: Intel(R) Atom(TM) x5-Z8350 CPU @ 1.44GHz
CPU long-mode flag (lm): $lm
[DMI]
System vendor: $vendor
Product name: $product
[UEFI]
UEFI sysfs interface: $fw_iface
Firmware architecture: $fw_arch
REPORT
}
bash -n "$planner"; bash -n "$script_dir/../scripts/check_build_environment.sh"
printf '[PASS] shell syntax\n'
make_report present '32-bit IA32' yes
bash "$planner" "$tmp/report.txt" > "$tmp/ia32.txt"
grep -q 'BOOTIA32.EFI' "$tmp/ia32.txt"; grep -q 'Kernel selection: BLOCKED' "$tmp/ia32.txt"; grep -q 'Mixed-mode status: REQUIRED' "$tmp/ia32.txt"
printf '[PASS] IA32 loader candidate; unverified 64-bit kernel blocked\n'
make_report present '64-bit x86-64' yes
bash "$planner" "$tmp/report.txt" > "$tmp/x64.txt"
grep -q 'BOOTX64.EFI' "$tmp/x64.txt"; grep -q 'Kernel architecture candidate: x86_64' "$tmp/x64.txt"
printf '[PASS] x64 loader candidate; kernel remains unverified\n'
make_report present unknown yes
if bash "$planner" "$tmp/report.txt" > "$tmp/u" 2>&1; then exit 1; fi
grep -q 'firmware architecture is unknown' "$tmp/u"; printf '[PASS] unknown firmware architecture blocked\n'
make_report 'not present in this running environment' unknown yes
if bash "$planner" "$tmp/report.txt" > "$tmp/e" 2>&1; then exit 1; fi
grep -q 'does not prove Legacy-only firmware' "$tmp/e"; printf '[PASS] missing EFI sysfs is not treated as Legacy proof\n'
make_report present '64-bit x86-64' unknown
if bash "$planner" "$tmp/report.txt" > "$tmp/lm" 2>&1; then exit 1; fi
grep -q 'long-mode capability is not confirmed' "$tmp/lm"; printf '[PASS] unknown CPU long mode blocked\n'
make_report present '64-bit x86-64' yes 'Unknown Vendor' 'Unknown Product'
if bash "$planner" "$tmp/report.txt" > "$tmp/id" 2>&1; then exit 1; fi
grep -q 'does not positively identify DIGMA Citi 1804' "$tmp/id"; printf '[PASS] mismatched DMI blocked\n'
if bash "$planner" "$tmp/no-report" > "$tmp/m" 2>&1; then exit 1; fi
grep -q 'missing or unreadable' "$tmp/m"; printf '[PASS] missing report rejected\n'
if bash "$planner" > "$tmp/usage" 2>&1; then exit 1; fi
grep -q 'Usage:' "$tmp/usage"; printf '[PASS] invalid invocation rejected\n'
echo 'PASS: all boot-path planner regression tests passed.'
