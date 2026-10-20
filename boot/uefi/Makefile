SHELL := /bin/bash
BUILD := build
EFI_DIR := $(BUILD)/efi/EFI/BOOT
EFI_APP := $(EFI_DIR)/BOOTX64.EFI
ISO := $(BUILD)/VIS-OS-UEFI-x86_64.iso
CC := gcc
LD := ld
OBJCOPY := objcopy
EFI_CFLAGS := -I/usr/include/efi -I/usr/include/efi/x86_64 -fpic -ffreestanding -fno-stack-protector -fno-stack-check -fshort-wchar -mno-red-zone -maccumulate-outgoing-args -Wall -Wextra
EFI_LDFLAGS := -nostdlib -znocombreloc -T /usr/lib/elf_x86_64_efi.lds -shared -Bsymbolic
EFI_LIBS := -L/usr/lib -lefi -lgnuefi

.PHONY: all clean
all: $(ISO)

$(BUILD)/efi_main.o: efi_main.c
	mkdir -p $(BUILD)
	$(CC) $(EFI_CFLAGS) -c $< -o $@

$(BUILD)/BOOTX64.so: $(BUILD)/efi_main.o
	$(LD) $(EFI_LDFLAGS) /usr/lib/crt0-efi-x86_64.o $< $(EFI_LIBS) -o $@

$(EFI_APP): $(BUILD)/BOOTX64.so
	mkdir -p $(EFI_DIR)
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel -j .rela -j .reloc --target=efi-app-x86_64 $< $@

$(ISO): $(EFI_APP)
	mkdir -p $(BUILD)/iso/boot
	dd if=/dev/zero of=$(BUILD)/iso/boot/efi.img bs=1M count=16 status=none
	mkfs.vfat $(BUILD)/iso/boot/efi.img
	mmd -i $(BUILD)/iso/boot/efi.img ::/EFI ::/EFI/BOOT
	mcopy -i $(BUILD)/iso/boot/efi.img $(EFI_APP) ::/EFI/BOOT/BOOTX64.EFI
	xorriso -as mkisofs -R -J -V VIS_OS_UEFI -e boot/efi.img -no-emul-boot -o $(ISO) $(BUILD)/iso
	@echo "Built $(ISO)"

clean:
	rm -rf $(BUILD)
