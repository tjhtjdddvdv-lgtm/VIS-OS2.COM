#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
collector="$script_dir/../scripts/collect_hardware_report.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
sys="$tmp/sys"
proc="$tmp/proc"
mkdir -p "$sys/firmware/efi" "$sys/class/dmi/id" "$sys/block/mmcblk0/device" \
  "$sys/bus/pci/devices/0000:00:02.0" "$sys/bus/usb/devices/1-1" \
  "$sys/class/input/event2/device/id" "$sys/class/net/wlan0/wireless" \
  "$sys/class/video4linux/video0" "$sys/class/power_supply/BAT0" \
  "$sys/bus/iio/devices/iio:device0" "$sys/class/drm/card0-HDMI-A-1" "$proc/asound"
printf '32\n' > "$sys/firmware/efi/fw_platform_size"
printf 'DIGMA\n' > "$sys/class/dmi/id/sys_vendor"
printf 'CITI 1804\n' > "$sys/class/dmi/id/product_name"
printf 'DO-NOT-PRINT-SERIAL\n' > "$sys/class/dmi/id/board_serial"
printf 'MMC\n' > "$sys/block/mmcblk0/device/type"
printf 'HBG4\n' > "$sys/block/mmcblk0/device/name"
printf '62500000\n' > "$sys/block/mmcblk0/size"
printf '0x8086\n' > "$sys/bus/pci/devices/0000:00:02.0/vendor"
printf '0x22b1\n' > "$sys/bus/pci/devices/0000:00:02.0/device"
printf '0x030000\n' > "$sys/bus/pci/devices/0000:00:02.0/class"
printf '0x1234\n' > "$sys/bus/usb/devices/1-1/idVendor"
printf '0xabcd\n' > "$sys/bus/usb/devices/1-1/idProduct"
printf 'Goodix Capacitive Touchscreen\n' > "$sys/class/input/event2/device/name"
printf '0x27c6\n' > "$sys/class/input/event2/device/id/vendor"
printf '0x0113\n' > "$sys/class/input/event2/device/id/product"
printf 'de:ad:be:ef:00:01\n' > "$sys/class/net/wlan0/address"
printf 'HDA Intel PCH\n' > "$proc/asound/cards"
printf 'Integrated Camera\n' > "$sys/class/video4linux/video0/name"
printf 'Battery\n' > "$sys/class/power_supply/BAT0/type"
printf '83\n' > "$sys/class/power_supply/BAT0/capacity"
printf 'bmi160\n' > "$sys/bus/iio/devices/iio:device0/name"
printf '%s\n' '-12' > "$sys/bus/iio/devices/iio:device0/in_accel_x_raw"
printf '%s\n' '34' > "$sys/bus/iio/devices/iio:device0/in_accel_y_raw"
printf '%s\n' '1001' > "$sys/bus/iio/devices/iio:device0/in_accel_z_raw"
printf '%s\n' '0.009806' > "$sys/bus/iio/devices/iio:device0/in_accel_scale"
printf '%s\n' '1,0,0;0,1,0;0,0,1' > "$sys/bus/iio/devices/iio:device0/mount_matrix"
mkdir -p "$sys/bus/iio/devices/iio:device1"
printf '%s\n' 'partial-accelerometer' > "$sys/bus/iio/devices/iio:device1/name"
printf '%s\n' '7' > "$sys/bus/iio/devices/iio:device1/in_accel_x_raw"
printf 'connected\n' > "$sys/class/drm/card0-HDMI-A-1/status"
printf '1920x1200\n1280x800\n' > "$sys/class/drm/card0-HDMI-A-1/modes"
cat > "$proc/cpuinfo" <<'CPU'
processor : 0
model name : Intel(R) Atom(TM) x5-Z8350 CPU @ 1.44GHz
flags : fpu sse sse2 lm
CPU
printf 'MemTotal:        2048000 kB\n' > "$proc/meminfo"

run_report() {
  VIS_SYS_ROOT="$sys" VIS_PROC_ROOT="$proc" VIS_REPORT_TIME="2026-11-22T00:00:00Z" \
  VIS_UNAME_M="x86_64" VIS_UNAME_R="test-kernel" VIS_LONG_BIT="64" \
  bash "$collector" -
}
bash -n "$collector"
report="$(run_report)"
grep -q 'Firmware architecture: 32-bit IA32' <<<"$report"
grep -q 'BOOTIA32.EFI' <<<"$report"
grep -q 'mixed-mode boot is a separate compatibility requirement' <<<"$report"
grep -q 'CPU long-mode flag (lm): yes' <<<"$report"
grep -q 'CITI 1804' <<<"$report"
grep -q 'mmcblk0: type=MMC' <<<"$report"
grep -q '0000:00:02.0 vendor=0x8086 device=0x22b1' <<<"$report"
grep -q 'Goodix Capacitive Touchscreen' <<<"$report"
grep -q 'wlan0 wireless_sysfs=yes' <<<"$report"
grep -q 'Integrated Camera' <<<"$report"
grep -q 'bmi160' <<<"$report"
grep -q 'accel_axes=x,y,z sample_raw=x:-12,y:34,z:1001 scale=0.009806' <<<"$report"
grep -q 'mount_matrix=1,0,0;0,1,0;0,0,1 rotation_ready=no' <<<"$report"
grep -q 'partial-accelerometer accel_axes=x sample_raw=x:7' <<<"$report"
grep -q '1920x1200' <<<"$report"
if grep -q 'DO-NOT-PRINT-SERIAL\|de:ad:be:ef:00:01' <<<"$report"; then
  echo '[FAIL] serial or MAC value leaked into report' >&2
  exit 1
fi
printf '[PASS] IA32 UEFI and x86_64 CPU are reported separately\n'
printf '[PASS] DMI/MMC/PCI/USB/input/network/audio/camera/battery/IIO/DRM inventory\n'
printf '[PASS] serial number and MAC values are omitted\n'

printf '64\n' > "$sys/firmware/efi/fw_platform_size"
report64="$(run_report)"
grep -q 'Firmware architecture: 64-bit x86-64' <<<"$report64"
grep -q 'BOOTX64.EFI' <<<"$report64"
printf '[PASS] x64 UEFI fallback path\n'

rm -f "$sys/firmware/efi/fw_platform_size"
report_unknown="$(run_report)"
grep -q 'Firmware architecture: unknown' <<<"$report_unknown"
grep -q 'do not choose yet' <<<"$report_unknown"
printf '[PASS] unknown firmware bitness stays unknown\n'

rm -rf "$sys/firmware/efi"
report_legacy="$(run_report)"
grep -q 'UEFI sysfs interface: not present' <<<"$report_legacy"
grep -q 'does not prove that device firmware lacks UEFI' <<<"$report_legacy"
printf '[PASS] absent EFI sysfs is not treated as proof of Legacy-only firmware\n'

out="$tmp/report.txt"
VIS_SYS_ROOT="$sys" VIS_PROC_ROOT="$proc" bash "$collector" "$out" >/dev/null
test -s "$out"
printf '[PASS] report file output\n'
printf '%s\n' 'PASS: all hardware report regression tests passed.'
