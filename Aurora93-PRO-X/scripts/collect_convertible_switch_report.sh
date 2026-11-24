#!/usr/bin/env bash
# Read-only inventory of Linux tablet-mode and input switch capabilities.
set -euo pipefail
SYS_ROOT="${VIS_SYS_ROOT:-/sys}"
OUTPUT="${1:-VIS_OS_CITI1804_CONVERTIBLE_REPORT.txt}"

read_one() {
  local path="$1" value
  if [[ -r "$path" ]]; then
    value="$(<"$path")"
    value="${value//$'\r'/}"
    value="${value//$'\n'/; }"
    [[ -n "$value" ]] || value="(empty)"
    printf '%s' "$value"
  else
    printf '%s' 'not available'
  fi
}
clean_value() {
  local value="$1"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"
  printf '%s' "$value" | tr -cd '[:print:]\t'
}

render_report() {
  local event device name sw_caps compact last_digit nibble sw_lid sw_tablet
  local node value mode found=0
  shopt -s nullglob
  printf '%s\n' 'VIS OS Aurora 93 PRO X — convertible switch diagnostic' \
    'Read-only report; capability does not prove switch state or working mode transition.'

  printf '\n%s\n' '[Input switch capabilities]'
  for event in "$SYS_ROOT"/class/input/event*; do
    [[ -d "$event" ]] || continue
    device="$event/device"
    name="$(read_one "$device/name")"
    sw_caps="$(read_one "$device/capabilities/sw")"
    compact="${sw_caps//[[:space:]]/}"
    sw_lid='unknown'
    sw_tablet='unknown'
    if [[ "$compact" =~ ^[[:xdigit:]]+$ ]]; then
      last_digit="${compact: -1}"
      nibble=$((16#$last_digit))
      if (( nibble & 1 )); then sw_lid='yes'; else sw_lid='no'; fi
      if (( nibble & 2 )); then sw_tablet='yes'; else sw_tablet='no'; fi
    fi
    printf '%s name=%s sw_caps=%s SW_LID=%s SW_TABLET_MODE=%s current_state=not_exposed_by_capability_mask\n' \
      "$(basename "$event")" "$(clean_value "$name")" "$(clean_value "$sw_caps")" "$sw_lid" "$sw_tablet"
    found=1
  done
  if [[ "$found" -eq 0 ]]; then printf '%s\n' 'No input event devices exposed.'; fi

  printf '\n%s\n' '[Readable tablet_mode sysfs nodes]'
  found=0
  local -a candidates=()
  for node in "$SYS_ROOT"/devices/platform/*/tablet_mode "$SYS_ROOT"/bus/platform/devices/*/tablet_mode; do
    [[ -e "$node" ]] || continue
    candidates+=("$node")
  done
  if [[ "${#candidates[@]}" -eq 0 ]]; then
    printf '%s\n' 'No direct platform tablet_mode attributes exposed.'
  else
    for node in "${candidates[@]}"; do
      value="$(read_one "$node")"
      case "$value" in
        0) mode='laptop';;
        1) mode='tablet';;
        *) mode='unknown';;
      esac
      printf 'path=%s value=%s interpreted_mode=%s\n' \
        "${node#"$SYS_ROOT"}" "$(clean_value "$value")" "$mode"
    done
  fi

  printf '\n%s\n' '[Interpretation limits]' \
    '- SW_TABLET_MODE=yes means the input device advertises that event capability; it does not expose the current state.' \
    '- A readable tablet_mode sysfs value 0/1 is a state candidate; multiple nodes may disagree and must be investigated.' \
    '- Do not enable automatic Laptop/Tablet switching from capability presence alone.' \
    '- This report does not change input settings, sysfs values, firmware, partitions, EFI variables or eMMC.'
}

if [[ "$OUTPUT" == '-' ]]; then
  render_report
  exit 0
fi
out_dir="$(dirname "$OUTPUT")"
[[ -d "$out_dir" ]] || { echo "ERROR: output directory does not exist: $out_dir" >&2; exit 1; }
tmp_file="$(mktemp "$out_dir/.vis-convertible-report.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT
render_report > "$tmp_file"
mv -f "$tmp_file" "$OUTPUT"
trap - EXIT
printf 'Convertible switch report written to: %s\n' "$OUTPUT"
