# VIS OS Aurora 93 PRO X — DIGMA Citi 1804

## Состояние проекта

Это инженерный каркас бета-ветки, а не готовая ОС или загрузочный ISO. Ядро,
initramfs, драйверы, root filesystem и загрузочные пути должны собираться и
проверяться отдельно. Одобренный Desktop Stage 101/102 не заменять Stage 79
или отклонённым визуальным Stage 103.

## Основная база — Linux Mint Cinnamon

Пользовательская база Desktop/Live ISO — **Linux Mint Cinnamon 22.3**.
Сборочные инструкции ниже предназначены для Linux Mint; упоминания Debian 13
как основной базы этой ветки считать устаревшими.

Перед установкой пакетов проверьте их доступность в текущих репозиториях:

```bash
apt-cache policy xorriso grub-common grub-pc-bin grub-efi-ia32-bin grub-efi-amd64-bin mtools
```

Не устанавливайте пакеты и не начинайте сборку финального ISO, пока не проверены
доступность инструментов и архитектуры EFI-бинарников. Сам этот README не
подтверждает наличие полного Mint Live root filesystem или готового ISO.

## Целевая схема загрузки

Предполагаемая схема — отдельные пути, если они доступны и подтверждены тестами:

- UEFI IA32: `/EFI/BOOT/BOOTIA32.EFI` — 32-битная прошивка.
- UEFI x86-64: `/EFI/BOOT/BOOTX64.EFI` — 64-битная прошивка.
- Legacy BIOS: BIOS El Torito image с GRUB i386-pc.

Atom x5-Z8350 поддерживает x86-64, но это не определяет разрядность UEFI.
IA32 EFI-загрузчик не гарантирует загрузку 64-битного ядра: mixed-mode EFI и
выбранный протокол ядра должны быть отдельно собраны и проверены на устройстве.
Разрядность Windows не равна разрядности UEFI.

## Stage 105: аппаратный отчёт DIGMA

Перед выбором EFI-загрузчика и профилей драйверов соберите read-only отчёт:

```bash
bash Aurora93-PRO-X/scripts/collect_hardware_report.sh
bash Aurora93-PRO-X/tests/test_collect_hardware_report.sh
```

Скрипт не собирает serial number, UUID или MAC и не меняет eMMC/EFI.
Описание: `Aurora93-PRO-X/docs/HARDWARE_REPORT_RU.md`.

## Stage 106: проверка ISO-валидатора

```bash
bash Aurora93-PRO-X/tests/test_check_iso.sh
```

Тесты проверяют BIOS + UEFI записи и архитектуры EFI на синтетических ответах.
Они не заменяют проверку настоящего ISO.

## Stage 107/108: Boot Architecture Gate

```bash
bash Aurora93-PRO-X/tests/test_plan_boot_path.sh
bash Aurora93-PRO-X/scripts/check_build_environment.sh
bash Aurora93-PRO-X/scripts/plan_boot_path.sh VIS_OS_CITI1804_HARDWARE_REPORT.txt
```

Планировщик разрешает выбор кандидата EFI-файла только при подтверждении DMI
DIGMA Citi 1804, CPU long mode и архитектуры UEFI. При IA32 UEFI 64-битное ядро
остаётся заблокированным до аппаратной проверки mixed-mode. Неизвестная архитектура
прошивки блокирует выбор. Проверка build environment ничего не устанавливает.

Stage 108 также строго проверяет сигнатуру аппаратного отчёта и блокирует
повторяющиеся, пустые или отсутствующие используемые поля. Это проверка формата,
а не криптографическая подлинность аппаратных данных.

## Stage 109: диагностика датчика ориентации

Аппаратный отчёт Stage 105 показывает IIO accelerometer-каналы X/Y/Z, доступные
raw-значения, scale и mount matrix. Поле `rotation_ready=no` сохраняется до
физической калибровки осей и проверки ориентации DIGMA Citi 1804.

