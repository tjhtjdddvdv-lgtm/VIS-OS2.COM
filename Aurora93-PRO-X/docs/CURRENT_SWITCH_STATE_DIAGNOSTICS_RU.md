# Stage 111 — чтение текущего состояния EV_SW

## Зачем нужен этот этап

Stage 110 показывал только capability-биты `SW_LID` и `SW_TABLET_MODE`. Они
говорят, какие события устройство *может* отправлять, но не сообщают текущее
положение переключателя. Stage 111 добавляет read-only запрос Linux input ioctl
`EVIOCGSW` к каждому `/dev/input/eventX`, который объявляет один из этих кодов.

## Запуск на DIGMA из Linux Live

```bash
python3 Aurora93-PRO-X/scripts/probe_convertible_switch_state.py
```

Если обычному пользователю запрещено читать `/dev/input/event*`, повторите только
эту диагностическую команду с правами root:

```bash
sudo python3 Aurora93-PRO-X/scripts/probe_convertible_switch_state.py
```

Для тестирования альтернативного sysfs/dev дерева:

```bash
python3 Aurora93-PRO-X/scripts/probe_convertible_switch_state.py \\
  --sys-root /путь/к/sys --dev-root /путь/к/dev/input
```

## Значения

- `SW_TABLET_MODE=tablet(1)` — input-устройство сообщает текущее состояние Tablet.
- `SW_TABLET_MODE=laptop(0)` — текущее состояние Laptop.
- `SW_LID=closed(1)` / `open(0)` — состояние switch крышки.
- `unknown(PermissionError)` — нет доступа к event node; это не состояние Laptop.
- `aggregate=conflict` — разные устройства сообщают разные режимы.
- `aggregate=incomplete` — хотя бы одно устройство с нужной capability не удалось опросить.

Скрипт не подписывается на поток событий, не меняет состояние, не записывает в
sysfs, не трогает EFI/eMMC и не включает автоматическое переключение UI. Даже
согласованный ioctl-ответ — диагностическое свидетельство; перед включением
режима Auto нужно проверить физическое складывание/раскладывание DIGMA и
соответствие сигналов реальному положению клавиатуры.

## Тестирование

```bash
python3 Aurora93-PRO-X/tests/test_probe_convertible_switch_state.py
```

Тесты используют mock ioctl и временное sysfs-дерево. Они проверяют формат
EVIOCGSW, декодирование битов, отсутствие прав, конфликт нескольких датчиков
и запрет на опрос устройств без switch capability. Они не заменяют испытание
на физическом DIGMA Citi 1804.
