# Stage 113 — fail-closed sysfs input enumeration

- Replaced silent `Path.glob()` input enumeration with explicit `os.scandir()`.
- Missing or unreadable `/sys/class/input` now marks switch inventory as incomplete instead of reporting a clean empty inventory.
- Unreadable event entries and event names that are not directories are recorded as inventory warnings.
- Added regression coverage for a missing sysfs root, a permission error during enumeration, and a genuinely empty but readable input root.
- No UI, desktop mode, wallpaper, kernel, EFI loader or device configuration was changed.

Validation performed against the candidate source before publication:
- Python byte-compilation passed.
- 12/12 unit tests passed using temporary sysfs fixtures and mocked ioctl/scandir calls.
- No physical DIGMA, real hinge switch, ISO build or boot test was performed.
