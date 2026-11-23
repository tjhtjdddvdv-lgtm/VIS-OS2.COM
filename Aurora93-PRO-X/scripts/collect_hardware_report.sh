#!/usr/bin/env bash
# Read-only hardware/firmware inventory for VIS OS Aurora 93 PRO X.
set -euo pipefail
SYS_ROOT="${VIS_SYS_ROOT:-/sys}"
PROC_ROOT="${VIS_PROC_ROOT:-/proc}"
REPORT_TIME="${VIS_REPORT_TIME:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
HOST_ARCH="${VIS_UNAME_M:-$(uname -m 2>/dev/null || printf unknown)}"
KERNEL_RELEASE="${VIS_UNAME_R:-$(uname -r 2>/dev/null || printf unknown)}"
LONG_BIT="${VIS_LONG_BIT:-$(getconf LONG_BIT 2>/dev/null || printf unknown)}"
OUTPUT="${1:-VIS_OS_CITI1804_HARDWARE_REPORT.txt}"

read_one() {
  local path="$1" value
  if [[ -r "$path" ]]; then
    value="$(<"$path")"
    value="${value//$'\r'/}"
    value="${value//$'\n'/; }"
    [[ -n "$value" ]] || value="(empty)"
    printf '%s' "$value"
  else
    printf '%s' "not available"
  fi
}
clean_value() {
  local value="$1"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"
  printf '%s' "$value" | tr -cd '[:print:]\t'
}
cpu_model() {
  [[ -r "$PROC_ROOT/cpuinfo" ]] || return 0
  awk -F: '/^(model name|Hardware)[[:space:]]*:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}' "$PROC_ROOT/cpuinfo"
}
cpu_long_mode() {
  if [[ -r "$PROC_ROOT/cpuinfo" ]]; then
    awk '/^flags[[:space:]]*:/ {if ($0 ~ /(^|[[:space:]])lm([[:space:]]|$)/) print "yes"; else print "not reported"; found=1; exit} END {if (!found) print "unknown"}' "$PROC_ROOT/cpuinfo"
  else
    printf '%s' "unknown"
  fi
}
render_report() {
  local fw_size cpu_name mem_total dmi_path
  fw_size="$(read_one "$SYS_ROOT/firmware/efi/fw_platform_size")"
  cpu_name="$(cpu_model || true)"
  [[ -n "$cpu_name" ]] || cpu_name="not available"
  mem_total="$(awk '/^MemTotal:/ {print $2 " kB"; exit}' "$PROC_ROOT/meminfo" 2>/dev/null || true)"
  [[ -n "$mem_total" ]] || mem_total="not available"
  dmi_path="$SYS_ROOT/class/dmi/id"

  cat <<REPORT
VIS OS Aurora 93 PRO X — DIGMA Citi 1804 hardware report
Generated UTC: $REPORT_TIME

[Runtime]
Kernel: $KERNEL_RELEASE
Running kernel architecture: $HOST_ARCH
Userspace word size: $LONG_BIT
CPU model from procfs: $(clean_value "$cpu_name")
CPU long-mode flag (lm): $(cpu_long_mode)
Memory reported by procfs: $mem_total

[UEFI]
REPORT
  if [[ -d "$SYS_ROOT/firmware/efi" ]]; then
    printf 'UEFI sysfs interface: present\n'
    case "$fw_size" in
      32)
        printf 'Firmware architecture: 32-bit IA32\n'
        printf 'EFI fallback path to test: /EFI/BOOT/BOOTIA32.EFI\n'
        printf '64-bit kernel note: mixed-mode boot is a separate compatibility requirement; not proven by this report.\n'
        ;;
      64)
        printf 'Firmware architecture: 64-bit x86-64\n'
        printf 'EFI fallback path to test: /EFI/BOOT/BOOTX64.EFI\n'
        ;;
      *)
        printf 'Firmware architecture: unknown (fw_platform_size unavailable or unreadable)\n'
        printf 'EFI fallback path: do not choose yet; obtain a report from a Linux Live boot.\n'
        ;;
    esac
  else
    printf 'UEFI sysfs interface: not present in this running environment\n'
    printf 'Interpretation: may be Legacy boot or an environment that does not expose EFI sysfs; this does not prove that device firmware lacks UEFI.\n'
  fi

  cat <<REPORT

