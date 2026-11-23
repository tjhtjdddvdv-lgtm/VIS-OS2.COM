#!/usr/bin/env bash
# VIS OS Aurora 93 — configure a clean graphical boot on Linux Mint.
# Makes a timestamped backup and changes only /etc/default/grub.
# Does not install a kernel, bootloader, desktop shell, or modify EFI entries.
set -euo pipefail

GRUB_DEFAULTS="/etc/default/grub"
[[ "${EUID}" -eq 0 ]] || { echo "Запустите скрипт через sudo." >&2; exit 1; }
[[ -f "$GRUB_DEFAULTS" ]] || { echo "Не найден $GRUB_DEFAULTS. Нужна система на базе Linux Mint/Ubuntu." >&2; exit 2; }
command -v update-grub >/dev/null 2>&1 || { echo "Не найдена команда update-grub; изменения не внесены." >&2; exit 2; }

if ! grep -qiE 'Linux Mint|Ubuntu' /etc/os-release; then
  echo "Предупреждение: дистрибутив не распознан как Linux Mint/Ubuntu."
  read -r -p "Продолжить? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

stamp="$(date +%Y%m%d-%H%M%S)"
backup="${GRUB_DEFAULTS}.visos-backup-${stamp}"
cp -a "$GRUB_DEFAULTS" "$backup"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

python3 - "$GRUB_DEFAULTS" "$tmp" <<'PY'
import re, sys
src, dst = sys.argv[1:]
with open(src, encoding="utf-8") as f:
    lines = f.readlines()

settings = {
    "GRUB_TIMEOUT_STYLE": "hidden",
    "GRUB_TIMEOUT": "2",
    "GRUB_CMDLINE_LINUX_DEFAULT": '"quiet splash loglevel=3 systemd.show_status=false rd.udev.log_level=3 vt.global_cursor_default=0"',
}
seen = set()
out = []
for line in lines:
    match = re.match(r'^\s*(GRUB_TIMEOUT_STYLE|GRUB_TIMEOUT|GRUB_CMDLINE_LINUX_DEFAULT)=', line)
    if match:
        key = match.group(1)
        if key not in seen:
            out.append(f"{key}={settings[key]}\n")
            seen.add(key)
        continue
    out.append(line)
for key, value in settings.items():
    if key not in seen:
        out.append(f"{key}={value}\n")
with open(dst, "w", encoding="utf-8") as f:
    f.writelines(out)
PY

install -m 0644 "$tmp" "$GRUB_DEFAULTS"
if update-grub; then
  echo "Готово: включён тихий графический запуск VIS OS."
  echo "Резервная копия: $backup"
  echo "Меню GRUB можно вызвать клавишей Esc (UEFI) или удержанием Shift (BIOS)."
  echo "Если заставка Plymouth не появилась, проверьте пакет plymouth и тему Mint."
else
  cp -a "$backup" "$GRUB_DEFAULTS"
  update-grub || true
  echo "Ошибка обновления GRUB. Исходный файл восстановлен из резервной копии." >&2
  exit 3
fi
