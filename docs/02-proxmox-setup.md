# Proxmox VE (PVE) Hypervisor Setup & Optimization

Proxmox VE is an open-source enterprise virtualization platform combining KVM hypervisor and LXC containers on top of a battle-tested Debian base.

---

## 1. Installation

1. Download the latest Proxmox VE ISO (PVE 8.x) from [proxmox.com/en/downloads](https://www.proxmox.com/en/downloads).
2. Flash it to a USB drive using [Etcher](https://etcher.balena.io/) or `dd`:
   ```bash
   sudo dd if=proxmox-ve_8.x.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```
3. Boot the Mini-PC from the USB drive.
4. Select **Install Proxmox VE (Graphical)**.
5. **Target Harddisk**: Select your primary NVMe drive.
   - For single NVMe: Select `ext4` or `zfs (RAID0)`.
   - For dual drives (e.g. 2x NVMe or 2x SATA): Select `zfs (RAID1 / mirror)` for automatic disk redundancy.
6. **Network Configuration**:
   - Assign a static IP (e.g., `192.168.1.50/24`).
   - Set Gateway (`192.168.1.1`) and DNS (`1.1.1.1` or your router's IP).
   - Set FQDN (e.g., `pve-node1.home.arpa`).
7. Once finished, reboot and remove the USB installer. Access the web dashboard at:
   `https://192.168.1.50:8006`

---

## 2. Post-Install Automation & Optimization

Out of the box, Proxmox points to enterprise subscription repositories. You need to enable the free community repository and disable the enterprise warning.

SSH into your Proxmox node as `root` or open the Proxmox Web Shell, and run the automated script provided in this repo:

```bash
# Clone or copy the script to your PVE node
curl -fsSL https://raw.githubusercontent.com/.../scripts/pve-post-install.sh -o pve-post-install.sh
# Or run local script:
bash scripts/pve-post-install.sh
```

### Manual Steps Performed by the Script:
1. **Remove Enterprise Repositories**:
   ```bash
   rm -f /etc/apt/sources.list.d/pve-enterprise.list
   ```
2. **Add No-Subscription Repository**:
   ```bash
   cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.list
   deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
   EOF
   ```
3. **Disable the Subscription Warning Popup**:
   Replaces the nag prompt logic in `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js`.
4. **Update System**:
   ```bash
   apt-get update && apt-get dist-upgrade -y
   ```

---

## 3. Storage Architecture on Budget Hardware

On cheap hardware, storage I/O is usually the biggest bottleneck. Follow these rules:

1. **Local VM/LXC Disks (`local-lvm` or `local-zfs`)**:
   - Store all active VM/LXC virtual disks directly on the internal NVMe drive.
2. **Proxmox Backup Server (PBS) or NFS**:
   - Set up an external 2.5" drive, USB hard drive, or a separate low-cost machine running **Proxmox Backup Server (PBS)** for deduplicated, incremental, encrypted backups.
3. **ZFS Memory Tuning (If using ZFS)**:
   By default, ZFS ARC will consume up to 50% of your system RAM. Limit ZFS ARC to 2–4 GB on a 16GB system:
   ```bash
   echo "options zfs zfs_arc_max=4294967296" >> /etc/modprobe.d/zfs.conf
   update-initramfs -u
   ```

---

## 4. Multi-Node Proxmox Cluster (For 2 or 3 Nodes)

If you have 2 or 3 mini-PCs, combine them into a single pane-of-glass cluster:

1. **On Node 1 (Primary)**:
   ```bash
   pvecm create home-cluster
   ```
2. **On Node 2 & Node 3**:
   ```bash
   pvecm add 192.168.1.50
   ```
*(Enter Node 1's root password and fingerprint when prompted).*

> **Important Note for 2-Node Clusters:**
> Proxmox requires a quorum majority (>50% votes). A 2-node cluster needs a tie-breaker. You can add a lightweight **QDevice** (Quorum Device) on any cheap external device, such as a Raspberry Pi or your router:
> ```bash
> apt-get install corosync-qnetd corosync-qdevice
> pvecm qdevice setup <qdevice-ip>
> ```
