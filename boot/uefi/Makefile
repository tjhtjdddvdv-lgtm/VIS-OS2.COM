SHELL := /bin/bash
BUILD := build
EFI_DIR := $(BUILD)/iso/EFI/BOOT
EFI_APP := $(EFI_DIR)/BOOTX64.EFI
ISO := $(BUILD)/VIS-OS-UEFI-x86_64.iso
EFI_INC := /usr/include/efi
EFI_ARCH_INC := /usr/include/efi/x86_64
EFI_LIBDIR := $(shell dpkg -L gnu-efi 2>/dev/null | grep '/crt0-efi-x86_64.o$$' | head -n1 | xargs -r dirname)
EFI_LDS := $(shell dpkg -L gnu-efi 2>/dev/null | grep '/elf_x86_64_efi.lds$$' | head -n1)
EFI_CFLAGS := -I$(EFI_INC) -I$(EFI_ARCH_INC) -fpic -ffreestanding -fno-stack-protector -fno-stack-check -fshort-wchar -mno-red-zone -maccumulate-outgoing-args -Wall -Wextra
EFI_LDFLAGS := -nostdlib -znocombreloc -T $(EFI_LDS) -shared -Bsymbolic
EFI_LIBS := -L$(EFI_LIBDIR) -lefi -lgnuefi

.PHONY: all clean check-tools
all: check-tools $(ISO)

check-tools:
	@test -n "$(EFI_LIBDIR)" -a -f "$(EFI_LIBDIR)/crt0-efi-x86_64.o" || (echo "Missing gnu-efi linker objects"; exit 1)
	@test -n "$(EFI_LDS)" -a -f "$(EFI_LDS)" || (echo "Missing gnu-efi linker script"; exit 1)
	@command -v gcc >/dev/null && command -v ld >/dev/null && command -v objcopy >/dev/null
	@command -v mkfs.vfat >/dev/null && command -v mmd >/dev/null && command -v mcopy >/dev/null && command -v xorriso >/dev/null

$(BUILD)/efi_main.o: efi_main.c
	mkdir -p $(BUILD)
	$(CC) $(EFI_CFLAGS) -c $< -o $@

$(BUILD)/BOOTX64.so: $(BUILD)/efi_main.o
	$(LD) $(EFI_LDFLAGS) $(EFI_LIBDIR)/crt0-efi-x86_64.o $< $(EFI_LIBS) -o $@

$(EFI_APP): $(BUILD)/BOOTX64.so
	mkdir -p $(EFI_DIR)
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel -j .rela -j .reloc --target=efi-app-x86_64 $< $@

$(ISO): $(EFI_APP)
	mkdir -p $(BUILD)/iso/boot
	dd if=/dev/zero of=$(BUILD)/iso/boot/efi.img bs=1M count=16 status=none
	mkfs.vfat -F 16 $(BUILD)/iso/boot/efi.img
	mmd -i $(BUILD)/iso/boot/efi.img ::/EFI ::/EFI/BOOT
	mcopy -i $(BUILD)/iso/boot/efi.img $(EFI_APP) ::/EFI/BOOT/BOOTX64.EFI
	xorriso -as mkisofs -R -J -V VIS_OS_UEFI -eltorito-alt-boot -e boot/efi.img -no-emul-boot -o $(ISO) $(BUILD)/iso
	@echo "Built $(ISO)"

clean:
	rm -rf $(BUILD)
