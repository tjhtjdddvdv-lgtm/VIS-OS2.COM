#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/monitor_convertible_switch.py"
SPEC = importlib.util.spec_from_file_location("vis_switch_monitor", SCRIPT)
monitor = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(monitor)


class FakeClock:
    def __init__(self):
        self.value = 0.0

    def __call__(self):
        return self.value

    def sleep(self, seconds):
        self.value += seconds


class SwitchMonitorTests(unittest.TestCase):
    def test_emits_initial_and_changed_snapshots_only(self):
        clock = FakeClock()
        reports = iter(["state A", "state A", "state B", "state B"])
        output = []
        count = monitor.run_monitor(
            lambda: next(reports), interval=0.5, duration=1.5,
            clock=clock, sleep=clock.sleep,
            timestamp_fn=lambda: "2026-11-27T18:00:00+01:00", emit=output.append,
        )
        self.assertEqual(count, 3)
        self.assertEqual(sum(line == "state A" for line in output), 1)
        self.assertEqual(sum(line == "state B" for line in output), 1)
        self.assertEqual(sum(line.startswith("[") for line in output), 2)

    def test_device_line_change_is_reported_even_if_aggregate_stays_unknown(self):
        clock = FakeClock()
        reports = iter([
            "SW_TABLET_MODE aggregate: unknown/incomplete\nevent2 SW_TABLET_MODE=unknown(PermissionError)",
            "SW_TABLET_MODE aggregate: unknown/incomplete\nevent2 SW_TABLET_MODE=tablet(1)",
        ])
        output = []
        count = monitor.run_monitor(
            lambda: next(reports), interval=0.5, duration=0.6,
            clock=clock, sleep=clock.sleep,
            timestamp_fn=lambda: "timestamp", emit=output.append,
        )
        self.assertEqual(count, 2)
        self.assertEqual(sum(line.startswith("[timestamp]") for line in output), 2)

    def test_collect_snapshot_includes_both_input_and_platform_sources(self):
        snapshot = monitor.collect_snapshot(
            Path("/sys"), Path("/dev/input"),
            switch_report_fn=lambda _sys, _dev: "SW_TABLET_MODE aggregate: laptop\n",
            platform_report_fn=lambda _sys: "Platform tablet_mode aggregate: tablet\n",
        )
        self.assertIn("SW_TABLET_MODE aggregate: laptop", snapshot)
        self.assertIn("Platform tablet_mode aggregate: tablet", snapshot)

    def test_rejects_non_positive_interval_or_duration(self):
        with self.assertRaises(ValueError):
            monitor.run_monitor(lambda: "", interval=0, duration=1)
        with self.assertRaises(ValueError):
            monitor.run_monitor(lambda: "", interval=1, duration=0)

    def test_samples_once_when_duration_is_shorter_than_interval(self):
        clock = FakeClock()
        output = []
        count = monitor.run_monitor(
            lambda: "initial", interval=2, duration=0.25,
            clock=clock, sleep=clock.sleep,
            timestamp_fn=lambda: "timestamp", emit=output.append,
        )
        self.assertEqual(count, 1)
        self.assertEqual(output.count("initial"), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
