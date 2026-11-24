#!/usr/bin/env python3
"""Read current EV_SW state from Linux input devices without changing them."""
from __future__ import annotations
import argparse
import ctypes
import fcntl
import os
import sys
from pathlib import Path
from typing import Callable

SW_LID = 0
SW_TABLET_MODE = 1
IOC_READ = 2
IOC_NR_BITS = 8
IOC_TYPE_BITS = 8
IOC_SIZE_BITS = 14
IOC_NR_SHIFT = 0
IOC_TYPE_SHIFT = IOC_NR_SHIFT + IOC_NR_BITS
IOC_SIZE_SHIFT = IOC_TYPE_SHIFT + IOC_TYPE_BITS
IOC_DIR_SHIFT = IOC_SIZE_SHIFT + IOC_SIZE_BITS

def ev_iocgsw_request(word_size: int | None = None) -> int:
    """Build EVIOCGSW(sizeof(unsigned long)) for the current userspace ABI."""
    size = word_size if word_size is not None else ctypes.sizeof(ctypes.c_ulong)
    if size <= 0 or size >= (1 << IOC_SIZE_BITS):
        raise ValueError("invalid ioctl buffer size")
    return ((IOC_READ << IOC_DIR_SHIFT) | (size << IOC_SIZE_SHIFT)
            | (ord("E") << IOC_TYPE_SHIFT) | 0x1B)

def parse_switch_capabilities(mask_text: str) -> set[int] | None:
    """Parse Linux capabilities/sw bitmap; return supported EV_SW codes."""
    compact = "".join(mask_text.split())
    if not compact:
        return None
    try:
        bits = int(compact, 16)
    except ValueError:
        return None
    return {code for code in (SW_LID, SW_TABLET_MODE) if bits & (1 << code)}

def query_switch_state(device_path: Path, *, open_fn: Callable = os.open,
                       ioctl_fn: Callable = fcntl.ioctl, close_fn: Callable = os.close,
                       word_size: int | None = None) -> tuple[dict[int, bool] | None, str | None]:
    """Read EVIOCGSW state. Returns unknown plus an error class on failure."""
    size = word_size if word_size is not None else ctypes.sizeof(ctypes.c_ulong)
    fd = None
    try:
        flags = os.O_RDONLY | os.O_NONBLOCK | getattr(os, "O_CLOEXEC", 0)
        fd = open_fn(str(device_path), flags)
        buffer = bytearray(size)
        ioctl_fn(fd, ev_iocgsw_request(size), buffer, True)
        bits = int.from_bytes(buffer, byteorder=sys.byteorder, signed=False)
        return {SW_LID: bool(bits & (1 << SW_LID)),
                SW_TABLET_MODE: bool(bits & (1 << SW_TABLET_MODE))}, None
    except OSError as exc:
        return None, type(exc).__name__
    finally:
        if fd is not None:
            close_fn(fd)

def _safe_name(path: Path) -> str:
    try:
        value = path.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        value = "unknown"
    return " ".join(value.split()) or "unknown"

def _aggregate(values: list[bool], unavailable: int) -> str:
    if not values:
        return "unknown (no readable state)"
    labels = {"tablet" if value else "laptop" for value in values}
    if len(labels) > 1:
        return "conflict (devices report both laptop and tablet)"
    if unavailable:
        return f"incomplete ({len(values)} readable, {unavailable} unavailable)"
    return f"{next(iter(labels))} ({len(values)} readable; all advertised devices queried)"

def collect_report(sys_root: Path, dev_root: Path, *, open_fn: Callable = os.open,
                   ioctl_fn: Callable = fcntl.ioctl, close_fn: Callable = os.close) -> str:
    lines = [
        "VIS OS Aurora 93 PRO X — current convertible switch state",
        "Read-only EVIOCGSW probe; no input events are consumed and no device state is changed.",
    ]
    tablet_values: list[bool] = []
    tablet_unavailable = 0
    lid_values: list[bool] = []
    lid_unavailable = 0
    found = 0
    inventory_warnings: list[str] = []

    for event_dir in sorted((sys_root / "class/input").glob("event*")):
        if not event_dir.is_dir():
            continue
        caps_path = event_dir / "device/capabilities/sw"
        try:
            caps_text = caps_path.read_text(encoding="ascii").strip()
        except OSError as exc:
            inventory_warnings.append(
                f"{event_dir.name} capabilities=unreadable({type(exc).__name__})")
            continue

        supported = parse_switch_capabilities(caps_text)
        if supported is None:
            inventory_warnings.append(f"{event_dir.name} capabilities=malformed")
            continue
        if not supported:
            continue

        found += 1
        name = _safe_name(event_dir / "device/name")
        device_path = dev_root / event_dir.name
        state, error = query_switch_state(device_path, open_fn=open_fn,
                                          ioctl_fn=ioctl_fn, close_fn=close_fn)
        fields = [f"{event_dir.name} name={name}"]
        if SW_TABLET_MODE in supported:
            if state is None:
                tablet_unavailable += 1
                fields.append(f"SW_TABLET_MODE=unknown({error})")
            else:
                value = state[SW_TABLET_MODE]
                tablet_values.append(value)
                fields.append(f"SW_TABLET_MODE={'tablet' if value else 'laptop'}({int(value)})")
        if SW_LID in supported:
            if state is None:
                lid_unavailable += 1
                fields.append(f"SW_LID=unknown({error})")
            else:
                value = state[SW_LID]
                lid_values.append(value)
                fields.append(f"SW_LID={'closed' if value else 'open'}({int(value)})")
        lines.append(" ".join(fields))

    if inventory_warnings:
        lines.extend(["", "[Capability inventory warnings]", *inventory_warnings])
    inventory_state = "incomplete" if inventory_warnings else "complete"
    lines.append(f"Switch capability inventory: {inventory_state} ({len(inventory_warnings)} warning(s))")
    if not found and inventory_warnings:
        lines.append("No valid switch capability entries found; inventory incomplete.")
    elif not found:
        lines.append("No input event device advertises SW_LID or SW_TABLET_MODE.")

    if not lid_values:
        lid_summary = "unknown/incomplete"
    elif len(set(lid_values)) > 1:
        lid_summary = "conflict"
    elif lid_unavailable:
        lid_summary = "unknown/incomplete"
    else:
        lid_summary = "closed" if lid_values[0] else "open"

    lines.extend([
        "",
        f"SW_TABLET_MODE aggregate: {_aggregate(tablet_values, tablet_unavailable)}",
        f"SW_LID aggregate: {lid_summary}",
        "Interpretation: aggregate state is diagnostic only; do not change desktop mode until verified on the physical device.",
        "Permission note: run with access to /dev/input/event* (for example, via sudo) if states are reported unknown(PermissionError).",
    ])
    return "\n".join(lines) + "\n"

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sys-root", type=Path, default=Path("/sys"))
    parser.add_argument("--dev-root", type=Path, default=Path("/dev/input"))
    args = parser.parse_args()
    try:
        sys.stdout.write(collect_report(args.sys_root, args.dev_root))
    except OSError as exc:
        print(f"ERROR: unable to read input switch inventory: {type(exc).__name__}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
