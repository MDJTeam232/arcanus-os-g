.PHONY: help build clean download-mint remaster verify

MINT_VERSION ?= 22
MINT_ISO ?= linuxmint-$(MINT_VERSION)-cinnamon-64bit.iso
MINT_URL ?= https://mirrors.layeronline.com/linuxmint/stable/$(MINT_VERSION)/$(MINT_ISO)
DIST_DIR := dist
SCRIPTS_DIR := scripts

help:
	@echo ""
	@echo "╔════════════════════════════════════════╗"
	@echo "║     Arcanus OS Build System            ║"
	@echo "║     (Linux Mint Remaster)              ║"
	@echo "╚════════════════════════════════════════╝"
	@echo ""
	@echo "Commands:"
	@echo "  make verify          Check repository structure"
	@echo "  make download-mint   Download Linux Mint $(MINT_VERSION) ISO"
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
	@echo "📥 Downloading Linux Mint $(MINT_VERSION) Cinnamon (64-bit)..."
	@echo "   URL: $(MINT_URL)"
	@echo ""
	@wget -O $(MINT_ISO) "$(MINT_URL)" || (echo "❌ Download failed" && exit 1)
	@echo ""
	@echo "✅ Downloaded: $(MINT_ISO)"
	@ls -lh $(MINT_ISO)
	@echo ""

remaster: verify $(MINT_ISO)
	@echo "🔧 Remastering Linux Mint with Arcanus branding..."
	@echo ""
	@chmod +x $(SCRIPTS_DIR)/remaster-iso.sh
	@mkdir -p $(DIST_DIR)
	@echo "⚠️  This requires sudo access for mounting/chroot"
	@echo ""
	@sudo $(SCRIPTS_DIR)/remaster-iso.sh $(MINT_ISO) $(DIST_DIR)
	@echo ""
	@ls -lh $(DIST_DIR)/arcanus-os-demo.iso 2>/dev/null && echo "✅ ISO ready for testing!" || echo "⚠️  Build may require manual intervention"

clean:
	@echo "🧹 Cleaning build artifacts..."
	@sudo rm -rf .work/ 2>/dev/null || true
	@rm -f $(DIST_DIR)/*.log
	@echo "✅ Clean complete"

.DEFAULT_GOAL := help
