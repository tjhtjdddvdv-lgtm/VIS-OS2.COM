# DIGMA Citi 1804 — аппаратный отчёт VIS OS

Запуск из корня репозитория:

~~~bash
bash Aurora93-PRO-X/scripts/collect_hardware_report.sh
~~~

Для вывода в терминал:

~~~bash
bash Aurora93-PRO-X/scripts/collect_hardware_report.sh -
~~~

Скрипт только читает sysfs/procfs, не требует root и не меняет eMMC, EFI variables или настройки прошивки. Он не собирает serial number, UUID и MAC-адреса.

## Как читать UEFI

- /sys/firmware/efi/fw_platform_size = 32: текущий Linux Live загружен через IA32 UEFI; проверяемый fallback — /EFI/BOOT/BOOTIA32.EFI.
- Значение 64: текущий Linux Live загружен через x86-64 UEFI; проверяемый fallback — /EFI/BOOT/BOOTX64.EFI.
- Если файл отсутствует, архитектура прошивки остаётся неизвестной. Отсутствие каталога EFI может означать Legacy-загрузку или ограничение окружения и не доказывает, что UEFI в устройстве нет.

CPU x86_64, userspace и UEFI — разные параметры. Поддержка Intel 64 у Atom x5-Z8350 не доказывает наличие x64 UEFI. При IA32 UEFI загрузка 64-битного ядра требует отдельной проверки mixed-mode пути.

## Состав отчёта

DMI без serial/UUID, CPU, RAM, UEFI bitness, MMC/eMMC, PCI/USB IDs, input names, сеть без MAC, ALSA, камера, батарея, IIO sensors и DRM display modes.

Имена и IDs устройств — только инвентаризация, не подтверждение работы драйверов. Отчёт не проверяет сенсор, поворот, сон/пробуждение, Wi-Fi-трафик, звук, камеру или загрузку ISO.

## Тесты

~~~bash
bash Aurora93-PRO-X/tests/test_collect_hardware_report.sh
~~~

Тесты используют синтетические sysfs/procfs fixtures и не заменяют запуск на физическом DIGMA Citi 1804.