```bash
bash Aurora93-PRO-X/tests/test_collect_hardware_report.sh
bash Aurora93-PRO-X/scripts/collect_hardware_report.sh VIS_OS_CITI1804_HARDWARE_REPORT.txt
```

Описание: `Aurora93-PRO-X/docs/ORIENTATION_SENSOR_DIAGNOSTICS_RU.md`.
Автоповорот не включён и не подтверждён на устройстве.

## Stage 110: диагностика переключателя Laptop/Tablet

Новый read-only сборщик отдельно показывает capability input-событий
`SW_TABLET_MODE`/`SW_LID` и все обнаруженные прямые платформенные
`tablet_mode` sysfs-узлы:

```bash
bash Aurora93-PRO-X/scripts/collect_convertible_switch_report.sh VIS_OS_CITI1804_CONVERTIBLE_REPORT.txt
bash Aurora93-PRO-X/tests/test_convertible_switch_report.sh
```

Capability `SW_TABLET_MODE=yes` означает только то, что input-устройство
объявляет поддержку события; это не текущее состояние и не доказательство
переключения. Если несколько sysfs-узлов расходятся, автоматический выбор
режима блокируется до выяснения причины. Подробности:
`Aurora93-PRO-X/docs/CONVERTIBLE_SWITCH_DIAGNOSTICS_RU.md`.

## Stage 111: чтение текущего состояния EV_SW

Stage 110 показывает capability `SW_LID`/`SW_TABLET_MODE`, но capability не является текущим состоянием. Новый read-only probe запрашивает `EVIOCGSW` у соответствующих `/dev/input/eventX` и отдельно показывает `unknown`, `incomplete` и `conflict`.

```bash
python3 Aurora93-PRO-X/tests/test_probe_convertible_switch_state.py
python3 Aurora93-PRO-X/scripts/probe_convertible_switch_state.py
```

Если нет прав на чтение input event nodes, запустите только диагностический probe через `sudo`. Согласованный результат всё равно не включает автоматический режим UI: сначала требуется физическая проверка складывания/раскладывания DIGMA Citi 1804.

Описание и ограничения: `docs/CURRENT_SWITCH_STATE_DIAGNOSTICS_RU.md`.
## Stage 112: целостность инвентаризации switch-capability

Проверка Stage 111 теперь не скрывает event-узлы с повреждённым или недоступным
capabilities/sw: отчёт помечает инвентаризацию как incomplete и перечисляет
причины. Чистый нулевой bitmap остаётся корректным результатом без switch-событий.

    python3 -m py_compile Aurora93-PRO-X/scripts/probe_convertible_switch_state.py Aurora93-PRO-X/tests/test_probe_convertible_switch_state.py
    python3 Aurora93-PRO-X/tests/test_probe_convertible_switch_state.py
    python3 Aurora93-PRO-X/scripts/probe_convertible_switch_state.py

Описание: Aurora93-PRO-X/docs/SWITCH_INVENTORY_VALIDATION_RU.md.
Это только диагностика; Auto и режимы рабочего стола не меняются.

## Stage 113: надёжность перечисления sysfs input

Проверка Stage 112 использовала `Path.glob()` для поиска `/sys/class/input/event*`.
Если корень `/sys/class/input` отсутствовал или не читался, пустой результат
мог быть ошибочно принят за полную инвентаризацию без switch-устройств. Теперь
сборщик использует `os.scandir()` и помечает недоступный корень, ошибки
перечисления и некорректные event-узлы как `incomplete`.

```bash
python3 -m py_compile Aurora93-PRO-X/scripts/probe_convertible_switch_state.py Aurora93-PRO-X/tests/test_probe_convertible_switch_state.py
python3 Aurora93-PRO-X/tests/test_probe_convertible_switch_state.py
python3 Aurora93-PRO-X/scripts/probe_convertible_switch_state.py
```

