# Stage 112 — целостность инвентаризации switch-capability

## Проблема

Stage 111 опрашивал EVIOCGSW у устройств с известными SW_LID или SW_TABLET_MODE,
но пропускал event-узлы, если capabilities/sw был недоступен или содержал
повреждённую маску. В таком случае отчёт мог выглядеть так, будто ни одно
устройство не объявляет switch-события.

## Изменение

Теперь сборщик:
- отдельно перечисляет event-узлы с недоступной capability-маской;
- отмечает повреждённую или пустую маску как malformed;
- выводит общий статус Switch capability inventory: complete/incomplete;
- сообщает об отсутствии switch-устройств только после чистой инвентаризации;
- проверяет размер ioctl для 32- и 64-битного userspace ABI в тестах.

Нулевой валидный bitmap (00000000) означает, что event-устройство не объявляет
switch capabilities. Ошибка чтения или некорректный bitmap не считается
отсутствием датчика.

## Проверка

    python3 -m py_compile Aurora93-PRO-X/scripts/probe_convertible_switch_state.py Aurora93-PRO-X/tests/test_probe_convertible_switch_state.py
    python3 Aurora93-PRO-X/tests/test_probe_convertible_switch_state.py

Тесты используют временное sysfs-дерево и mock ioctl. Они проверяют конфликт
состояний, недоступность event node, malformed/unreadable capability files,
чистый нулевой bitmap и размеры ioctl 4/8 байт.

## Ограничения

Этап не меняет поведение UI и не включает Auto. Физический DIGMA Citi 1804,
реальные hinge-события, автоповорот, драйверы и загрузка ISO не проверялись.
