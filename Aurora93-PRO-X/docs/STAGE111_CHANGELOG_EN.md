# Stage 111 — current EV_SW state probe

- Added a read-only Python probe that queries EVIOCGSW for input devices advertising SW_LID or SW_TABLET_MODE.
- Separates current state from Stage 110 capability masks.
- Reports unknown, incomplete and conflicting devices without selecting an automatic desktop mode.
- Added seven unit tests covering ioctl encoding, capability decoding, permission failures, file-descriptor cleanup, conflicts and incomplete probes.
- Updated the Russian project README with run and safety instructions.

Local validation: Python byte-compilation passed; 7/7 unit tests passed.
The execution container exposed no convertible switch input devices. No DIGMA hardware,
real input event, ISO, UEFI boot or driver was tested.
