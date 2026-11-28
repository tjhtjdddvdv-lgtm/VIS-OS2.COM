#!/usr/bin/env python3
import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/validate_convertible_trace.py"
SPEC = importlib.util.spec_from_file_location("vis_trace_validator", SCRIPT)
validator = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = validator
assert SPEC.loader is not None
SPEC.loader.exec_module(validator)


def snapshot(sample, switch, platform, switch_inventory="complete", platform_inventory="complete", timestamp=None):
    timestamp = timestamp or f"2026-11-28T18:00:{sample:02d}+01:00"
    return "\n".join((
        f"[{timestamp}] sample={sample}",
        f"Switch capability inventory: {switch_inventory} (0 warning(s))",
        f"SW_TABLET_MODE aggregate: {switch} (1 readable; all advertised devices queried)",
        f"Platform tablet_mode inventory: {platform_inventory} (0 warning(s))",
        f"Platform tablet_mode aggregate: {platform} (1 readable platform attribute(s))",
    ))


class ConvertibleTraceValidatorTests(unittest.TestCase):
    def test_accepts_matching_complete_laptop_tablet_laptop_cycle(self):
        trace = "\n".join((
            snapshot(1, "laptop", "laptop"),
            snapshot(2, "tablet", "tablet"),
            snapshot(3, "laptop", "laptop"),
        ))
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "PASS")
        self.assertEqual(result.switch_sequence, ("laptop", "tablet", "laptop"))
        self.assertEqual(result.platform_sequence, ("laptop", "tablet", "laptop"))

    def test_rejects_source_disagreement(self):
        trace = "\n".join((
            snapshot(1, "laptop", "laptop"),
            snapshot(2, "tablet", "laptop"),
            snapshot(3, "laptop", "laptop"),
        ))
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "REJECTED")
        self.assertIn("disagree", result.reason)

    def test_incomplete_input_inventory_cannot_pass(self):
        trace = "\n".join((
            snapshot(1, "laptop", "laptop", switch_inventory="incomplete"),
            snapshot(2, "tablet", "tablet"),
            snapshot(3, "laptop", "laptop"),
        ))
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "INCOMPLETE")
        self.assertIn("input switch inventory incomplete", result.reason)

    def test_missing_platform_attribute_cannot_pass(self):
        trace = "\n".join((
            snapshot(1, "laptop", "unknown"),
            snapshot(2, "tablet", "unknown"),
            snapshot(3, "laptop", "unknown"),
        ))
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "INCOMPLETE")
        self.assertIn("platform source aggregate unknown", result.reason)

    def test_rejects_bounce_or_extra_transition(self):
        trace = "\n".join((
            snapshot(1, "laptop", "laptop"),
            snapshot(2, "tablet", "tablet"),
            snapshot(3, "laptop", "laptop"),
            snapshot(4, "tablet", "tablet"),
        ))
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "REJECTED")
        self.assertIn("exactly laptop -> tablet -> laptop", result.reason)

    def test_rejects_non_increasing_sample_numbers(self):
        trace = "\n".join((
            snapshot(2, "laptop", "laptop"),
            snapshot(2, "tablet", "tablet"),
        ))
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "INCOMPLETE")
        self.assertIn("sample numbers must be positive and increase", result.reason)

    def test_rejects_timestamp_without_offset(self):
        trace = snapshot(1, "laptop", "laptop", timestamp="2026-11-28T18:00:01")
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "INCOMPLETE")
        self.assertIn("UTC offset", result.reason)

    def test_rejects_missing_summary_line(self):
        trace = snapshot(1, "laptop", "laptop").replace(
            "Platform tablet_mode inventory: complete (0 warning(s))\n", ""
        )
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "INCOMPLETE")
        self.assertIn("missing or duplicate", result.reason)

    def test_rejects_timestamp_moving_backwards(self):
        trace = "\n".join((
            snapshot(1, "laptop", "laptop", timestamp="2026-11-28T18:00:02+01:00"),
            snapshot(2, "tablet", "tablet", timestamp="2026-11-28T18:00:01+01:00"),
        ))
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "INCOMPLETE")
        self.assertIn("timestamps moved backwards", result.reason)

    def test_rejects_zero_sample_number(self):
        trace = snapshot(1, "laptop", "laptop").replace("sample=1", "sample=0")
        result = validator.validate_trace(trace)
        self.assertEqual(result.status, "INCOMPLETE")
        self.assertIn("sample numbers must be positive and increase", result.reason)

    def test_requires_content_before_no_header_to_be_empty(self):
        result = validator.validate_trace("unexpected preamble\n" + snapshot(1, "laptop", "laptop"))
        self.assertEqual(result.status, "INCOMPLETE")
        self.assertIn("before first snapshot", result.reason)


if __name__ == "__main__":
    unittest.main(verbosity=2)
