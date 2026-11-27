#!/usr/bin/env python3
"""Read platform tablet_mode sysfs attributes without changing them."""
from __future__ import annotations

import argparse
import os
import stat
import sys
from pathlib import Path
from typing import Callable


PLATFORM_ROOTS = (
    Path("devices/platform"),
    Path("bus/platform/devices"),
)


def collect_platform_report(
    sys_root: Path,
    *,
    scandir_fn: Callable = os.scandir,
) -> str:
    """Return a read-only inventory and aggregate of platform tablet_mode nodes.

    The bus path commonly contains symlinks to devices/platform. Resolved paths
    are de-duplicated, and a symlink resolving outside sys_root is not followed.
    Missing attributes are normal; missing/unreadable inventory roots and
    unreadable or malformed attributes are reported as incomplete.
    """
    lines = [
        "VIS OS Aurora 93 PRO X — platform tablet_mode state",
        "Read-only sysfs query; no attributes are written.",
        "[Platform tablet_mode attributes]",
    ]
    warnings: list[str] = []
    values: list[int] = []
    seen: set[str] = set()
    root_resolved = sys_root.resolve()

    for relative_root in PLATFORM_ROOTS:
        inventory_root = sys_root / relative_root
        try:
            with scandir_fn(inventory_root) as entries:
                for entry in entries:
                    try:
                        if not entry.is_dir(follow_symlinks=True):
                            continue
                    except OSError as exc:
                        warnings.append(
                            f"{relative_root.as_posix()}/{entry.name} "
                            f"device=unreadable({type(exc).__name__})"
                        )
                        continue

                    candidate = Path(entry.path) / "tablet_mode"
                    try:
                        candidate_stat = candidate.stat()
                    except FileNotFoundError:
                        # Most platform devices do not expose this optional attribute.
                        continue
                    except OSError as exc:
                        warnings.append(
                            f"{relative_root.as_posix()}/{entry.name}/tablet_mode "
                            f"unreadable({type(exc).__name__})"
                        )
                        continue

                    if not stat.S_ISREG(candidate_stat.st_mode):
                        warnings.append(
                            f"{relative_root.as_posix()}/{entry.name}/tablet_mode "
                            "not-a-regular-sysfs-attribute"
                        )
                        continue

                    try:
                        resolved = candidate.resolve(strict=True)
                        if not resolved.is_relative_to(root_resolved):
                            warnings.append(
                                f"{relative_root.as_posix()}/{entry.name}/tablet_mode "
                                "target-outside-sys-root"
                            )
                            continue
                        key = os.fspath(resolved)
                        if key in seen:
                            continue
                        seen.add(key)
                        raw_value = candidate.read_text(encoding="ascii").strip()
                    except (OSError, UnicodeError) as exc:
                        warnings.append(
                            f"{relative_root.as_posix()}/{entry.name}/tablet_mode "
                            f"unreadable({type(exc).__name__})"
                        )
                        continue

                    display_path = candidate.relative_to(sys_root).as_posix()
                    if raw_value not in {"0", "1"}:
                        lines.append(
                            f"path={display_path} value={raw_value!r} interpreted_mode=unknown"
                        )
                        warnings.append(f"{display_path} invalid-value")
                        continue

                    value = int(raw_value)
                    values.append(value)
                    mode = "tablet" if value else "laptop"
                    lines.append(
                        f"path={display_path} value={value} interpreted_mode={mode}"
                    )
        except OSError as exc:
            warnings.append(
                f"{relative_root.as_posix()} inventory=unreadable({type(exc).__name__})"
            )

    if warnings:
        lines.extend(["", "[Platform tablet_mode warnings]", *warnings])

    inventory_state = "incomplete" if warnings else "complete"
    lines.append(
        f"Platform tablet_mode inventory: {inventory_state} "
        f"({len(warnings)} warning(s))"
    )

    if not values:
        aggregate = (
            "unknown/incomplete" if warnings
            else "unknown (no direct platform tablet_mode attributes)"
        )
        if warnings and not any("value=" in line for line in lines):
            lines.append("No readable platform tablet_mode attributes found; inventory incomplete.")
    elif len(set(values)) > 1:
        aggregate = "conflict (platform devices report both laptop and tablet)"
    elif warnings:
        aggregate = f"incomplete ({len(values)} readable, {len(warnings)} warning(s))"
    else:
        mode = "tablet" if values[0] else "laptop"
        aggregate = f"{mode} ({len(values)} readable platform attribute(s))"

    lines.append(f"Platform tablet_mode aggregate: {aggregate}")
    lines.append(
        "Interpretation: diagnostic only; compare with physical hinge movement before enabling Auto mode."
    )
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sys-root", type=Path, default=Path("/sys"))
    args = parser.parse_args(argv)
    try:
        sys.stdout.write(collect_platform_report(args.sys_root))
    except OSError as exc:
        print(
            f"ERROR: unable to inspect platform tablet_mode attributes: {type(exc).__name__}",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
