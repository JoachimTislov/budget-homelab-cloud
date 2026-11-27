# Budget Homelab: Virtualization & Cloud Orchestration Architecture

This repository contains the architecture blueprint, hardware procurement guide, setup instructions, and automation scripts for building a high-efficiency virtualization and orchestration cloud on budget/cheap local hardware.

---

## 1. Executive Summary & Recommended Tech Stack

When running local infrastructure on budget hardware (e.g., $60–$150 used enterprise micro-PCs, older laptops, or SBCs), avoiding resource-heavy enterprise stacks (OpenStack, Cloud Foundry, full OpenShift) is critical. 

### The Recommended 3-Tier Production Stack

```
┌────────────────────────────────────────────────────────────────────────┐
│                        3. Application Layer                            │
│    Coolify (PaaS / Git Ops)   OR   Kubernetes Manifests / Helm Charts  │
├────────────────────────────────────────────────────────────────────────┤
│                       2. Orchestration Layer                           │
│     k3s (Lightweight Kubernetes)  OR  HashiCorp Nomad / Docker Swarm   │
├────────────────────────────────────────────────────────────────────────┤
│                      1. Virtualization & Host                          │
│     Proxmox VE (KVM + LXC)  OR  Debian 12 + Incus / Bare-Metal Linux   │
├────────────────────────────────────────────────────────────────────────┤
│                          Hardware Layer                                │
│   1 to 3x Used 1L Mini-PCs (Lenovo Tiny / HP ProDesk / Dell OptiPlex)  │
│          Intel 6th–10th Gen Core i5 (35W TDP), 16–32 GB RAM, NVMe       │
└────────────────────────────────────────────────────────────────────────┘
```

| Layer | Recommended Choice | Lightweight Alternative | Why It Wins on Cheap Hardware |
| :--- | :--- | :--- | :--- |
| **Hypervisor** | **[Proxmox VE 8.x](docs/02-proxmox-setup.md)** | Bare-metal Debian 12 / Incus | Low baseline footprint (~1 GB RAM), native LXC for zero-overhead containers, hardware passthrough, robust web UI. |
| **Orchestrator** | **[k3s](docs/03-k3s-orchestration.md)** | HashiCorp Nomad or Docker Swarm | Full CNCF Kubernetes compatibility at only ~500 MB RAM per node. Replaces etcd with SQLite/kine for single-node or lightweight embedded etcd for 3-node HA. |
| **Self-Hosted PaaS** | **[Coolify v4](docs/04-paas-coolify.md)** | Dokku / CapRover | Offers a Heroku/Vercel-like UI, automatic git pushes, SSL termination, and managed databases directly over SSH/Docker. |
| **Networking Mesh** | **Tailscale / Headscale** | WireGuard / Cloudflare Tunnels | Secure remote access without opening public router ports or needing a static IP. |
| **Storage** | **ZFS (Local) + Local-Path Provisioner** | NFS / Longhorn (with SSDs) | Maximum I/O throughput on budget consumer SSDs; avoids distributed storage network bottlenecks on 1GbE. |

---

## 2. Repository Structure & Guides

- **[docs/01-hardware-guide.md](docs/01-hardware-guide.md)**: Hardware buying guide (used 1L mini-PCs vs SBCs), power efficiency, RAM/SSD recommendations, and BIOS configuration.
- **[docs/02-proxmox-setup.md](docs/02-proxmox-setup.md)**: Step-by-step Proxmox VE installation, post-install repository cleanup, storage tuning, and networking setup.
- **[docs/03-k3s-orchestration.md](docs/03-k3s-orchestration.md)**: Lightweight Kubernetes cluster installation (single-node or multi-node HA), storage classes, Traefik ingress, and Helm deployments.
- **[docs/04-paas-coolify.md](docs/04-paas-coolify.md)**: Turnkey self-hosted PaaS installation for rapid app deployments, database provisioning, and SSL management.
- **[docs/05-automated-provisioning.md](docs/05-automated-provisioning.md)**: Zero-touch unattended ISO setup, answer file generation, USB flashing, and multi-node parallel rollout.
- **[iso/](iso/)**:
  - `pve-answer.toml`: Declarative answer file for zero-touch Proxmox VE 8.x installation.
  - `user-data.yaml`: Cloud-init autoinstall configuration for bare-metal Ubuntu/Debian.
- **[scripts/](scripts/)**:
  - `bootstrap-node.sh`: Universal role-based node bootstrapper (`--role pve|k3s-server|k3s-agent|coolify|docker`).
  - `build-unattended-pve-iso.sh`: Builds a zero-touch bootable Proxmox VE ISO with embedded answer file.
  - `install-k3s-server.sh`: One-line automated k3s master node deployment.
  - `install-k3s-agent.sh`: One-line automated k3s worker node join script.
  - `pve-post-install.sh`: Proxmox post-install helper (disables subscription popups, enables no-subscription repos).
  - `pve-create-k3s-template.sh`: Creates an automated Debian 12 cloud-init VM template on Proxmox.

---

## 3. Quick Start Roadmap

1. **Procure Hardware**: Grab 1 to 3 used USFF mini-PCs (e.g., HP ProDesk 400/600/800 G3/G4 or Lenovo ThinkCentre M710q/M900, ~$80–$120 each with 16–32 GB RAM).
2. **Flash & Install Proxmox VE**: Install Proxmox VE from USB on each node and run `scripts/pve-post-install.sh`.
3. **Choose Your Operating Mode**:
   - **Mode A (Fastest PaaS - "Vercel on your own desk")**: Spin up an Ubuntu/Debian VM or LXC container and install Coolify via `docs/04-paas-coolify.md`.
   - **Mode B (Standard Kubernetes Cloud)**: Deploy 1 to 3 lightweight VMs and run `scripts/install-k3s-server.sh` and `scripts/install-k3s-agent.sh` following `docs/03-k3s-orchestration.md`.
