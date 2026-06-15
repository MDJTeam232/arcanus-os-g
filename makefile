.PHONY: help build clean download-mint remaster verify

# Base OS Isolation Parameters (Swapped from Mint to crisp Debian 12 Base Matrix)
DEBIAN_VERSION := 12.9.0
ARCH           ?= amd64
MINT_ISO       := debian-$(DEBIAN_VERSION)-$(ARCH)-netinst.iso
MINT_URL       := https://debian.org

DIST_DIR       := dist
SCRIPTS_DIR    := scripts

help:
	@echo ""
	@echo "╔════════════════════════════════════════╗"
	@echo "║     Arcanus OS Build System            ║"
	@echo "║     (Debian 12 Remaster Platform)      ║"
	@echo "╚════════════════════════════════════════╝"
	@echo ""
	@echo "Commands:"
	@echo "  make verify          Check repository structure"
	@echo "  make download-mint   Download Debian $(DEBIAN_VERSION) ($(ARCH)) Base ISO"
	@echo "  make remaster        Build remastered ISO with Arcanus branding"
	@echo "  make clean           Remove build artifacts"
	@echo "  make help            Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make verify && make download-mint && make remaster"
	@echo ""

verify:
	@echo "✅ Checking Arcanus OS repository structure..."
	@echo ""
	@[ -d branding ] && echo "  ✓ branding/" || (echo "  ✗ branding/ (create & add assets)" && false)
	@[ -d theme ] && echo "  ✓ theme/" || (echo "  ✗ theme/ (optional)" && false)
	@[ -d scripts ] && echo "  ✓ scripts/" || (echo "  ✗ scripts/" && false)
	@[ -f scripts/remaster-iso.sh ] && echo "  ✓ scripts/remaster-iso.sh" || (echo "  ✗ scripts/remaster-iso.sh" && false)
	@[ -f Makefile ] && echo "  ✓ Makefile" || (echo "  ✗ Makefile" && false)
	@[ -f README.md ] && echo "  ✓ README.md" || (echo "  ✗ README.md" && false)
	@echo ""
	@echo "✅ Structure validated!"
	@echo ""

download-mint:
	@echo "📥 Downloading Debian $(DEBIAN_VERSION) Stable Core Base ($(ARCH))..."
	@echo "   URL: $(MINT_URL)"
	@echo ""
	@wget --no-check-certificate --auth-no-challenge -O $(MINT_ISO) "$(MINT_URL)" || (echo "❌ Download failed" && exit 1)
	@echo ""
	@echo "✅ Downloaded: $(MINT_ISO)"
	@ls -lh $(MINT_ISO)
	@echo ""

remaster: verify $(MINT_ISO)
	@echo "🔧 Remastering Core Image Layers with Arcanus packaging..."
	@echo ""
	@chmod +x $(SCRIPTS_DIR)/remaster-iso.sh
	@mkdir -p $(DIST_DIR)
	@echo "⚠️  This requires sudo access for mounting/chroot operations"
	@echo ""
	@sudo $(SCRIPTS_DIR)/remaster-iso.sh $(MINT_ISO) $(DIST_DIR)
	@echo ""
	@ls -lh $(DIST_DIR)/arcanus-os-live-$(ARCH).iso 2>/dev/null && echo "✅ ISO ready for endpoint deployment flash testing!" || echo "⚠️  Build may require checkpoint manual intervention"

clean:
	@echo "🧹 Cleaning build workspace artifacts and cache layers..."
	@sudo rm -rf build_env/ 2>/dev/null || true
	@sudo rm -rf .work/ 2>/dev/null || true
	@rm -f $(MINT_ISO)
	@rm -rf $(DIST_DIR)
	@echo "✅ Clean complete"

.DEFAULT_GOAL := help
