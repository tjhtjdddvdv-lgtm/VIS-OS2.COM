#!/usr/bin/env python3
import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/probe_platform_tablet_mode.py"
SPEC = importlib.util.spec_from_file_location("vis_platform_tablet_probe", SCRIPT)
probe = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(probe)


class PlatformTabletModeProbeTests(unittest.TestCase):
    def _fixture(self, root: Path):
        sys_root = root / "sys"
        (sys_root / "devices/platform").mkdir(parents=True)
        (sys_root / "bus/platform/devices").mkdir(parents=True)
        return sys_root

    def _device(self, sys_root: Path, name: str, value: str) -> Path:
        device = sys_root / "devices/platform" / name
        device.mkdir(parents=True)
        (device / "tablet_mode").write_text(value, encoding="ascii")
        return device

    def test_reads_laptop_and_tablet_values(self):
        with tempfile.TemporaryDirectory() as temp:
            sys_root = self._fixture(Path(temp))
            device = self._device(sys_root, "hinge", "0\n")
            report = probe.collect_platform_report(sys_root)
            self.assertIn("devices/platform/hinge/tablet_mode value=0 interpreted_mode=laptop", report)
            self.assertIn("Platform tablet_mode aggregate: laptop (1 readable platform attribute(s))", report)

            (device / "tablet_mode").write_text("1\n", encoding="ascii")
            report = probe.collect_platform_report(sys_root)
            self.assertIn("value=1 interpreted_mode=tablet", report)
            self.assertIn("Platform tablet_mode aggregate: tablet (1 readable platform attribute(s))", report)

    def test_bus_alias_is_deduplicated(self):
        with tempfile.TemporaryDirectory() as temp:
            sys_root = self._fixture(Path(temp))
            device = self._device(sys_root, "hinge", "1\n")
            (sys_root / "bus/platform/devices/hinge").symlink_to(device, target_is_directory=True)
            report = probe.collect_platform_report(sys_root)
            self.assertEqual(report.count("interpreted_mode=tablet"), 1)
            self.assertIn("Platform tablet_mode aggregate: tablet (1 readable platform attribute(s))", report)

    def test_conflicting_platform_devices_are_not_collapsed(self):
        with tempfile.TemporaryDirectory() as temp:
            sys_root = self._fixture(Path(temp))
            self._device(sys_root, "hinge-a", "0\n")
            self._device(sys_root, "hinge-b", "1\n")
            report = probe.collect_platform_report(sys_root)
            self.assertIn("Platform tablet_mode aggregate: conflict", report)

    def test_invalid_value_marks_inventory_incomplete(self):
        with tempfile.TemporaryDirectory() as temp:
            sys_root = self._fixture(Path(temp))
            self._device(sys_root, "hinge", "2\n")
            report = probe.collect_platform_report(sys_root)
            self.assertIn("invalid-value", report)
            self.assertIn("Platform tablet_mode inventory: incomplete", report)
            self.assertIn("Platform tablet_mode aggregate: unknown/incomplete", report)

    def test_missing_inventory_roots_are_not_reported_as_empty_complete(self):
        with tempfile.TemporaryDirectory() as temp:
            sys_root = Path(temp) / "sys"
            report = probe.collect_platform_report(sys_root)
            self.assertIn("Platform tablet_mode inventory: incomplete", report)
            self.assertIn("Platform tablet_mode aggregate: unknown/incomplete", report)

    def test_symlink_outside_sys_root_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            sys_root = self._fixture(root)
            outside = root / "outside"
            outside.mkdir()
            (outside / "tablet_mode").write_text("1\n", encoding="ascii")
            (sys_root / "devices/platform/escape").symlink_to(outside, target_is_directory=True)
            report = probe.collect_platform_report(sys_root)
            self.assertIn("target-outside-sys-root", report)
            self.assertNotIn("interpreted_mode=tablet", report)


if __name__ == "__main__":
    unittest.main(verbosity=2)
