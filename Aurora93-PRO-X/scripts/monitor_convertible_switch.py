#!/usr/bin/env python3
"""Poll read-only EVIOCGSW diagnostics and print only changed snapshots."""
from __future__ import annotations

import argparse
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Callable


def run_monitor(
    sample_fn: Callable[[], str],
    *,
    interval: float = 0.5,
    duration: float = 120.0,
    clock: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
    timestamp_fn: Callable[[], str] = lambda: datetime.now().astimezone().isoformat(timespec="seconds"),
    emit: Callable[[str], None] = print,
) -> int:
    """Sample until duration expires; emit the first and changed reports.

    Returns the number of snapshots taken. The function never writes to sysfs
    or input devices; sample_fn is expected to perform read-only queries.
    """
    if interval <= 0:
        raise ValueError("interval must be greater than zero")
    if duration <= 0:
        raise ValueError("duration must be greater than zero")

    deadline = clock() + duration
    previous: tuple[str, ...] | None = None
    samples = 0

    while True:
        report = sample_fn().rstrip("\n")
        samples += 1
        signature = tuple(report.splitlines())
        if signature != previous:
            emit(f"[{timestamp_fn()}] sample={samples}")
            emit(report)
            previous = signature

        remaining = deadline - clock()
        if remaining <= 0:
            break
        delay = min(interval, remaining)
        sleep(delay)
        if clock() >= deadline:
            break

    return samples


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sys-root", type=Path, default=Path("/sys"))
    parser.add_argument("--dev-root", type=Path, default=Path("/dev/input"))
    parser.add_argument("--interval", type=float, default=0.5,
                        help="poll interval in seconds (default: 0.5)")
    parser.add_argument("--duration", type=float, default=120.0,
                        help="capture duration in seconds (default: 120)")
    args = parser.parse_args(argv)
    if args.interval <= 0:
        parser.error("--interval must be greater than zero")
    if args.duration <= 0:
        parser.error("--duration must be greater than zero")

    # When executed as a script, its directory is sys.path[0]. Keep the
    # existing EVIOCGSW implementation as the single source of truth.
    from probe_convertible_switch_state import collect_report

    try:
        count = run_monitor(
            lambda: collect_report(args.sys_root, args.dev_root),
            interval=args.interval,
            duration=args.duration,
        )
    except KeyboardInterrupt:
        print("Capture interrupted by user.", file=sys.stderr)
        return 130
    except OSError as exc:
        print(f"ERROR: switch sampling failed: {type(exc).__name__}", file=sys.stderr)
        return 1

    print(f"Capture completed: {count} sample(s).", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
