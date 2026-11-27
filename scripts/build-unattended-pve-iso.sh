#!/usr/bin/env bash
# ==============================================================================
# Build Unattended Proxmox VE ISO
# Embeds answer.toml into a standard Proxmox VE 8.x ISO for zero-touch installation.
#
# Usage:
#   ./build-unattended-pve-iso.sh <SOURCE_PVE_ISO> [ANSWER_FILE] [OUTPUT_ISO]
# Example:
#   ./build-unattended-pve-iso.sh proxmox-ve_8.2-1.iso iso/pve-answer.toml proxmox-unattended.iso
# ==============================================================================

set -euo pipefail

SOURCE_ISO="${1:-}"
ANSWER_FILE="${2:-iso/pve-answer.toml}"
OUTPUT_ISO="${3:-proxmox-ve-unattended.iso}"

if [ -z "$SOURCE_ISO" ] || [ ! -f "$SOURCE_ISO" ]; then
  echo "Error: Source Proxmox ISO file not found."
  echo "Usage: $0 <path-to-proxmox-ve.iso> [answer.toml] [output.iso]"
  exit 1
fi

if [ ! -f "$ANSWER_FILE" ]; then
  echo "Error: Answer file '$ANSWER_FILE' not found."
  exit 1
fi

echo "========================================================================"
echo " Building Unattended Proxmox VE Installer"
echo " Source ISO:  $SOURCE_ISO"
echo " Answer File: $ANSWER_FILE"
echo " Output ISO:  $OUTPUT_ISO"
echo "========================================================================"

# Check if official proxmox-auto-install-assistant is available
if command -v proxmox-auto-install-assistant >/dev/null 2>&1; then
  echo "==> Using official proxmox-auto-install-assistant..."
  proxmox-auto-install-assistant prepare-iso "$SOURCE_ISO" \
    --answer-file "$ANSWER_FILE" \
    --output "$OUTPUT_ISO"
  echo "==> Done! Output ISO generated at: $OUTPUT_ISO"
  exit 0
fi

echo "==> 'proxmox-auto-install-assistant' not found in path."
echo "==> Using portable xorriso injection method..."

TMP_DIR="$(mktemp -d /tmp/pve-iso-build.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "--> Extracting MBR template and partition table from source ISO..."
xorriso -osirrox on -indev "$SOURCE_ISO" -extract / "$TMP_DIR/extracted"

echo "--> Copying answer file into installer root..."
mkdir -p "$TMP_DIR/extracted"
cp "$ANSWER_FILE" "$TMP_DIR/extracted/answer.toml"

echo "--> Repacking ISO with embedded answer.toml..."
xorriso -as mkisofs \
  -r -V 'PVE_UNATTENDED' \
  -o "$OUTPUT_ISO" \
  -J -joliet-long \
  -b boot/grub/i386-pc/eltorito.img \
  -c boot.catalog \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  --eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  "$TMP_DIR/extracted"

echo "========================================================================"
echo " Successfully generated unattended ISO: ${OUTPUT_ISO}"
echo " Flash this ISO to a USB flash drive using dd or Balena Etcher:"
echo "   sudo dd if=${OUTPUT_ISO} of=/dev/sdX bs=4M status=progress conv=fsync"
echo " Plug into the target PC, boot from USB, and the installation is automatic!"
echo "========================================================================"