Проверки используют временное sysfs-дерево и искусственную ошибку доступа;
они не подтверждают наличие hinge-сенсора на DIGMA Citi 1804.

## Проверка UEFI на DIGMA из Linux Live

```bash
cat /sys/firmware/efi/fw_platform_size
```

Ожидается `32` для IA32 UEFI или `64` для x86-64 UEFI. Если файла нет,
система могла быть загружена в Legacy-режиме; это не доказывает отсутствие UEFI
в прошивке.

## Диагностика оборудования

См. `docs/HARDWARE_CHECKLIST_RU.md`. Не форматируйте eMMC и не меняйте прошивку
ради диагностики. Начинайте с Live USB и резервной копии важных данных.

## Ветка

Рабочая бета-ветка: `beta/aurora-93-pro-x`.

## Ограничения

- Физический DIGMA Citi 1804 пока не подтверждён тестами этого каркаса.
- IA32/x64 UEFI конкретного экземпляра не определены без его аппаратного отчёта.
- Mixed-mode IA32 EFI + 64-bit kernel не считается реализованным до сборки и теста.
- Сенсор, hinge/tablet switch, автоповорот, клавиатура, тачпад, сон, Wi-Fi, аудио
  и камера не объявляются рабочими без соответствующих испытаний.
- Stage 101/102 Desktop должен быть восстановлен из оригинального исходника до
  интеграции; архив Stage 86 содержит Stage 79 HTML и не заменяет Stage 102.
- Экспериментальные собственные ядро/загрузчик VIS OS остаются отдельной веткой.
- Live ISO и установка на eMMC не подтверждены.

## Stage 114: запись переходов Laptop/Tablet

Новый read-only монитор повторяет существующий `EVIOCGSW` probe и записывает
первый снимок и только изменившиеся отчёты. Он не читает очередь `input_event`,
не меняет sysfs и не переключает режим интерфейса.

```bash
sudo python3 Aurora93-PRO-X/scripts/monitor_convertible_switch.py \
  --interval 0.5 --duration 180 \
  | tee VIS_OS_CITI1804_SWITCH_TRACE.txt
python3 Aurora93-PRO-X/tests/test_monitor_convertible_switch.py
```

После записи медленно переведите DIGMA из положения ноутбука в положение
планшета и обратно. Отправьте трассу для сопоставления с физическим движением.
`unknown`, `incomplete` или `conflict` не разрешают автоматический режим.
Подробности: `docs/SWITCH_TRANSITION_CAPTURE_RU.md`.

Это диагностический этап: Stage 101/102 UI и приложения не изменялись;
автоматическое переключение, ISO и работа на физическом DIGMA не подтверждены.


## Stage 115: мониторинг platform tablet_mode

Stage 114 записывал только `EVIOCGSW`. Теперь монитор также читает прямые
read-only sysfs-атрибуты `tablet_mode` в `/sys/devices/platform/*` и
`/sys/bus/platform/devices/*`. Повторяющиеся bus symlink удаляются, ссылки за
пределы `--sys-root` отклоняются, неизвестные значения и ошибки маркируются как
incomplete. Автоматический режим по-прежнему не включается.

```bash
python3 -m py_compile Aurora93-PRO-X/scripts/probe_platform_tablet_mode.py Aurora93-PRO-X/scripts/monitor_convertible_switch.py Aurora93-PRO-X/tests/test_probe_platform_tablet_mode.py Aurora93-PRO-X/tests/test_monitor_convertible_switch.py
python3 Aurora93-PRO-X/tests/test_probe_platform_tablet_mode.py
python3 Aurora93-PRO-X/tests/test_monitor_convertible_switch.py
python3 Aurora93-PRO-X/scripts/probe_platform_tablet_mode.py
```

Описание и инструкция физического захвата: `docs/SWITCH_TRANSITION_CAPTURE_RU.md`.
