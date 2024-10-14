bits 16                         ; We are still in 16-bit Real Mode, as BIOS starts the bootloader in this mode.

org 0                           ; The BIOS loads the bootloader at memory address 0x7C00, so we set the origin to this address.

start: 
    jmp main                    ; Jump over the OEM block to the actual loader code.

;*************************************************;
;  OEM Parameter block (BIOS Parameter Block - BPB)
;*************************************************;

; This section contains the BIOS Parameter Block (BPB), which provides information about the disk layout.

bpbOEM          db "GovernOs "   ; The OEM name for the operating system, 8 bytes, required by FAT12/FAT16.

bpbBytesPerSector:   DW 512      ; Number of bytes per sector (512 bytes in this case).
bpbSectorsPerCluster: DB 1       ; Number of sectors per cluster (1 sector per cluster).
bpbReservedSectors:  DW 1        ; Number of reserved sectors (the first sector, the boot sector).
bpbNumberOfFATs:     DB 2        ; Number of File Allocation Tables (FATs) present (2 for redundancy).
bpbRootEntries:      DW 224      ; Maximum number of root directory entries (224 entries).
bpbTotalSectors:     DW 2880     ; Total number of sectors on the disk (for a 1.44MB floppy, this is 2880).
bpbMedia:           DB 0xF0      ; Media descriptor byte (0xF0 indicates a 1.44MB floppy disk).
bpbSectorsPerFAT:   DW 9         ; Number of sectors per FAT (9 sectors per FAT for a 1.44MB floppy).
bpbSectorsPerTrack: DW 18        ; Number of sectors per track (18 sectors per track on a floppy disk).
bpbHeadsPerCylinder: DW 2        ; Number of heads per cylinder (2 heads on a floppy disk).
bpbHiddenSectors:   DD 0         ; Number of hidden sectors (not applicable for floppy disks, so 0).
bpbTotalSectorsBig: DD 0         ; Total sectors for large disks (not used for floppies, set to 0).
bsDriveNumber:      DB 0         ; BIOS drive number (0 for floppy drive A:).
bsUnused:           DB 0         ; Unused byte (padding).
bsExtBootSignature: DB 0x29      ; Extended boot signature (0x29 indicates that serial number, label, and system ID are present).
bsSerialNumber:     DD 0xa0a1a2a3 ; A random serial number for the disk (4 bytes).
bsVolumeLabel:      DB "MOS FLOPPY " ; The volume label for the disk (11 bytes, padded with spaces).
bsFileSystem:       DB "FAT12   " ; The file system type, which is FAT12 (8 bytes, padded with spaces).

msg db "Welcome to GovernOs!", 0  ; The string to display on boot, followed by a null terminator (0).

;***************************************
; Prints a string (null-terminated)
; DS=>SI: Points to the string
;***************************************
Print:
    lodsb                        ; Load the next byte from the string (pointed to by SI) into AL.
    or al, al                    ; Check if AL is 0 (null terminator).
    jz PrintDone                 ; If AL is 0, jump to the end (done printing).
    mov ah, 0eh                  ; BIOS interrupt function to print a character (0x0E).
    int 10h                      ; Call BIOS interrupt 10h to print the character in AL.
    jmp Print                    ; Loop back and print the next character.
PrintDone:
    ret                          ; Return from the print function when done.

;************************************************;
; Reads a series of sectors using BIOS interrput 0x13
; CX => Number of sectors to read
; AX => Starting sector
; ES:BX => Buffer to read to
;************************************************;

ReadSectors:
    .MAIN
        mov     di, 0x0005                     ; Set error retry counter to 5
    .SECTORLOOP
        push    ax                             ; Save starting sector
        push    bx                             ; Save buffer pointer
        push    cx                             ; Save number of sectors to read
        call    LBACHS                         ; Convert starting sector from LBA to CHS (Cylinder-Head-Sector)
        mov     ah, 0x02                       ; BIOS interrupt function to read disk sectors
        mov     al, 0x01                       ; We are reading one sector
        mov     ch, BYTE [absoluteTrack]       ; Load the track number (CHS - Cylinder)
        mov     cl, BYTE [absoluteSector]      ; Load the sector number (CHS - Sector)
        mov     dh, BYTE [absoluteHead]        ; Load the head number (CHS - Head)
        mov     dl, BYTE [bsDriveNumber]       ; Load the drive number (floppy or hard drive)
        int     0x13                           ; Call BIOS interrupt to read sector
        jnc     .SUCCESS                       ; Jump to SUCCESS if no error (carry flag is clear)
        xor     ax, ax                         ; If an error occurred, reset disk
        int     0x13                           ; BIOS reset disk interrupt
        dec     di                             ; Decrement retry counter
        pop     cx                             ; Restore number of sectors
        pop     bx                             ; Restore buffer pointer
        pop     ax                             ; Restore starting sector
        jnz     .SECTORLOOP                    ; Retry if counter is not zero
        int     0x18                           ; If retries are exhausted, invoke BIOS reboot
    .SUCCESS
        mov     si, msgProgress                ; Load progress message into SI
        call    Print                          ; Print the progress message
        pop     cx                             ; Restore number of sectors
        pop     bx                             ; Restore buffer pointer
        pop     ax                             ; Restore starting sector
        add     bx, WORD [bpbBytesPerSector]   ; Move the buffer pointer for the next sector
        inc     ax                             ; Increment starting sector
        loop    .MAIN                          ; Repeat for remaining sectors
        ret                                    ; Return from the function

