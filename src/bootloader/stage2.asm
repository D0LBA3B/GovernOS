org 0x0					        ; offset to 0, we will set segments later

bits 16					        ; we are still in real mode

jmp main				        ; jump to main

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
;	Second Stage Loader Entry Point
;************************************************;

main:
	cli             ; clear interrupts
	push    cs		; Insure DS=CS
	pop     ds
	mov     si, Msg
    call    Print   ; Print the progress message

	cli     ; clear interrupts to prevent triple faults
	hlt     ; hault the syst

;*************************************************;
;	Data Section TODO
;************************************************;
Msg	db	"Preparing to load operating system...",13,10,0