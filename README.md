# GovernOS
GovernOS is my very first operating system development project. I know the code can (or will) be crap, but the aim is to learn and improve along the way.

## Prerequisites (Ubuntu)
Make sure to install the following packages:
```bash
sudo apt install nasm
sudo apt install qemu-system-x86
sudo apt install libc6-dev-i386
sudo apt install binutils
sudo apt install make
```

## Example of compilation and execution with NASM/QEMU on the bootloader
```bash
nasm -f bin bootloader.asm -o bootloader
```

### Disk creation
```bash
dd if=/dev/zero of=disk.img bs=512 count=2880
```

### Write in sector
```bash
dd conv=notrunc if=bootloader of=disk.img bs=512 count=1 seek=0
```

### Launch in QUEMU
```bash
qemu-system-i386 -machine q35 -fda disk.img -gdb tcp::26000 -S
```

### Setup gdb (debugger) 
<i>Open a new terminal</i>
```bash
gdb
set architecture i8086
target remote localhost:26000

#Set-up a breakpoint
b *XXXXXX (b *0x7c00)

#View the assembly code + registers
layout asm
layout reg
```