;************************************************;
; Convert CHS to LBA (Logical Block Addressing)
; LBA = (cluster - 2) * sectors per cluster
;************************************************;

ClusterLBA:
    sub     ax, 0x0002                     ; Adjust the cluster number to a zero-based cluster number
    xor     cx, cx                         ; Clear CX to use it in the multiplication
    mov     cl, BYTE [bpbSectorsPerCluster]; Load sectors per cluster (from BPB)
    mul     cx                             ; Multiply AX by sectors per cluster (AX = AX * CX)
    add     ax, WORD [datasector]          ; Add the base data sector to AX
    ret                                    ; Return from the function

;************************************************;
; Convert LBA to CHS (Cylinder-Head-Sector)
; AX => LBA Address to convert
;
; absolute sector = (logical sector / sectors per track) + 1
; absolute head   = (logical sector / sectors per track) MOD number of heads
; absolute track  = logical sector / (sectors per track * number of heads)
;************************************************;

LBACHS:
    xor     dx, dx                         ; Clear DX (prepare for division)
    div     WORD [bpbSectorsPerTrack]      ; Divide AX by the number of sectors per track
    inc     dl                             ; Increment DL for 1-based sector number (sectors start from 1, not 0)
    mov     BYTE [absoluteSector], dl      ; Store sector number in absoluteSector variable
    xor     dx, dx                         ; Clear DX for the next division
    div     WORD [bpbHeadsPerCylinder]     ; Divide AX by the number of heads per cylinder
    mov     BYTE [absoluteHead], dl        ; Store head number in absoluteHead variable
    mov     BYTE [absoluteTrack], al       ; Store track (cylinder) number in absoluteTrack variable
    ret                                    ; Return from the function