[DMI — serial numbers and UUID are not collected]
System vendor: $(clean_value "$(read_one "$dmi_path/sys_vendor")")
Product name: $(clean_value "$(read_one "$dmi_path/product_name")")
Product version: $(clean_value "$(read_one "$dmi_path/product_version")")
Board name: $(clean_value "$(read_one "$dmi_path/board_name")")
BIOS vendor: $(clean_value "$(read_one "$dmi_path/bios_vendor")")
BIOS version: $(clean_value "$(read_one "$dmi_path/bios_version")")
BIOS date: $(clean_value "$(read_one "$dmi_path/bios_date")")

[eMMC / MMC block devices]
REPORT
  local found=0 block name type chip sectors size_gib
  shopt -s nullglob
  for block in "$SYS_ROOT"/block/mmcblk*; do
    [[ -d "$block" ]] || continue
    found=1
    name="$(basename "$block")"
    type="$(read_one "$block/device/type")"
    chip="$(read_one "$block/device/name")"
    sectors="$(read_one "$block/size")"
    size_gib="unknown"
    if [[ "$sectors" =~ ^[0-9]+$ ]]; then
      size_gib="$(awk -v s="$sectors" 'BEGIN {printf "%.2f GiB", s*512/1024/1024/1024}')"
    fi
    printf '%s: type=%s model=%s capacity=%s\n' "$name" "$(clean_value "$type")" "$(clean_value "$chip")" "$size_gib"
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' 'No mmcblk devices exposed in sysfs.'

  cat <<REPORT

