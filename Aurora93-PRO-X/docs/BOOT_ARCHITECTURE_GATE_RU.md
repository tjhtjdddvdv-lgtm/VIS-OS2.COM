# Stage 107 — архитектурный шлюз загрузки DIGMA Citi 1804

Stage 107 добавляет fail-closed планировщик загрузочного пути. Он читает отчёт Stage 105
и не позволяет выбирать EFI-файл, если отчёт не идентифицирует DIGMA Citi 1804,
не подтверждает CPU long mode или не сообщает архитектуру UEFI.

## Запуск

```bash
bash Aurora93-PRO-X/tests/test_plan_boot_path.sh
bash Aurora93-PRO-X/scripts/check_build_environment.sh
bash Aurora93-PRO-X/scripts/plan_boot_path.sh VIS_OS_CITI1804_HARDWARE_REPORT.txt
```

## Правила выбора

- IA32 UEFI + подтверждённый CPU long mode: кандидат EFI `/EFI/BOOT/BOOTIA32.EFI`.
  Выбор 64-битного ядра блокируется до отдельной проверки mixed-mode загрузки.
- x86-64 UEFI + подтверждённый CPU long mode: кандидат EFI `/EFI/BOOT/BOOTX64.EFI`;
  x86_64 ядро остаётся кандидатом, а не подтверждённой сборкой.
- Неизвестная UEFI архитектура, отсутствие UEFI sysfs, неизвестный CPU long mode,
  несовпадение DMI или отсутствующий отчёт: STOP.
- Отсутствие `/sys/firmware/efi` не доказывает отсутствие UEFI: Linux мог быть загружен
  в Legacy-режиме.

## Ограничения

Планировщик не собирает ядро, initramfs, root filesystem или ISO. Он не меняет eMMC,
EFI variables, boot entries или firmware. BIOS-путь этим отчётом не определяется.
Тесты используют синтетические отчёты и не заменяют проверку на физическом DIGMA.
