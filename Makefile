# Paths
SRC_DIR = src/bootloader
BUILD_DIR = build

# Files
BOOTLOADER = $(BUILD_DIR)/Boot1.bin
STAGE2 = $(BUILD_DIR)/KRNLDR.SYS
DISK_IMAGE = disk.img

# Commands
NASM = nasm
DD = dd
MKFS_FAT = mkfs.fat
MCOPY = mcopy
QEMU = qemu-system-i386

# QEMU Parameters
QEMU_FLAGS = -machine q35 -fda $(DISK_IMAGE) -gdb tcp::26000 -S

# Assemble the bootloader and Stage2
all: $(DISK_IMAGE)

$(BOOTLOADER): $(SRC_DIR)/bootloader.asm
	mkdir -p $(BUILD_DIR)
	$(NASM) -f bin $< -o $@

$(STAGE2): $(SRC_DIR)/Stage2.asm
	mkdir -p $(BUILD_DIR)
	$(NASM) -f bin $< -o $@

# Create an empty disk image, format it as FAT12, and copy files
$(DISK_IMAGE): $(BOOTLOADER) $(STAGE2)
	# Create an empty disk image (1.44MB floppy)
	$(DD) if=/dev/zero of=$(DISK_IMAGE) bs=512 count=2880

	# Format the disk image as FAT12
	$(MKFS_FAT) -F 12 -n "MOS FLOPPY" $(DISK_IMAGE)

	# Write specific parts of Boot1.bin to the disk image to mimic PARTCOPY
	# Copy first 3 bytes to offset 0
	$(DD) if=$(BOOTLOADER) of=$(DISK_IMAGE) bs=1 count=3 seek=0 conv=notrunc

	# Copy bytes from offset 62 (0x3E) for 450 bytes (0x1C2) to offset 62 on the disk image
	$(DD) if=$(BOOTLOADER) of=$(DISK_IMAGE) bs=1 count=450 skip=62 seek=62 conv=notrunc

	# Copy KRNLDR.SYS into the disk image using mcopy
	$(MCOPY) -i $(DISK_IMAGE) $(STAGE2) ::

# Run QEMU
run: all
	$(QEMU) $(QEMU_FLAGS)

# Clean the build directory and disk image
clean:
	rm -rf $(BUILD_DIR) $(DISK_IMAGE)
