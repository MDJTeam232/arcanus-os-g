# ==============================================================================
#                      ARCANUS OS GENERATOR (DEBIAN 12 RE-ENGINEERED)
# ==============================================================================

# Core Build Parameters
ARCH            ?= arm64
DEBIAN_VER      := 12.9.0
ISO_NAME        := arcanus-os-live-$(ARCH).iso

# Mirror Paths (Fallback to amd64 if specified via ARCH=amd64)
ifeq ($(ARCH),arm64)
	ISO_URL := https://debian.org
else
	ISO_URL := https://debian.org
endif

# Working Build Directories
WORKSPACE       := $(shell pwd)
BUILD_DIR       := $(WORKSPACE)/build_env
ISO_EXTRACT     := $(BUILD_DIR)/iso_root
SQUASH_EXTRACT  := $(BUILD_DIR)/squashfs_root
OUTPUT_DIR      := $(WORKSPACE)/output

.PHONY: all clean init download-base extract patch compile

all: init download-base extract patch compile

init:
	@echo "⚙️ Initializing clean build workspace tracking states..."
	mkdir -p $(BUILD_DIR) $(ISO_EXTRACT) $(SQUASH_EXTRACT) $(OUTPUT_DIR)
	sudo apt-get update && sudo apt-get install -y squashfs-tools rsync xorriso syslinux isolinux wget

download-base:
	@if [ ! -f $(BUILD_DIR)/base.iso ]; then \
		echo "📥 Fetching Official Upstream Debian $(DEBIAN_VER) ($(ARCH)) Base Matrix..."; \
		wget -O $(BUILD_DIR)/base.iso $(ISO_URL); \
	fi

extract:
	@echo "🗜️ Ripping open base ISO structures..."
	# Mount and extract raw ISO content layers
	mkdir -p $(BUILD_DIR)/mnt
	sudo mount -o loop $(BUILD_DIR)/base.iso $(BUILD_DIR)/mnt
	rsync -a --exclude='live/filesystem.squashfs' $(BUILD_DIR)/mnt/ $(ISO_EXTRACT)/
	
	@echo "🗜️ Decompressing primary system filesystem squashfs..."
	if [ -f $(BUILD_DIR)/mnt/live/filesystem.squashfs ]; then \
		sudo unsquashfs -d $(SQUASH_EXTRACT) $(BUILD_DIR)/mnt/live/filesystem.squashfs; \
	elif [ -f $(BUILD_DIR)/mnt/install.amd/initrd.gz ] || [ -f $(BUILD_DIR)/mnt/install.arm/initrd.gz ]; then \
		echo "🔄 Netinst layout detected. Structuring clean core base target filesystem..."; \
		sudo debootstrap --arch=$(ARCH) stable $(SQUASH_EXTRACT) http://debian.org; \
	fi
	sudo umount $(BUILD_DIR)/mnt
	rm -rf $(BUILD_DIR)/mnt

patch:
	@echo "🔒 Injecting Arcanus Workspace payload files and dconf locks..."
	# Transfer branding parameters directly into live system layers
	sudo mkdir -p $(SQUASH_EXTRACT)/usr/share/backgrounds/arcanus
	sudo mkdir -p $(SQUASH_EXTRACT)/etc/dconf/db/arcanus.d/locks
	sudo mkdir -p $(SQUASH_EXTRACT)/etc/dconf/profile
	
	sudo cp branding/wallpaper.png $(SQUASH_EXTRACT)/usr/share/backgrounds/arcanus/wallpaper.png
	sudo cp -r branding/icon-theme/* $(SQUASH_EXTRACT)/usr/share/icons/Arcanus/ || true
	
	# Execute your post-install customization script inside the isolated image jail
	sudo cp scripts/customize.sh $(SQUASH_EXTRACT)/tmp/customize.sh
	sudo chmod +x $(SQUASH_EXTRACT)/tmp/customize.sh
	sudo mount --bind /dev $(SQUASH_EXTRACT)/dev
	sudo mount --bind /run $(SQUASH_EXTRACT)/run
	sudo chroot $(SQUASH_EXTRACT) /bin/bash /tmp/customize.sh
	
	# Clean up bind mounts securely after jail execution loop closes
	sudo umount $(SQUASH_EXTRACT)/dev
	sudo umount $(SQUASH_EXTRACT)/run
	sudo rm -f $(SQUASH_EXTRACT)/tmp/customize.sh

compile:
	@echo "📦 Re-compressing isolated secure Arcanus filesystem layer..."
	sudo rm -f $(ISO_EXTRACT)/live/filesystem.squashfs
	mkdir -p $(ISO_EXTRACT)/live
	sudo mksquashfs $(SQUASH_EXTRACT) $(ISO_EXTRACT)/live/filesystem.squashfs -comp xz -e boot
	
	@echo "💿 Compiling custom production Arcanus bootable ISO artifact..."
	sudo xorriso -as mkisofs -r -V "ARCANUS_OS" \
		-o $(OUTPUT_DIR)/$(ISO_NAME) \
		-J -joliet-long -b isolinux/isolinux.bin \
		-c isolinux/boot.cat -no-emul-boot \
		-boot-load-size 4 -boot-info-table $(ISO_EXTRACT)
	@echo "🎉 Build production run complete! ISO ready at output/$(ISO_NAME)"

clean:
	@echo "🧹 Flushing dirty working caches..."
	sudo rm -rf $(BUILD_DIR) $(OUTPUT_DIR)