[PCI devices — IDs and bound driver]
REPORT
  local pci vendor device class driver_path driver
  found=0
  for pci in "$SYS_ROOT"/bus/pci/devices/*; do
    [[ -d "$pci" ]] || continue
    found=1
    vendor="$(read_one "$pci/vendor")"
    device="$(read_one "$pci/device")"
    class="$(read_one "$pci/class")"
    driver_path="$(readlink "$pci/driver" 2>/dev/null || true)"
    driver="$(basename "$driver_path" 2>/dev/null || true)"
    [[ -n "$driver" ]] || driver="unbound/unknown"
    printf '%s vendor=%s device=%s class=%s driver=%s\n' "$(basename "$pci")" "$vendor" "$device" "$class" "$driver"
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' 'No PCI devices exposed in sysfs.'

  cat <<REPORT

[USB devices — product IDs only; serials omitted]
REPORT
  local usb vid pid manufacturer product
  found=0
  for usb in "$SYS_ROOT"/bus/usb/devices/*; do
    [[ -r "$usb/idVendor" && -r "$usb/idProduct" ]] || continue
    found=1
    vid="$(read_one "$usb/idVendor")"
    pid="$(read_one "$usb/idProduct")"
    manufacturer="$(read_one "$usb/manufacturer")"
    product="$(read_one "$usb/product")"
    printf '%s id=%s:%s manufacturer=%s product=%s\n' "$(basename "$usb")" "$vid" "$pid" "$(clean_value "$manufacturer")" "$(clean_value "$product")"
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' 'No USB device IDs exposed in sysfs.'

  cat <<REPORT

[Input devices — names only; touch/stylus require live testing]
REPORT
  local event input_name input_id
  found=0
  for event in "$SYS_ROOT"/class/input/event*; do
    [[ -e "$event/device/name" ]] || continue
    found=1
    input_name="$(read_one "$event/device/name")"
    input_id="$(read_one "$event/device/id/vendor"):$(read_one "$event/device/id/product")"
    printf '%s name=%s id=%s\n' "$(basename "$event")" "$(clean_value "$input_name")" "$input_id"
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' 'No event devices exposed in sysfs.'

  cat <<REPORT

[Network interfaces — MAC addresses omitted]
REPORT
  local net net_name wireless
  found=0
  for net in "$SYS_ROOT"/class/net/*; do
    [[ -e "$net" ]] || continue
    net_name="$(basename "$net")"
    [[ "$net_name" == "lo" ]] && continue
    found=1
    wireless="no"
    [[ -d "$net/wireless" ]] && wireless="yes"
    printf '%s wireless_sysfs=%s\n' "$net_name" "$wireless"
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' 'No non-loopback network interfaces exposed.'

  cat <<REPORT

[Audio]
REPORT
  if [[ -r "$PROC_ROOT/asound/cards" ]]; then
    sed -n '1,20p' "$PROC_ROOT/asound/cards"
  else
    printf '%s\n' 'ALSA card list not available.'
  fi

  cat <<REPORT

[Camera]
REPORT
  local video video_name
  found=0
  for video in "$SYS_ROOT"/class/video4linux/video*; do
    [[ -e "$video/name" ]] || continue
    found=1
    video_name="$(read_one "$video/name")"
    printf '%s name=%s\n' "$(basename "$video")" "$(clean_value "$video_name")"
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' 'No V4L2 video nodes exposed.'

  cat <<REPORT

[Battery / power supply]
REPORT
  local power power_type power_capacity
  found=0
  for power in "$SYS_ROOT"/class/power_supply/*; do
    [[ -e "$power/type" ]] || continue
    found=1
    power_type="$(read_one "$power/type")"
    power_capacity="$(read_one "$power/capacity")"
    printf '%s type=%s capacity=%s\n' "$(basename "$power")" "$power_type" "$power_capacity"
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' 'No power-supply devices exposed.'

  cat <<REPORT

[Orientation / IIO sensors]
REPORT
  local sensor sensor_name axis channel axes sample scale mount_matrix
  found=0
  for sensor in "$SYS_ROOT"/bus/iio/devices/iio:device*; do
    [[ -d "$sensor" && -e "$sensor/name" ]] || continue
    found=1
    sensor_name="$(read_one "$sensor/name")"
    axes=""
    sample=""
    for axis in x y z; do
      channel="$sensor/in_accel_"$axis"_raw"
      if [[ -r "$channel" ]]; then
        if [[ -n "$axes" ]]; then axes="$axes,"; fi
        axes="$axes$axis"
        axis_value="$(clean_value "$(read_one "$channel")")"
        if [[ -n "$sample" ]]; then sample="$sample,"; fi
        sample="$sample$axis:$axis_value"
      fi
    done
    [[ -n "$axes" ]] || axes="none"
    [[ -n "$sample" ]] || sample="not available"
    scale="$(read_one "$sensor/in_accel_scale")"
    mount_matrix="$(read_one "$sensor/in_accel_mount_matrix")"
    if [[ "$mount_matrix" == "not available" ]]; then
      mount_matrix="$(read_one "$sensor/mount_matrix")"
    fi
    printf '%s name=%s accel_axes=%s sample_raw=%s scale=%s mount_matrix=%s rotation_ready=no\n' \
      "$(basename "$sensor")" "$(clean_value "$sensor_name")" "$axes" "$sample" \
      "$(clean_value "$scale")" "$(clean_value "$mount_matrix")"
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' 'No IIO sensor devices exposed.'

  cat <<REPORT

[Display connectors / modes]
REPORT
  local connector status modes
  found=0
  for connector in "$SYS_ROOT"/class/drm/card*-*; do
    [[ -r "$connector/status" ]] || continue
    found=1
    status="$(read_one "$connector/status")"
    modes="$(awk 'NR<=4 {printf "%s%s", (NR==1?"":"; "), $0}' "$connector/modes" 2>/dev/null || true)"
    [[ -n "$modes" ]] || modes="not available"
    printf '%s status=%s modes=%s\n' "$(basename "$connector")" "$status" "$(clean_value "$modes")"
  done
  [[ "$found" -eq 1 ]] || printf '%s\n' 'No DRM connector modes exposed.'

  cat <<REPORT

[Interpretation limits]
- CPU architecture, firmware architecture and userspace architecture are separate facts.
- x86_64 CPU support does not prove that the device has x64 UEFI.
- IA32 UEFI requires an IA32 EFI application; a 64-bit kernel needs a separately validated mixed-mode path.
- Device names and IDs do not prove that a driver works.
- This report does not test touch, rotation, sleep/wake, Wi-Fi throughput, audio playback, camera capture or ISO boot.
- No partitions, EFI variables, firmware settings or firmware contents are modified.
REPORT
}

if [[ "$OUTPUT" == "-" ]]; then
  render_report
  exit 0
fi
out_dir="$(dirname "$OUTPUT")"
[[ -d "$out_dir" ]] || { echo "ERROR: output directory does not exist: $out_dir" >&2; exit 1; }
tmp_file="$(mktemp "$out_dir/.vis-hardware-report.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT
render_report > "$tmp_file"
mv -f "$tmp_file" "$OUTPUT"
trap - EXIT
printf 'Hardware report written to: %s\n' "$OUTPUT"
