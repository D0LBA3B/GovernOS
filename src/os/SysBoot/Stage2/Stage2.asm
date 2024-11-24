org 0x500
bits 16					        ; we are still in real mode
jmp main				        ; jump to main

;*******************************************************
;	Preprocessor directives
;*******************************************************

%include "stdio.inc"            ; basic i/o routines
%include "Gdt.inc"			    ; Gdt routines
%include "A20.inc"			    ; A20 enabling
%include "Fat12.inc"			; FAT12 driver. Kinda :)
%include "Common.inc"
%include "bootinfo.inc"
%include "memory.inc"

;*******************************************************
;	Data Section
;*******************************************************
LoadingMsg db 0x0D, 0x0A, "Searching for Operating System...", 0x00
msgFailure db 0x0D, 0x0A, "*** FATAL: Missing or corrupt KRNL32. Press Any Key to Reboot.", 0x0D, 0x0A, 0x0A, 0x00

boot_info:
istruc multiboot_info
	at multiboot_info.flags,			    dd 0
	at multiboot_info.memoryLo,			    dd 0
	at multiboot_info.memoryHi,			    dd 0
	at multiboot_info.bootDevice,		    dd 0
	at multiboot_info.cmdLine,			    dd 0
	at multiboot_info.mods_count,		    dd 0
	at multiboot_info.mods_addr,		    dd 0
	at multiboot_info.syms0,			    dd 0
	at multiboot_info.syms1,			    dd 0
	at multiboot_info.syms2,			    dd 0
	at multiboot_info.mmap_length,		    dd 0
	at multiboot_info.mmap_addr,		    dd 0
	at multiboot_info.drives_length,	    dd 0
	at multiboot_info.drives_addr,		    dd 0
	at multiboot_info.config_table,		    dd 0
	at multiboot_info.bootloader_name,	    dd 0
	at multiboot_info.apm_table,		    dd 0
	at multiboot_info.vbe_control_info,	    dd 0
	at multiboot_info.vbe_mode_info,	    dw 0
	at multiboot_info.vbe_interface_seg,	dw 0
	at multiboot_info.vbe_interface_off,	dw 0
	at multiboot_info.vbe_interface_len,    dw 0
iend

main:
	;-------------------------------;
	;   Setup segments and stack	;
	;-------------------------------;
	cli	                       ; clear interrupts
	xor		ax, ax             ; null segments
	mov		ds, ax
	mov		es, ax
	mov		ax, 0x0000         ; stack begins at 0x9000-0xffff
	mov		ss, ax
	mov		sp, 0xFFFF
	sti	                       ; enable interrupts

	mov     	[boot_info+multiboot_info.bootDevice], dl
	call		_EnableA20
	call		InstallGDT
	sti
	xor		eax, eax
	xor		ebx, ebx
	call		BiosGetMemorySize64MB
	push		eax
	mov		eax, 64
	mul		ebx
	mov		ecx, eax
	pop		eax
	add		eax, ecx
	add		eax, 1024		; the routine doesnt add the KB between 0-1MB; add it
	mov		dword [boot_info+multiboot_info.memoryHi], 0
	mov		dword [boot_info+multiboot_info.memoryLo], eax
	mov		eax, 0x0
	mov		ds, ax
	mov		di, 0x1000
	call		BiosGetMemoryMap
	call		LoadRoot
   	mov    		ebx, 0
   	mov		ebp, IMAGE_RMODE_BASE
   	mov 	   	esi, ImageName
	call		LoadFile		; load our file
   	mov   		dword [ImageSize], ecx
	cmp		ax, 0
	je		EnterStage3
	mov		si, msgFailure
	call   		Puts16
	mov		ah, 0

	;-------------------------------;
	;   Go into pmode               ;
	;-------------------------------;

EnterStage3:
	cli	                           ; clear interrupts
	mov	eax, cr0                   ; set bit 0 in cr0--enter pmode
	or	eax, 1
	mov	cr0, eax
	jmp	CODE_DESC:Stage3                ; far jump to fix CS. Remember that the code selector is 0x8!
	; Note: Do NOT re-enable interrupts! Doing so will triple fault!
;******************************************************
;	ENTRY POINT FOR STAGE 3
;******************************************************
bits 32
%include "Paging.inc"
BadImage db "*** FATAL: Invalid or corrupt kernel image. Halting system.", 0

Stage3:
	;-------------------------------;
	;   Set registers				;
	;-------------------------------;
	mov	ax, DATA_DESC	   ; set data segments to data selector (0x10)
	mov	ds, ax
	mov	ss, ax
	mov	es, ax
	mov	esp, 9000h		   ; stack begins from 90000h
	call	ClrScr32
	call	EnablePaging

CopyImage:
  	 mov	eax, dword [ImageSize]
  	 movzx	ebx, word [bpbBytesPerSector]
  	 mul	ebx
  	 mov	ebx, 4
  	 div	ebx
   	 cld
   	 mov    esi, IMAGE_RMODE_BASE
   	 mov	edi, IMAGE_PMODE_BASE
   	 mov	ecx, eax
   	 rep	movsd                     ; copy image to its protected mode address

TestImage:
  	  mov    ebx, [IMAGE_PMODE_BASE+60]
  	  add    ebx, IMAGE_PMODE_BASE    ; ebx now points to file sig (PE00)
  	  mov    esi, ebx
  	  mov    edi, ImageSig
  	  cmpsw
  	  je     EXECUTE
  	  mov	ebx, BadImage
  	  call	Puts32
  	  cli
  	  hlt

ImageSig db 'PE'
EXECUTE:
	;---------------------------------------;
	;   Execute Kernel
	;---------------------------------------;
    ; parse the programs header info structures to get its entry point
	add		ebx, 24
	mov		eax, [ebx]			; _IMAGE_FILE_HEADER is 20 bytes + size of sig (4 bytes)
	add		ebx, 20-4			; address of entry point
	mov		ebp, dword [ebx]		; get entry point offset in code section	
	add		ebx, 12				; image base is offset 8 bytes from entry point
	mov		eax, dword [ebx]		; add image base
	add		ebp, eax
	cli
	mov		eax, 0x2badb002			; multiboot specs say eax should be this
	mov		ebx, 0
	mov		edx, [ImageSize]
	push		dword boot_info
	call		ebp               	      ; Execute Kernel
	add		esp, 4

    	cli
	hlt