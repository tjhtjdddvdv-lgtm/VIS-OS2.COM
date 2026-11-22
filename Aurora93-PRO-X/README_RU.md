# VIS OS Aurora 93 PRO X — DIGMA Citi 1804

## Stage 104: MULTI-UEFI boot foundation

Это исходный инженерный каркас бета-ветки, а не готовая ОС или загрузочный ISO.
Здесь фиксируется схема загрузки и проверочные процедуры. Ядро, initramfs,
драйверы и root filesystem должны быть собраны и проверены отдельно.

### Цель

Один ISO с несколькими независимыми загрузочными путями:

- UEFI IA32: `/EFI/BOOT/BOOTIA32.EFI` — 32-битная прошивка.
- UEFI x86-64: `/EFI/BOOT/BOOTX64.EFI` — 64-битная прошивка.
- Legacy BIOS: BIOS El Torito image с GRUB i386-pc.

Atom x5-Z8350 поддерживает x86-64, но 32-битный UEFI требует отдельного
IA32 EFI-загрузчика. Сам факт наличия IA32 GRUB не гарантирует, что 64-битное
ядро загрузится: mixed-mode EFI и выбранный протокол ядра нужно проверить
на конкретной прошивке. Разрядность Windows не равна разрядности UEFI.

### Установка зависимостей (Debian 13)

Пакеты и доступность IA32 GRUB зависят от репозиториев и архитектуры сборочной
машины. Сначала проверьте наличие пакетов через apt-cache:

```bash
sudo apt update
apt-cache policy xorriso grub-common grub-pc-bin grub-efi-ia32-bin grub-efi-amd64-bin mtools
```

Не начинайте сборку финального ISO, пока не подтверждены доступные EFI-бинарники.

### Stage 105: аппаратный отчёт DIGMA

Перед выбором EFI-загрузчика и профилей драйверов соберите read-only отчёт:

~~~bash
bash Aurora93-PRO-X/scripts/collect_hardware_report.sh
bash Aurora93-PRO-X/tests/test_collect_hardware_report.sh
~~~

Скрипт не собирает serial number, UUID или MAC и не меняет eMMC/EFI.
Описание: Aurora93-PRO-X/docs/HARDWARE_REPORT_RU.md.

### Stage 106: проверка самого ISO-валидатора

Перед проверкой собранного образа запустите регрессионные тесты:

```bash
bash Aurora93-PRO-X/tests/test_check_iso.sh
```

Они проверяют, что валидатор принимает BIOS + UEFI записи и две правильные
архитектуры EFI, а также отклоняет отсутствующую запись, отсутствующий файл
и EFI-бинарник неверной архитектуры.

После этого проверяйте реальный образ:

```bash
bash Aurora93-PRO-X/scripts/check_iso.sh /путь/к/образу.iso
```

Тесты используют имитацию xorriso/objdump и не заменяют проверку настоящего ISO.
Для проверки образа нужны установленный xorriso и реально собранный файл ISO.

### Проверка UEFI на DIGMA из Linux Live

```bash
cat /sys/firmware/efi/fw_platform_size
```

Ожидается `32` для IA32 UEFI или `64` для x86-64 UEFI. Если файла нет,
система могла быть загружена в Legacy-режиме.

### Диагностика оборудования

См. `docs/HARDWARE_CHECKLIST_RU.md`. Не форматируйте eMMC и не прошивайте
UEFI на этом этапе. Начинайте с Live USB и резервной копии важных данных.

### Ветка

Рабочая бета-ветка: `beta/aurora-93-pro-x`.
