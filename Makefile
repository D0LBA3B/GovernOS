# Paths
SRC_DIR = src/bootloader
BUILD_DIR = build

# Files
BOOTLOADER = $(BUILD_DIR)/bootloader
DISK_IMAGE = disk.img

# Commands
NASM = nasm
DD = dd
QEMU = qemu-system-i386

# QEMU Parameters
QEMU_FLAGS = -machine q35 -fda $(DISK_IMAGE) -gdb tcp::26000 -S

# Assemble the bootloader
all: $(DISK_IMAGE)

$(BOOTLOADER): $(SRC_DIR)/bootloader.asm
	mkdir -p $(BUILD_DIR)
	$(NASM) -f bin $< -o $@

# Create an empty disk image and write the bootloader to it
$(DISK_IMAGE): $(BOOTLOADER)
	$(DD) if=/dev/zero of=$(DISK_IMAGE) bs=512 count=2880
	$(DD) conv=notrunc if=$(BOOTLOADER) of=$(DISK_IMAGE) bs=512 count=1 seek=0

# Run QEMU
run: all
	$(QEMU) $(QEMU_FLAGS)

# Clean the build directory and disk image
clean:
	rm -rf $(BUILD_DIR) $(DISK_IMAGE)
