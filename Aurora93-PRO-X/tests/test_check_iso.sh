#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
checker="$script_dir/../scripts/check_iso.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mockbin="$tmp/mockbin"
mkdir -p "$mockbin"
: > "$tmp/test.iso"

cat > "$mockbin/xorriso" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
  if [[ "$arg" == "-report_el_torito" ]]; then
    printf '%s\n' "${MOCK_ELTORITO_REPORT:-}"
    exit 0
  fi
done
for arg in "$@"; do
  if [[ "$arg" == "-extract" ]]; then
    destination="${@: -1}"
    filename="${destination##*/}"
    if [[ "${MOCK_MISSING_FILE:-}" == "$filename" ]]; then
      exit 1
    fi
    printf 'mock EFI payload: %s\n' "$filename" > "$destination"
    exit 0
  fi
done
exit 64
MOCK

cat > "$mockbin/objdump" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
filename="${@: -1}"
case "${MOCK_WRONG_ARCH:-}:$filename" in
  BOOTIA32.EFI:*) format="pei-x86-64" ;;
  BOOTX64.EFI:*) format="pei-i386" ;;
  *:*)
    case "$filename" in
      */BOOTIA32.EFI) format="pei-i386" ;;
      */BOOTX64.EFI) format="pei-x86-64" ;;
      *) exit 1 ;;
    esac
    ;;
esac
printf 'file format %s\n' "$format"
MOCK

cat > "$mockbin/file" <<'MOCK'
#!/usr/bin/env bash
printf 'mock file: %s\n' "${@: -1}"
MOCK
chmod +x "$mockbin/xorriso" "$mockbin/objdump" "$mockbin/file"

valid_report=$'El Torito images   :   N  Pltf  B  Emul  Ld_seg  Hdpt  Ldsiz  LBA\nEl Torito boot img :   1  BIOS  y  none  0x0000  0x00  4  54\nEl Torito boot img :   2  UEFI  y  none  0x0000  0x00  8  55'

run_checker() {
  env PATH="$mockbin:$PATH" \
    MOCK_ELTORITO_REPORT="${MOCK_ELTORITO_REPORT:-}" \
    MOCK_WRONG_ARCH="${MOCK_WRONG_ARCH:-}" \
    MOCK_MISSING_FILE="${MOCK_MISSING_FILE:-}" \
    bash "$checker" "$tmp/test.iso"
}

MOCK_ELTORITO_REPORT="$valid_report" run_checker > "$tmp/valid.log"
grep -q '^PASS:' "$tmp/valid.log"
printf '[PASS] valid BIOS + UEFI catalog and both EFI architectures\n'

if MOCK_ELTORITO_REPORT=$'El Torito boot img : 1  UEFI  y  none  0x0000  0x00  8  55' run_checker > "$tmp/no-bios.log" 2>&1; then
  echo '[FAIL] missing BIOS entry was accepted' >&2
  exit 1
fi
grep -q 'Legacy BIOS El Torito entry' "$tmp/no-bios.log"
printf '[PASS] missing BIOS entry is rejected\n'

if MOCK_ELTORITO_REPORT=$'El Torito boot img : 1  BIOS  y  none  0x0000  0x00  4  54' run_checker > "$tmp/no-uefi.log" 2>&1; then
  echo '[FAIL] missing UEFI entry was accepted' >&2
  exit 1
fi
grep -q 'UEFI El Torito entry' "$tmp/no-uefi.log"
printf '[PASS] missing UEFI entry is rejected\n'

if MOCK_ELTORITO_REPORT="$valid_report" MOCK_WRONG_ARCH=BOOTIA32.EFI run_checker > "$tmp/wrong-arch.log" 2>&1; then
  echo '[FAIL] wrong IA32 executable architecture was accepted' >&2
  exit 1
fi
grep -q "BOOTIA32.EFI has format 'pei-x86-64'" "$tmp/wrong-arch.log"
printf '[PASS] wrong EFI executable architecture is rejected\n'

if MOCK_ELTORITO_REPORT="$valid_report" MOCK_MISSING_FILE=BOOTX64.EFI run_checker > "$tmp/missing-efi.log" 2>&1; then
  echo '[FAIL] missing BOOTX64.EFI was accepted' >&2
  exit 1
fi
grep -q 'missing or unreadable /EFI/BOOT/BOOTX64.EFI' "$tmp/missing-efi.log"
printf '[PASS] missing EFI fallback file is rejected\n'

printf '%s\n' 'PASS: all check_iso.sh regression tests passed.'
