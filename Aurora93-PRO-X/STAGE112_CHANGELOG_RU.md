# Stage 112 — fail-closed switch inventory

- The EV_SW probe now reports unreadable and malformed input capability masks instead of silently skipping them.
- A clean zero bitmap remains a valid result meaning that the event device advertises no switch capabilities.
- The report explicitly marks capability inventory as complete or incomplete.
- Regression tests cover 32-bit and 64-bit ioctl request sizes, malformed and unreadable masks, and clean no-switch inventory.
- The UI remains unchanged; automatic Laptop/Tablet switching is not enabled.

Local validation: Python byte-compilation passed; 9/9 unit tests passed.
Tests use synthetic sysfs fixtures and mocked ioctl calls. No physical DIGMA,
real switch, driver, ISO build or boot test was performed.
