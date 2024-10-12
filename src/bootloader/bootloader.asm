bits 16                          ; We are still in 16-bit Real Mode, as BIOS starts the bootloader in this mode.

org 0x7c00                       ; The BIOS loads the bootloader at memory address 0x7C00, so we set the origin to this address.

start: jmp loader                ; Jump over the OEM block to the actual loader code.

;*************************************************;
;  OEM Parameter block (BIOS Parameter Block - BPB)
;*************************************************;

; This section contains the BIOS Parameter Block (BPB), which provides information about the disk layout.

bpbOEM          db "GovernOs "    ; The OEM name for the operating system, 8 bytes, required by FAT12/FAT16.

bpbBytesPerSector:   DW 512       ; Number of bytes per sector (512 bytes in this case).
bpbSectorsPerCluster: DB 1        ; Number of sectors per cluster (1 sector per cluster).
bpbReservedSectors:  DW 1         ; Number of reserved sectors (the first sector, the boot sector).
bpbNumberOfFATs:     DB 2         ; Number of File Allocation Tables (FATs) present (2 for redundancy).
bpbRootEntries:      DW 224       ; Maximum number of root directory entries (224 entries).
bpbTotalSectors:     DW 2880      ; Total number of sectors on the disk (for a 1.44MB floppy, this is 2880).
bpbMedia:           DB 0xF0       ; Media descriptor byte (0xF0 indicates a 1.44MB floppy disk).
bpbSectorsPerFAT:   DW 9          ; Number of sectors per FAT (9 sectors per FAT for a 1.44MB floppy).
bpbSectorsPerTrack: DW 18         ; Number of sectors per track (18 sectors per track on a floppy disk).
bpbHeadsPerCylinder: DW 2         ; Number of heads per cylinder (2 heads on a floppy disk).
bpbHiddenSectors:   DD 0          ; Number of hidden sectors (not applicable for floppy disks, so 0).
bpbTotalSectorsBig: DD 0          ; Total sectors for large disks (not used for floppies, set to 0).
bsDriveNumber:      DB 0          ; BIOS drive number (0 for floppy drive A:).
bsUnused:           DB 0          ; Unused byte (padding).
bsExtBootSignature: DB 0x29       ; Extended boot signature (0x29 indicates that serial number, label, and system ID are present).
bsSerialNumber:     DD 0xa0a1a2a3 ; A random serial number for the disk (4 bytes).
bsVolumeLabel:      DB "MOS FLOPPY " ; The volume label for the disk (11 bytes, padded with spaces).
bsFileSystem:       DB "FAT12   " ; The file system type, which is FAT12 (8 bytes, padded with spaces).

msg db "Welcome to GovernOs!", 0  ; The string to display on boot, followed by a null terminator (0).

;***************************************
; Prints a string (null-terminated)
; DS=>SI: Points to the string
;***************************************
Print:
            lodsb                 ; Load the next byte from the string (pointed to by SI) into AL.
            or al, al             ; Check if AL is 0 (null terminator).
            jz PrintDone          ; If AL is 0, jump to the end (done printing).
            mov ah, 0eh           ; BIOS interrupt function to print a character (0x0E).
            int 10h               ; Call BIOS interrupt 10h to print the character in AL.
            jmp Print             ; Loop back and print the next character.
PrintDone:
            ret                   ; Return from the print function when done.

;*************************************************;
; Bootloader Entry Point
;*************************************************;
loader:

    xor ax, ax         ; Clear AX register to 0.
    mov ds, ax         ; Set the data segment (DS) to 0. We are at memory address 0x7C00.
    mov es, ax         ; Set the extra segment (ES) to 0. Addresses are relative to 0x7C00.

    mov si, msg        ; Load the address of the message string into SI.
    call Print         ; Call the print function to display the message.

    xor ax, ax         ; Clear AX register.
    int 0x12           ; BIOS interrupt to get the amount of installed memory (in kilobytes).

    cli                ; Disable interrupts (clear interrupt flag).
    hlt                ; Halt the system (wait for hardware reset or power off).

times 510 - ($-$$) db 0 ; Fill the remaining space up to 510 bytes with zeros, to pad the bootloader to 512 bytes.

dw 0xAA55             ; Boot signature (0xAA55), required for BIOS to recognize the bootloader as valid.
