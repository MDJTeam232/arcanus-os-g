name: Build Arcanus OS ISO

on:
  workflow_dispatch:
    inputs:
      iso_url:
        description: 'Linux Mint ISO download URL (optional)'
        required: false
        default: ''
  push:
    branches:
      - main
    paths:
      - 'branding/**'
      - 'theme/**'
      - 'scripts/**'
      - '.github/workflows/build-iso.yml'

permissions:
  contents: read
  actions: write

jobs:
  build-iso:
    name: Remaster Linux Mint with Arcanus Branding
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            wget \
            squashfs-tools \
            xorriso \
            rsync \
            sudo

      - name: Download Linux Mint 22 ISO
        run: |
          mkdir -p downloads
          
          # Use working UKFast mirror
          ISO_URL="https://mirrors.ukfast.co.uk/sites/linuxmint.com/isos/stable/22.3/linuxmint-22.3-cinnamon-64bit.iso"
          
          echo "📥 Downloading Linux Mint 22.3 Cinnamon from UKFast mirror..."
          wget -O downloads/linuxmint-22-64bit.iso "$ISO_URL" --progress=bar:force:noscroll --timeout=120
          
          echo "✅ Download complete"
          ls -lh downloads/

      - name: Build Arcanus OS ISO
        run: |
          chmod +x scripts/remaster-iso.sh
          mkdir -p dist
          
          ISO_FILE=$(ls downloads/*.iso 2>/dev/null | head -1)
          
          if [ -z "$ISO_FILE" ]; then
            echo "❌ No ISO file found in downloads/"
            exit 1
          fi
          
          echo "🔧 Remastering: $ISO_FILE"
          sudo bash ./scripts/remaster-iso.sh "$ISO_FILE" dist/

      - name: Verify ISO
        run: |
          echo "📋 Verifying output..."
          ls -lh dist/
          file dist/arcanus-os-demo.iso

      - name: Upload ISO artifact
        uses: actions/upload-artifact@v4
        with:
          name: arcanus-os-demo-iso
          path: dist/arcanus-os-demo.iso
          retention-days: 30

      - name: Create release (on tag)
        if: startsWith(github.ref, 'refs/tags/v')
        uses: softprops/action-gh-release@v1
        with:
          files: dist/arcanus-os-demo.iso
          body: |
            # Arcanus OS ${{ github.ref_name }}
            
            **Linux Mint 22.3 Cinnamon** remastered with Arcanus branding.
            
            ## What's Included
            - Full Linux Mint 22.3 functionality
            - Arcanus visual branding (logo, wallpaper, icons)
            - Pre-installed Arcanus Ledger
            - Ready to test in VirtualBox/QEMU
            
            ## Quick Test
            ```bash
            qemu-system-x86_64 -cdrom arcanus-os-demo.iso -m 4G -smp 2
            ```
            
            ## Build Info
            - Built: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
            - Commit: ${{ github.sha }}