;*************************************************;
; Bootloader Entry Point
;*************************************************;
main:
    mov     si, msg                        ; Load the address of the message string into SI.
    call    Print                          ; Call the print function to display the message.
    cli                                   ; Disable interrupts

    ;----------------------------------------------------
    ; Setup segment registers at 0000:07C00
    ;----------------------------------------------------
    mov     ax, 0x07C0                    ; Load segment address (0x07C0:0000 = 0x7C00 in memory)
    mov     ds, ax                        ; Set the data segment
    mov     es, ax                        ; Set the extra segment
    mov     fs, ax                        ; Set fs segment
    mov     gs, ax                        ; Set gs segment

    ;----------------------------------------------------
    ; Create stack
    ;----------------------------------------------------
    mov     ax, 0x0000                    ; Load the segment value 0x0000 into AX. This sets the stack segment (SS) to start at address 0x0000.
    mov     ss, ax                        ; Set the stack segment register (SS) to the value in AX (0x0000). This means that the stack will operate within the memory segment starting at address 0x0000.
    mov     sp, 0xFFFF                    ; Set the stack pointer (SP) to 0xFFFF.
                                          ; This places the stack pointer at the highest address within the segment (0x0000:FFFF).
                                          ; The stack grows downwards in memory, so starting at 0xFFFF gives the stack space to grow as data is pushed onto it.

    sti                                   ; Restore interrupts

    ; Loading message
    mov     si, msgLoading
    call    Print

    xor     ax, ax                        ; Clear AX register.
    int     0x12                          ; BIOS interrupt to get the amount of installed memory (in kilobytes).

    LOAD_ROOT:
        ; compute size of root directory and store in "cx"
        xor     cx, cx
        xor     dx, dx
        mov     ax, 0x0020                    ; 32 byte directory entry
        mul     WORD [bpbRootEntries]         ; total size of directory
        div     WORD [bpbBytesPerSector]      ; sectors used by directory
        xchg    ax, cx

        ; compute location of root directory and store in "ax"
        mov     al, BYTE [bpbNumberOfFATs]    ; number of FATs
        mul     WORD [bpbSectorsPerFAT]       ; sectors used by FATs
        add     ax, WORD [bpbReservedSectors] ; adjust for bootsector
        mov     WORD [datasector], ax         ; base of root directory
        add     WORD [datasector], cx

        ; read root directory into memory (7C00:0200)
        mov     bx, 0x0200                    ; copy root dir above bootcode
        call    ReadSectors

        ;----------------------------------------------------
        ; Find stage 2
        ;----------------------------------------------------

        ; browse root directory for binary image
        mov     cx, WORD [bpbRootEntries]     ; load loop counter
        mov     di, 0x0200                    ; locate first root entry
    .LOOP:
        push    cx
        mov     cx, 0x000B                    ; eleven character name
        mov     si, ImageName                 ; image name to find
        push    di
        rep     cmpsb                         ; test for entry match
        pop     di
        je      LOAD_FAT
        pop     cx
        add     di, 0x0020                    ; queue next directory entry
        loop    .LOOP
        jmp     FAILURE

        ;----------------------------------------------------
        ; Load FAT
        ;----------------------------------------------------

    LOAD_FAT:

        ; save starting cluster of boot image

        mov     si, msgCRLF
        call    Print
        mov     dx, WORD [di + 0x001A]
        mov     WORD [cluster], dx            ; file's first cluster

        ; compute size of FAT and store in "cx"

        xor     ax, ax
        mov     al, BYTE [bpbNumberOfFATs]    ; number of FATs
        mul     WORD [bpbSectorsPerFAT]       ; sectors used by FATs
        mov     cx, ax

        ; compute location of FAT and store in "ax"

        mov     ax, WORD [bpbReservedSectors] ; adjust for bootsector

        ; read FAT into memory (7C00:0200)

        mov     bx, 0x0200                    ; copy FAT above bootcode
        call    ReadSectors

        ; read image file into memory (0050:0000)

        mov     si, msgCRLF
        call    Print
        mov     ax, 0x0050
        mov     es, ax                        ; destination for image
        mov     bx, 0x0000                    ; destination for image
        push    bx

        ;----------------------------------------------------
        ; Load Stage 2
        ;----------------------------------------------------

    LOAD_IMAGE:

        mov     ax, WORD [cluster]            ; cluster to read
        pop     bx                            ; buffer to read into
        call    ClusterLBA                    ; convert cluster to LBA
        xor     cx, cx
        mov     cl, BYTE [bpbSectorsPerCluster] ; sectors to read
        call    ReadSectors
        push    bx

        ; compute next cluster

        mov     ax, WORD [cluster]            ; identify current cluster
        mov     cx, ax                        ; copy current cluster
        mov     dx, ax                        ; copy current cluster
        shr     dx, 0x0001                    ; divide by two
        add     cx, dx                        ; sum for (3/2)
        mov     bx, 0x0200                    ; location of FAT in memory
        add     bx, cx                        ; index into FAT
        mov     dx, WORD [bx]                 ; read two bytes from FAT
        test    ax, 0x0001
        jnz     .ODD_CLUSTER

    .EVEN_CLUSTER:

        and     dx, 0000111111111111b         ; take low twelve bits
        jmp     .DONE

    .ODD_CLUSTER:

        shr     dx, 0x0004                    ; take high twelve bits

    .DONE:

        mov     WORD [cluster], dx            ; store new cluster
        cmp     dx, 0x0FF0                    ; test for end of file
        jb      LOAD_IMAGE

    DONE:

        mov     si, msgCRLF
        call    Print
        push    WORD 0x0050
        push    WORD 0x0000
        retf

    FAILURE:

        mov     si, msgFailure
        call    Print
        mov     ah, 0x00
        int     0x16                          ; await keypress
        int     0x19                          ; warm boot computer

    absoluteSector db 0x00
    absoluteHead   db 0x00
    absoluteTrack  db 0x00

    datasector  dw 0x0000
    cluster     dw 0x0000
    ImageName   db "KRNLDR  SYS"
    msgLoading  db 0x0D, 0x0A, "Loading Boot Image ", 0x00
    msgCRLF     db 0x0D, 0x0A, 0x00
    msgProgress db ".", 0x00
    msgFailure  db 0x0D, 0x0A, "GOVERROR : Press Any Key to Reboot", 0x0A, 0x00

        times 510 - ($-$$) db 0                 ; Fill the remaining space up to 510 bytes with zeros, to pad the bootloader to 512 bytes.
        dw 0xAA55                               ; Boot signature (0xAA55), required for BIOS to recognize the bootloader as valid.