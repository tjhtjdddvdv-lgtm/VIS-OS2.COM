Required fallback EFI filenames in the final ISO:

BOOTIA32.EFI — genuine 32-bit EFI application for IA32 UEFI.
BOOTX64.EFI  — genuine 64-bit EFI application for x86-64 UEFI.

These are different executable architectures. Never rename one binary to the
other filename. The firmware chooses the matching fallback path. Both
bootloaders must be configured to load the shared GRUB configuration.

Legacy BIOS needs a separate El Torito BIOS boot image; EFI files alone do
not provide BIOS boot support.

Secure Boot is not configured in this prototype. Do not claim Secure Boot
support until binaries are signed and the trust chain is verified.
