#!/usr/bin/env python3
import errno
import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/probe_convertible_switch_state.py"
SPEC = importlib.util.spec_from_file_location("vis_switch_probe", SCRIPT)
probe = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(probe)

class SwitchProbeTests(unittest.TestCase):
    def test_ioctl_request_supports_32_and_64_bit_userspace_sizes(self):
        for size in (4, 8):
            with self.subTest(size=size):
                request = probe.ev_iocgsw_request(size)
                self.assertEqual((request >> 30) & 0x3, probe.IOC_READ)
                self.assertEqual((request >> 16) & ((1 << probe.IOC_SIZE_BITS) - 1), size)
                self.assertEqual((request >> 8) & 0xFF, ord("E"))
                self.assertEqual(request & 0xFF, 0x1B)

    def test_capability_mask_decodes_only_lid_and_tablet_bits(self):
        self.assertEqual(probe.parse_switch_capabilities("00000003\n"), {0, 1})
        self.assertEqual(probe.parse_switch_capabilities("00000000 00000002\n"), {1})
        self.assertEqual(probe.parse_switch_capabilities("00000000"), set())
        self.assertIsNone(probe.parse_switch_capabilities("not-hex"))
        self.assertIsNone(probe.parse_switch_capabilities(""))

    def test_query_switch_state_decodes_ioctl_bitmap_and_closes_fd(self):
        open_fn = Mock(return_value=17)
        close_fn = Mock()
        def fake_ioctl(fd, request, buffer, mutate):
            self.assertEqual(fd, 17)
            self.assertTrue(mutate)
            buffer[:] = (3).to_bytes(len(buffer), byteorder=probe.sys.byteorder)
        state, error = probe.query_switch_state(
            Path("/dev/input/event2"), open_fn=open_fn, ioctl_fn=fake_ioctl,
            close_fn=close_fn, word_size=8)
        self.assertIsNone(error)
        self.assertEqual(state, {probe.SW_LID: True, probe.SW_TABLET_MODE: True})
        self.assertEqual(open_fn.call_args.args[1] & os.O_RDONLY, os.O_RDONLY)
        close_fn.assert_called_once_with(17)

    def test_permission_error_returns_unknown_and_closes_fd(self):
        close_fn = Mock()
        state, error = probe.query_switch_state(
            Path("/dev/input/event4"), open_fn=Mock(return_value=22),
            ioctl_fn=Mock(side_effect=PermissionError(errno.EACCES, "denied")),
            close_fn=close_fn, word_size=8)
        self.assertIsNone(state)
        self.assertEqual(error, "PermissionError")
        close_fn.assert_called_once_with(22)

    def _fixture(self, root: Path, entries: list[tuple[str, str, str]]):
        sys_root = root / "sys"
        dev_root = root / "dev/input"
        for event, name, mask in entries:
            base = sys_root / f"class/input/{event}/device"
            base.mkdir(parents=True)
            (base / "name").write_text(name + "\n", encoding="utf-8")
            (base / "capabilities").mkdir()
            (base / "capabilities/sw").write_text(mask + "\n", encoding="ascii")
        dev_root.mkdir(parents=True)
        return sys_root, dev_root

    def test_collect_report_detects_conflicting_live_states(self):
        with tempfile.TemporaryDirectory() as temp:
            sys_root, dev_root = self._fixture(
                Path(temp), [("event2", "Hinge A", "00000002"), ("event3", "Hinge B", "00000002")])
            fd_by_path = {str(dev_root / "event2"): 2, str(dev_root / "event3"): 3}
            states = {2: 0, 3: 2}
            def fake_ioctl(fd, request, buffer, mutate):
                buffer[:] = states[fd].to_bytes(len(buffer), byteorder=probe.sys.byteorder)
            report = probe.collect_report(
                sys_root, dev_root,
                open_fn=lambda path, flags: fd_by_path[path],
                ioctl_fn=fake_ioctl, close_fn=lambda fd: None)
            self.assertIn("event2 name=Hinge A SW_TABLET_MODE=laptop(0)", report)
            self.assertIn("event3 name=Hinge B SW_TABLET_MODE=tablet(1)", report)
            self.assertIn("SW_TABLET_MODE aggregate: conflict", report)
            self.assertIn("Switch capability inventory: complete (0 warning(s))", report)

    def test_unreadable_advertised_device_keeps_aggregate_incomplete(self):
        with tempfile.TemporaryDirectory() as temp:
            sys_root, dev_root = self._fixture(
                Path(temp), [("event2", "Hinge A", "00000002"), ("event3", "Hinge B", "00000002")])
            fd_by_path = {str(dev_root / "event2"): 2}
            def open_device(path, flags):
                if path not in fd_by_path:
                    raise PermissionError(errno.EACCES, "denied")
                return fd_by_path[path]
            def fake_ioctl(fd, request, buffer, mutate):
                buffer[:] = (2).to_bytes(len(buffer), byteorder=probe.sys.byteorder)
            report = probe.collect_report(
                sys_root, dev_root, open_fn=open_device, ioctl_fn=fake_ioctl,
                close_fn=lambda fd: None)
            self.assertIn("SW_TABLET_MODE aggregate: incomplete (1 readable, 1 unavailable)", report)

    def test_malformed_capability_mask_is_not_reported_as_no_switch_devices(self):
        with tempfile.TemporaryDirectory() as temp:
            sys_root, dev_root = self._fixture(
                Path(temp), [("event6", "Broken switch", "not-hex")])
            report = probe.collect_report(sys_root, dev_root)
            self.assertIn("event6 capabilities=malformed", report)
            self.assertIn("No valid switch capability entries found; inventory incomplete.", report)
            self.assertNotIn("No input event device advertises", report)

    def test_unreadable_capability_file_marks_inventory_incomplete(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            sys_root = root / "sys"
            dev_root = root / "dev/input"
            device = sys_root / "class/input/event7/device"
            device.mkdir(parents=True)
            (device / "name").write_text("Missing mask\n", encoding="utf-8")
            dev_root.mkdir(parents=True)
            report = probe.collect_report(sys_root, dev_root)
            self.assertIn("event7 capabilities=unreadable(FileNotFoundError)", report)
            self.assertIn("No valid switch capability entries found; inventory incomplete.", report)

    def test_devices_without_switch_capabilities_are_not_probed(self):
        with tempfile.TemporaryDirectory() as temp:
            sys_root, dev_root = self._fixture(
                Path(temp), [("event5", "Keyboard", "00000000")])
            open_fn = Mock(side_effect=AssertionError("must not open non-switch device"))
            report = probe.collect_report(sys_root, dev_root, open_fn=open_fn)
            self.assertIn("No input event device advertises", report)
            self.assertIn("Switch capability inventory: complete (0 warning(s))", report)
            open_fn.assert_not_called()

if __name__ == "__main__":
    unittest.main(verbosity=2)
