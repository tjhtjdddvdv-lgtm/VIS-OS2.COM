#include <efi.h>
#include <efilib.h>

#define RGB(r,g,b) { (b), (g), (r), 0 }

static EFI_GRAPHICS_OUTPUT_PROTOCOL *gop = NULL;
static EFI_GRAPHICS_OUTPUT_BLT_PIXEL bg = RGB(8, 9, 16);
static EFI_GRAPHICS_OUTPUT_BLT_PIXEL panel = RGB(19, 21, 36);
static EFI_GRAPHICS_OUTPUT_BLT_PIXEL violet = RGB(169, 150, 255);
static EFI_GRAPHICS_OUTPUT_BLT_PIXEL cyan = RGB(133, 239, 255);
static EFI_GRAPHICS_OUTPUT_BLT_PIXEL white = RGB(245, 245, 251);
static EFI_GRAPHICS_OUTPUT_BLT_PIXEL muted = RGB(155, 162, 185);
static EFI_GRAPHICS_OUTPUT_BLT_PIXEL green = RGB(125, 255, 190);

static VOID Fill(UINTN x, UINTN y, UINTN w, UINTN h,
                 EFI_GRAPHICS_OUTPUT_BLT_PIXEL color) {
    if (!gop || w == 0 || h == 0) return;
    gop->Blt(gop, &color, EfiBltVideoFill, 0, 0, x, y, w, h, 0);
}

static VOID DrawScreen(BOOLEAN keyboard_test) {
    UINTN w = 1024, h = 768;
    if (gop && gop->Mode && gop->Mode->Info) {
        w = gop->Mode->Info->HorizontalResolution;
        h = gop->Mode->Info->VerticalResolution;
    }
    Fill(0, 0, w, h, bg);
    Fill(0, 0, w, 5, violet);
    Fill(0, 5, w, 2, cyan);

    UINTN left = w / 12, top = h / 8;
    UINTN cardw = (w * 5) / 6, cardh = (h * 3) / 4;
    Fill(left, top, cardw, cardh, panel);
    Fill(left, top, cardw, 2, violet);

    Fill(left + 32, top + 32, 42, 42, violet);
    Fill(left + 43, top + 41, 20, 23, bg);
    Fill(left + 49, top + 47, 8, 11, cyan);

    Fill(left + 32, top + 100, cardw - 64, 1, muted);
    Fill(left + 32, top + 130, cardw / 2, 3, cyan);
    Fill(left + 32, top + 145, cardw / 3, 2, muted);

    UINTN tiley = top + 190;
    UINTN tilew = (cardw - 80) / 3;
    for (UINTN i = 0; i < 3; i++) {
        UINTN tx = left + 32 + i * (tilew + 8);
        Fill(tx, tiley, tilew, 90, bg);
        Fill(tx, tiley, tilew, 2, i == 1 ? cyan : violet);
        Fill(tx + 14, tiley + 16, 20, 20, i == 1 ? cyan : violet);
        Fill(tx + 14, tiley + 52, tilew - 28, 2, muted);
        Fill(tx + 14, tiley + 62, tilew / 2, 2, muted);
    }

    Fill(left + 32, top + cardh - 60, cardw - 64, 1, muted);
    Fill(left + 32, top + cardh - 38, 8, 8, green);
    if (keyboard_test) {
        Fill(left + 46, top + cardh - 38, cardw / 2, 2, green);
    } else {
        Fill(left + 46, top + cardh - 38, cardw / 2, 2, muted);
    }

    if (SystemTable && SystemTable->ConOut) {
        SystemTable->ConOut->SetAttribute(SystemTable->ConOut,
            EFI_TEXT_ATTR(EFI_WHITE, EFI_BACKGROUND_BLACK));
        SystemTable->ConOut->ClearScreen(SystemTable->ConOut);
        SystemTable->ConOut->OutputString(SystemTable->ConOut,
            L"\r\n  VIS OS  |  AURORA UEFI STARTUP\r\n\r\n");
        SystemTable->ConOut->OutputString(SystemTable->ConOut,
            L"  Custom UEFI application loaded successfully.\r\n");
        SystemTable->ConOut->OutputString(SystemTable->ConOut,
            L"  This is an early boot test, not the full operating system.\r\n\r\n");
        SystemTable->ConOut->OutputString(SystemTable->ConOut,
            L"  Press any key to run the keyboard input test.\r\n");
        SystemTable->ConOut->OutputString(SystemTable->ConOut,
            L"  Press ESC to restart the machine.\r\n");
        if (keyboard_test) {
            SystemTable->ConOut->OutputString(SystemTable->ConOut,
                L"\r\n  KEYBOARD INPUT RECEIVED. VIS OS UEFI TEST PASSED.\r\n");
        }
    }
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *ST) {
    EFI_STATUS status;
    EFI_GUID gop_guid = EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;
    EFI_INPUT_KEY key;
    UINTN event_index;

    InitializeLib(ImageHandle, ST);
    status = ST->BootServices->LocateProtocol(&gop_guid, NULL, (VOID **)&gop);
    if (EFI_ERROR(status)) gop = NULL;

    if (gop && gop->Mode && gop->Mode->Info) {
        UINTN max_mode = gop->Mode->MaxMode;
        UINTN best_mode = gop->Mode->Mode;
        UINTN best_area = 0;
        for (UINTN i = 0; i < max_mode; i++) {
            EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info = NULL;
            UINTN info_size = 0;
            if (!EFI_ERROR(gop->QueryMode(gop, i, &info_size, &info)) && info) {
                UINTN area = info->HorizontalResolution * info->VerticalResolution;
                if (area >= 800 * 600 && area > best_area) {
                    best_area = area;
                    best_mode = i;
                }
                ST->BootServices->FreePool(info);
            }
        }
        if (best_area) gop->SetMode(gop, best_mode);
    }

    DrawScreen(FALSE);
    while (1) {
        ST->BootServices->WaitForEvent(1, &ST->ConIn->WaitForKey, &event_index);
        status = ST->ConIn->ReadKeyStroke(ST->ConIn, &key);
        if (EFI_ERROR(status)) continue;
        if (key.ScanCode == SCAN_ESC) {
            ST->RuntimeServices->ResetSystem(EfiResetCold, EFI_SUCCESS, 0, NULL);
        }
        DrawScreen(TRUE);
    }
}
