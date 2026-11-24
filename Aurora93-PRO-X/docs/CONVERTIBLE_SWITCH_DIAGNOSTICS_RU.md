# Stage 110 — диагностика переключателя Laptop/Tablet

## Цель

Отдельно инвентаризировать два разных механизма Linux:

1. Возможность input-устройства отправлять `EV_SW / SW_TABLET_MODE`.
2. Текущие значения доступных `tablet_mode` sysfs-атрибутов платформенных устройств.

Эти признаки нельзя смешивать. Бит `SW_TABLET_MODE` в `capabilities/sw` сообщает только о заявленной возможности устройства отправлять событие; текущего состояния он не содержит. Состояние события требует работающего input event listener. Значение `tablet_mode` sysfs `0/1` выводится отдельно как кандидат состояния.

## Запуск на DIGMA из Linux Live

```bash
bash Aurora93-PRO-X/scripts/collect_convertible_switch_report.sh VIS_OS_CITI1804_CONVERTIBLE_REPORT.txt
```

Вывод в терминал:

```bash
bash Aurora93-PRO-X/scripts/collect_convertible_switch_report.sh -
```

Скрипт только читает sysfs и создаёт текстовый отчёт. Он не меняет режим, не пишет в sysfs, не затрагивает EFI/eMMC и не собирает serial/MAC.

## Интерпретация

- `SW_TABLET_MODE=yes`: input-устройство объявляет поддержку switch event `0x01`; это не доказывает, что событие реально поступает.
- `SW_LID=yes`: объявлена поддержка события крышки `0x00`; это также не доказывает фактическое переключение.
- `tablet_mode value=0`: кандидат Laptop.
- `tablet_mode value=1`: кандидат Tablet.
- Если sysfs-узлы дают разные значения, автоматический выбор блокируется до выяснения причины.
- Если доступен только `SW_TABLET_MODE`, Stage 86 Auto должен оставаться на responsive/manual fallback; capability bit нельзя считать активным состоянием.

## Связь с прежней архитектурой

Stage 86 уже содержит политику Auto/Laptop/Tablet и читает `tablet_mode` sysfs. Stage 110 — самостоятельная read-only диагностика для DIGMA и не подменяет Desktop Stage 101/102. Архив Stage 86 содержит Stage 79 HTML baseline, поэтому его нельзя автоматически объявлять источником одобренного Stage 102.

## Проверки

`bash Aurora93-PRO-X/tests/test_convertible_switch_report.sh` использует синтетический sysfs: проверяет бит SW_TABLET_MODE, SW_LID, отсутствующие/повреждённые маски, два конфликтующих sysfs-узла, безопасный файловый вывод и отсутствие записи в fixture.

Это не тест физического устройства. Реальные input events, hinge switch, переход Laptop/Tablet и автоповорот требуют отдельной проверки на DIGMA Citi 1804.
