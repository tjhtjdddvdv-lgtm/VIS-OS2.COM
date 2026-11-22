# DIGMA Citi 1804 — аппаратная проверка

## Известно
- CPU: Intel Atom x5-Z8350; процессор поддерживает x86-64.
- Пользователь сообщил «32 бит»; требуется уточнить, относится ли это к UEFI
  или к установленной Windows. Для выбора EFI-файла важна именно прошивка.

## Проверить из Linux Live
- [ ] UEFI: `cat /sys/firmware/efi/fw_platform_size` (32 или 64).
- [ ] CPU и режим: `lscpu`.
- [ ] eMMC и контроллер: `lsblk -o NAME,SIZE,MODEL,TRAN`, `dmesg | grep -i mmc`.
- [ ] PCI: `lspci -nnk`.
- [ ] USB: `lsusb`.
- [ ] Сенсор и устройства ввода: `cat /proc/bus/input/devices`.
- [ ] Ошибки устройств: `dmesg -T | grep -Ei 'touch|i2c|hid|acpi|mmc|wifi|bluetooth|audio'`.
- [ ] Wi-Fi, Bluetooth, звук, камера.
- [ ] Автоповорот и датчик ориентации.
- [ ] Сон, пробуждение, зарядка и батарея.

Не форматируйте внутреннюю eMMC и не меняйте прошивку ради диагностики.
