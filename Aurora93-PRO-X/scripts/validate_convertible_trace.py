#!/usr/bin/env python3
"""Validate a recorded Laptop -> Tablet -> Laptop switch trace offline.

This tool reads a Stage 114/115 monitor trace only. It never accesses input
or sysfs devices and never changes the desktop mode.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


HEADER_RE = re.compile(r"^\[(?P<timestamp>[^\]]+)\]\s+sample=(?P<sample>[0-9]+)$")
SWITCH_AGGREGATE = "SW_TABLET_MODE aggregate:"
SWITCH_INVENTORY = "Switch capability inventory:"
PLATFORM_AGGREGATE = "Platform tablet_mode aggregate:"
PLATFORM_INVENTORY = "Platform tablet_mode inventory:"
EXPECTED_SEQUENCE = ("laptop", "tablet", "laptop")


@dataclass(frozen=True)
class Snapshot:
    timestamp: datetime
    sample: int
    lines: tuple[str, ...]


@dataclass(frozen=True)
class SourceState:
    state: str | None
    issue: str | None


@dataclass(frozen=True)
class ValidationResult:
    status: str
    snapshot_count: int
    switch_sequence: tuple[str, ...]
    platform_sequence: tuple[str, ...]
    reason: str

    def render(self) -> str:
        switch = " -> ".join(self.switch_sequence) or "unavailable"
        platform = " -> ".join(self.platform_sequence) or "unavailable"
        return "\n".join((
            "VIS OS Aurora 93 PRO X — convertible trace validation",
            f"Snapshots: {self.snapshot_count}",
            f"Input switch sequence: {switch}",
            f"Platform tablet_mode sequence: {platform}",
            f"Trace validation: {self.status}",
            f"Reason: {self.reason}",
            "Auto mode remains disabled; this report is diagnostic only.",
        )) + "\n"


def parse_trace(text: str) -> list[Snapshot]:
    """Parse monitor output and reject malformed or out-of-order headers."""
    snapshots: list[Snapshot] = []
    current_timestamp: datetime | None = None
    current_sample: int | None = None
    current_lines: list[str] = []
    previous_sample = 0
    previous_timestamp: datetime | None = None

    for line_number, line in enumerate(text.splitlines(), start=1):
        match = HEADER_RE.fullmatch(line.strip())
        if match:
            if current_timestamp is not None and current_sample is not None:
                snapshots.append(Snapshot(current_timestamp, current_sample, tuple(current_lines)))
            try:
                timestamp = datetime.fromisoformat(match.group("timestamp"))
            except ValueError as exc:
                raise ValueError(f"line {line_number}: invalid timestamp") from exc
            if timestamp.tzinfo is None or timestamp.utcoffset() is None:
                raise ValueError(f"line {line_number}: timestamp must include a UTC offset")
            sample = int(match.group("sample"))
            if sample <= 0 or sample <= previous_sample:
                raise ValueError(f"line {line_number}: sample numbers must be positive and increase")
            if previous_timestamp is not None and timestamp < previous_timestamp:
                raise ValueError(f"line {line_number}: timestamps moved backwards")
            previous_sample = sample
            previous_timestamp = timestamp
            current_timestamp = timestamp
            current_sample = sample
            current_lines = []
        elif current_timestamp is None:
            if line.strip():
                raise ValueError(f"line {line_number}: content before first snapshot header")
        else:
            current_lines.append(line)

    if current_timestamp is not None and current_sample is not None:
        snapshots.append(Snapshot(current_timestamp, current_sample, tuple(current_lines)))
    if not snapshots:
        raise ValueError("trace contains no monitor snapshots")
    return snapshots


def _source_state(snapshot: Snapshot, aggregate_prefix: str, inventory_prefix: str) -> SourceState:
    aggregates = [line.split(aggregate_prefix, 1)[1].strip()
                  for line in snapshot.lines if line.startswith(aggregate_prefix)]
    inventories = [line.split(inventory_prefix, 1)[1].strip()
                   for line in snapshot.lines if line.startswith(inventory_prefix)]
    if len(aggregates) != 1 or len(inventories) != 1:
        return SourceState(None, "missing or duplicate aggregate/inventory summary")

    inventory_status = inventories[0].split(maxsplit=1)[0].lower()
    if inventory_status != "complete":
        return SourceState(None, f"inventory {inventory_status or 'unknown'}")

    state = aggregates[0].split(maxsplit=1)[0].lower()
    if state not in {"laptop", "tablet"}:
        return SourceState(None, f"aggregate {state or 'unknown'}")
    return SourceState(state, None)


def _collapse(states: list[str | None]) -> tuple[str, ...]:
    collapsed: list[str] = []
    for state in states:
        if state is not None and (not collapsed or collapsed[-1] != state):
            collapsed.append(state)
    return tuple(collapsed)


def validate_trace(text: str) -> ValidationResult:
    try:
        snapshots = parse_trace(text)
    except ValueError as exc:
        return ValidationResult("INCOMPLETE", 0, (), (), str(exc))

    switch_states: list[str | None] = []
    platform_states: list[str | None] = []
    issues: list[str] = []
    conflicts: list[int] = []

    for snapshot in snapshots:
        switch = _source_state(snapshot, SWITCH_AGGREGATE, SWITCH_INVENTORY)
        platform = _source_state(snapshot, PLATFORM_AGGREGATE, PLATFORM_INVENTORY)
        switch_states.append(switch.state)
        platform_states.append(platform.state)
        if switch.issue:
            issues.append(f"sample {snapshot.sample}: input switch {switch.issue}")
        if platform.issue:
            issues.append(f"sample {snapshot.sample}: platform source {platform.issue}")
        if switch.state is not None and platform.state is not None and switch.state != platform.state:
            conflicts.append(snapshot.sample)

    switch_sequence = _collapse(switch_states)
    platform_sequence = _collapse(platform_states)

    if conflicts:
        return ValidationResult(
            "REJECTED", len(snapshots), switch_sequence, platform_sequence,
            "sources disagree at sample(s): " + ", ".join(map(str, conflicts)),
        )
    if issues:
        return ValidationResult(
            "INCOMPLETE", len(snapshots), switch_sequence, platform_sequence,
            "; ".join(issues),
        )
    if switch_sequence != EXPECTED_SEQUENCE or platform_sequence != EXPECTED_SEQUENCE:
        return ValidationResult(
            "REJECTED", len(snapshots), switch_sequence, platform_sequence,
            "both sources must independently record exactly laptop -> tablet -> laptop",
        )
    if switch_states != platform_states:
        return ValidationResult(
            "REJECTED", len(snapshots), switch_sequence, platform_sequence,
            "sources did not agree in every recorded snapshot",
        )
    return ValidationResult(
        "PASS", len(snapshots), switch_sequence, platform_sequence,
        "both complete sources agree on laptop -> tablet -> laptop",
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path, help="monitor trace file created by monitor_convertible_switch.py")
    args = parser.parse_args(argv)
    try:
        text = args.trace.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"ERROR: cannot read trace ({type(exc).__name__})", file=sys.stderr)
        return 2

    result = validate_trace(text)
    sys.stdout.write(result.render())
    return {"PASS": 0, "INCOMPLETE": 1, "REJECTED": 2}[result.status]


if __name__ == "__main__":
    raise SystemExit(main())
