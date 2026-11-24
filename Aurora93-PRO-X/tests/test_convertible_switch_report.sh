#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/collect_convertible_switch_report.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SYS="$TMP/sys"
mkdir -p "$SYS/class/input/event3/device/capabilities" \
  "$SYS/class/input/event4/device/capabilities" \
  "$SYS/class/input/event5/device" \
  "$SYS/class/input/event6/device/capabilities" \
  "$SYS/devices/platform/hinge" "$SYS/bus/platform/devices/second-hinge"
printf 'Hinge Switch\n' > "$SYS/class/input/event3/device/name"
printf '00000002\n' > "$SYS/class/input/event3/device/capabilities/sw"
printf 'Lid Switch\n' > "$SYS/class/input/event4/device/name"
printf '00000001\n' > "$SYS/class/input/event4/device/capabilities/sw"
printf 'No switch mask\n' > "$SYS/class/input/event5/device/name"
printf 'Malformed mask\n' > "$SYS/class/input/event6/device/name"
printf 'not-hex\n' > "$SYS/class/input/event6/device/capabilities/sw"
printf '1\n' > "$SYS/devices/platform/hinge/tablet_mode"
printf '0\n' > "$SYS/bus/platform/devices/second-hinge/tablet_mode"

bash -n "$SCRIPT"
report="$(VIS_SYS_ROOT="$SYS" bash "$SCRIPT" -)"
grep -q 'event3 name=Hinge Switch sw_caps=00000002 SW_LID=no SW_TABLET_MODE=yes current_state=not_exposed_by_capability_mask' <<<"$report"
grep -q 'event4 name=Lid Switch sw_caps=00000001 SW_LID=yes SW_TABLET_MODE=no' <<<"$report"
grep -q 'event5 name=No switch mask sw_caps=not available SW_LID=unknown SW_TABLET_MODE=unknown' <<<"$report"
grep -q 'event6 name=Malformed mask sw_caps=not-hex SW_LID=unknown SW_TABLET_MODE=unknown' <<<"$report"
grep -q 'path=/devices/platform/hinge/tablet_mode value=1 interpreted_mode=tablet' <<<"$report"
grep -q 'path=/bus/platform/devices/second-hinge/tablet_mode value=0 interpreted_mode=laptop' <<<"$report"
grep -q 'multiple nodes may disagree' <<<"$report"
grep -q 'Do not enable automatic Laptop/Tablet switching from capability presence alone' <<<"$report"

OUT="$TMP/result.txt"
VIS_SYS_ROOT="$SYS" bash "$SCRIPT" "$OUT" >/dev/null
test -s "$OUT"
cmp -s <(printf '1\n') "$SYS/devices/platform/hinge/tablet_mode"
cmp -s <(printf '0\n') "$SYS/bus/platform/devices/second-hinge/tablet_mode"
echo '[PASS] SW_TABLET_MODE capability bit (bit 1)'
echo '[PASS] SW_LID capability bit (bit 0)'
echo '[PASS] missing and malformed capability masks remain unknown'
echo '[PASS] tablet_mode sysfs nodes are reported individually, including conflicts'
echo '[PASS] capability presence is not misreported as current switch state'
echo '[PASS] output-file mode and read-only fixture preservation'
echo 'PASS: all convertible switch diagnostics tests passed.'
