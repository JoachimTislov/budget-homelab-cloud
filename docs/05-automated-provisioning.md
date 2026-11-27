# Zero-Touch Automated Provisioning & Bootstrap Guide

When provisioning multiple cheap computers (e.g., 2 to 5 used mini-PCs), manual clicking through OS installer wizards is slow and error-prone. This guide explains how to achieve **zero-touch unattended installation** using automated ISOs and a post-install bootstrap script.

---

## Architecture of Zero-Touch Provisioning

```
┌──────────────────────────┐      ┌──────────────────────────┐      ┌──────────────────────────┐
│   Mini-PC 1 (Master)     │      │   Mini-PC 2 (Worker)     │      │   Mini-PC 3 (Worker)     │
└────────────┬─────────────┘      └────────────┬─────────────┘      └────────────┬─────────────┘
             │                                 │                                 │
             └─────────────────────────────────┴─────────────────────────────────┘
                                               ▲
                         Plug in USB with Unattended PVE / Debian ISO
                                               │
                                      Boots automatically
                                      Formats NVMe/SATA
                                      Applies answer.toml / user-data
                                      Installs SSH keys & network
                                      Reboots automatically into OS
                                               │
                                               ▼
                              Run Universal Bootstrap Script
                              (Configures role, cluster, or PaaS)
```

---

## 1. Zero-Touch Proxmox VE Auto-Installer (Recommended)

Proxmox VE 8.1+ introduced the official declarative unattended installation engine driven by `answer.toml`.

### Method A: Build the Unattended ISO
1. Download standard Proxmox VE 8.x ISO:
   ```bash
   wget https://enterprise.proxmox.com/iso/proxmox-ve_8.2-1.iso
   ```
2. Customize `iso/pve-answer.toml`:
   - Set your desired root password.
   - Insert your SSH public key (`root_ssh_keys`).
   - Choose `ext4` or `zfs`.
   - Specify target disk (`nvme0n1` for NVMe or `sda` for SATA).
3. Build the unattended ISO:
   ```bash
   bash scripts/build-unattended-pve-iso.sh proxmox-ve_8.2-1.iso iso/pve-answer.toml pve-unattended.iso
   ```
4. Flash to a USB flash drive:
   ```bash
   sudo dd if=pve-unattended.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```

### Method B: Flash Drive Label Trick (No ISO Repacking Needed!)
Proxmox's automated installer looks for a FAT or ext4 partition with the filesystem label **`proxmox-ais`**:
1. Flash the standard, unmodified Proxmox VE ISO to your USB stick.
2. Plug in a second tiny USB flash drive (or create a secondary partition on the same drive).
3. Format it as FAT32 with label `proxmox-ais`:
   ```bash
   sudo mkfs.vfat -n "proxmox-ais" /dev/sdY1
   ```
4. Copy `iso/pve-answer.toml` onto that partition and rename it to `answer.toml`.
5. Plug both drives into the computer and turn it on. The installer will automatically detect `answer.toml` and proceed completely unattended!

---

## 2. Post-Install Universal Bootstrap Script

Once the computer finishes the automated install and boots into the OS, run the universal bootstrap script to prepare the node for its specific cluster role:

```bash
# General Syntax:
sudo ./scripts/bootstrap-node.sh --role <ROLE> [OPTIONS]
```

### Scenario 1: Provisioning a Proxmox Host
```bash
sudo ./scripts/bootstrap-node.sh \
  --role pve \
  --hostname pve-node-01 \
  --ssh-key "ssh-ed25519 AAAAC3... user@laptop" \
  --tailscale-key "tskey-auth-..." \
  --reboot
```
*What this does:* Disables subscription repos, adds free community repos, disables GUI nag popups, limits ZFS ARC RAM consumption, installs baseline tools, connects to Tailscale VPN, and reboots.

### Scenario 2: Provisioning a k3s Kubernetes Server (Control Plane)
```bash
sudo ./scripts/bootstrap-node.sh \
  --role k3s-server \
  --hostname k3s-master-01 \
  --reboot
```
*What this does:* Tunes sysctl network bridges, inotify watchers, and swappiness; installs k3s control plane with WireGuard mesh; prints the join token.

### Scenario 3: Provisioning k3s Worker Nodes
On your worker mini-PCs:
```bash
sudo ./scripts/bootstrap-node.sh \
  --role k3s-agent \
  --hostname k3s-worker-02 \
  --server-url "https://192.168.1.50:6443" \
  --token "<TOKEN_FROM_MASTER>"
```

### Scenario 4: Provisioning a Coolify PaaS Node
```bash
sudo ./scripts/bootstrap-node.sh \
  --role coolify \
  --hostname coolify-node-01
```
*What this does:* Installs Docker Engine, Docker Compose, system optimizations, and provisions Coolify PaaS on port 8000.

---

## 3. Mass Deploying Across Multiple PCs in Parallel

If you have 3 to 10 machines:
1. Plug the unattended USB installer into Machine 1 -> Power On -> Boot from USB.
2. Move the USB stick to Machine 2 -> Power On -> Boot from USB.
3. Repeat for Machine 3.
4. All machines partition, install, and obtain DHCP leases simultaneously without touching a keyboard or mouse.
5. Use an Ansible playbook or a bash loop over their DHCP IP addresses to trigger `bootstrap-node.sh`.
