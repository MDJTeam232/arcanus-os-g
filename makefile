.PHONY: help build clean download-mint remaster verify

# Base OS Isolation Parameters
DEBIAN_VERSION := 12.9.0
ARCH           ?= amd64
# Corrected URL to point to a valid Debian netinst ISO
MINT_ISO       := debian-$(DEBIAN_VERSION)-$(ARCH)-netinst.iso
MINT_URL       := https://cdimage.debian.org/debian-cd/current/$(ARCH)/iso-cd/$(MINT_ISO)

# Updated to match standard build expectations
DIST_DIR       := output
SCRIPTS_DIR    := scripts

help:
	@echo ""
	@echo "╔════════════════════════════════════════╗"
	@echo "║      Arcanus OS Build System           ║"
	@echo "║      (Debian 12 Remaster Platform)     ║"
	@echo "╚════════════════════════════════════════╝"
	@echo ""
	@echo "Commands:"
	@echo "  make verify          Check repository structure"
	@echo "  make download-mint   Download Debian $(DEBIAN_VERSION) ($(ARCH)) Base ISO"
	@echo "  make remaster        Build remastered ISO with Arcanus branding"
	@echo "  make clean           Remove build artifacts"
	@echo "  make help            Show this help message"
	@echo ""

verify:
	@echo "✅ Checking Arcanus OS repository structure..."
	@[ -d branding ] && echo "  ✓ branding/" || (echo "  ✗ branding/ (create & add assets)" && false)
	@[ -d scripts ] && echo "  ✓ scripts/" || (echo "  ✗ scripts/" && false)
	@[ -f scripts/remaster-iso.sh ] && echo "  ✓ scripts/remaster-iso.sh" || (echo "  ✗ scripts/remaster-iso.sh" && false)
	@echo "✅ Structure validated!"

download-mint:
	@echo "📥 Downloading Debian $(DEBIAN_VERSION) Stable Core Base ($(ARCH))..."
	@wget --progress=bar:force -O $(MINT_ISO) "$(MINT_URL)" || (echo "❌ Download failed" && exit 1)
	@echo "✅ Downloaded: $(MINT_ISO)"

remaster: verify $(MINT_ISO)
	@echo "🔧 Remastering Core Image Layers..."
	@chmod +x $(SCRIPTS_DIR)/remaster-iso.sh
	@mkdir -p $(DIST_DIR)
	@echo "⚠️  This requires sudo access for mounting/chroot operations"
	@sudo $(SCRIPTS_DIR)/remaster-iso.sh $(MINT_ISO) $(DIST_DIR)
	@if [ -f $(DIST_DIR)/arcanus-os-live-$(ARCH).iso ]; then \
		echo "✅ ISO ready: $(DIST_DIR)/arcanus-os-live-$(ARCH).iso"; \
	else \
		echo "❌ ISO not found in $(DIST_DIR)! Check script output."; \
	fi

clean:
	@echo "🧹 Cleaning build workspace..."
	@sudo rm -rf build_env/ .work/ 2>/dev/null || true
	@rm -f $(MINT_ISO)
	@rm -rf $(DIST_DIR)
	@echo "✅ Clean complete"

.DEFAULT_GOAL := help
