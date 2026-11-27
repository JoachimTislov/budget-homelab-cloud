#!/usr/bin/env bash
# ==============================================================================
# Proxmox VE Debian 12 Cloud-Init Template Creator
# Purpose: Automatically creates a gold-master cloud-init VM template (VMID 9000)
#          that can be cloned in 5 seconds to spin up new k3s or Coolify nodes.
# Run on: Proxmox VE Host as root
# ==============================================================================

set -euo pipefail

VMID="${1:-9000}"
VM_NAME="${2:-debian-12-cloudinit-template}"
STORAGE_POOL="${3:-local-lvm}"  # or local-zfs

echo "==> [1/6] Installing libguestfs-tools..."
apt-get update -qq && apt-get install -y libguestfs-tools -qq

echo "==> [2/6] Downloading latest Debian 12 generic cloud image..."
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
IMAGE_FILE="/tmp/debian-12-generic-amd64.qcow2"
wget -q --show-progress "$IMAGE_URL" -O "$IMAGE_FILE"

echo "==> [3/6] Installing qemu-guest-agent into the image..."
virt-customize -a "$IMAGE_FILE" --install qemu-guest-agent

echo "==> [4/6] Creating Proxmox VM shell (VMID: $VMID)..."
# Destroy existing template if it exists
qm destroy "$VMID" 2>/dev/null || true

qm create "$VMID" --name "$VM_NAME" \
  --memory 2048 --cores 2 --cpu host \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci

echo "==> [5/6] Importing disk into storage pool ($STORAGE_POOL)..."
qm importdisk "$VMID" "$IMAGE_FILE" "$STORAGE_POOL"
qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "${STORAGE_POOL}:vm-${VMID}-disk-0"
qm set "$VMID" --boot c --bootdisk scsi0
qm set "$VMID" --ide2 "${STORAGE_POOL}:cloudinit"
qm set "$VMID" --serial0 socket --vga serial0
qm set "$VMID" --agent enabled=1

echo "==> [6/6] Converting VM to template..."
qm template "$VMID"
rm -f "$IMAGE_FILE"

echo "========================================================================"
echo " Cloud-Init Template created successfully!"
echo " Template VM ID: ${VMID} (${VM_NAME})"
echo " You can now clone this VM from the GUI or CLI:"
echo "   qm clone ${VMID} 101 --name k3s-master-01 --full"
echo "========================================================================"
