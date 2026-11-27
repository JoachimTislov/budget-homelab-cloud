# Cheap Hardware Guide for Local Virtualization & Orchestration

Building a resilient local infrastructure doesn't require expensive enterprise servers. In fact, decommissioned enterprise 1-liter (1L) Ultra-Small-Form-Factor (USFF) mini-PCs offer the best price-to-performance, power efficiency, and whisper-quiet operation.

---

## 1. Top Recommended Cheap Hardware: 1L USFF "Mini-PCs"

Enterprise offices routinely decommission thousands of 1L desktop units. You can find them on eBay, refurbishers, or local marketplaces (Craigslist, Facebook Marketplace, Kleinanzeigen) for **$70 to $130 USD / €65 to €120 EUR**.

### Comparison of the "Big Three" 1L Mini-PCs

| Model Family | CPU Generations | RAM Slots / Max | Storage Slots | Approximate Used Price |
| :--- | :--- | :--- | :--- | :--- |
| **HP ProDesk / EliteDesk 800 G2 / G3 / G4 Mini** | 6th, 7th, or 8th Gen Intel Core i5 (e.g. i5-6500T, i5-8500T) | 2x DDR4 SODIMM (Up to 32GB or 64GB on G4) | 1x M.2 NVMe + 1x 2.5" SATA SSD | **$70 – $130** |
| **Lenovo ThinkCentre M700 / M710q / M910q Tiny** | 6th or 7th Gen Intel Core i5 (e.g. i5-6500T, i5-7500T) | 2x DDR4 SODIMM (Up to 32GB or 64GB) | 1x M.2 NVMe + 1x 2.5" SATA SSD | **$75 – $120** |
| **Dell OptiPlex 3050 / 5050 / 7050 Micro** | 6th or 7th Gen Intel Core i5 (e.g. i5-6500T, i5-7500T) | 2x DDR4 SODIMM (Up to 32GB or 64GB) | 1x M.2 NVMe + 1x 2.5" SATA SSD | **$70 – $120** |

> **Pro Tip:** Look for the **"T" series CPUs** (e.g., `i5-6500T`, `i5-7500T`, `i5-8500T`). These are 35W TDP chips that idle at only **6W to 12W**, keeping electricity bills negligible ($1–$2 per month per node).

### Why Mini-PCs beat Raspberry Pi 4/5 for Virtualization:
- **Compute per Dollar:** An Intel Core i5-6500T / i5-8500T has 4–6 full x86 cores with hardware virtualization extensions (`VT-x`, `VT-d`, `EPT`), outperforming an ARM Raspberry Pi 4/5 by 3x–6x.
- **RAM Capacity:** Raspberry Pis are capped at 4GB or 8GB (non-upgradable soldered RAM). Mini-PCs use standard DDR4 SODIMM sockets and easily upgrade to 32GB or 64GB.
- **I/O Speed:** Mini-PCs offer genuine PCIe Gen3 x4 NVMe slots (2,000–3,500 MB/s), whereas SD cards or basic USB-attached drives on SBCs are prone to severe I/O degradation and corruption under database write loads.
- **Total Cost:** A Raspberry Pi 5 (8GB) + power supply + NVMe HAT + SSD + case totals around $130–$150—the same price as a 6-core Intel i5 mini-PC with 32GB RAM!

---

## 2. Recommended Configuration Per Node

For a single server or a 3-node cluster:
- **Processor:** 4 cores minimum (e.g., Intel Core i5-6500T or better; i5-8500T gives 6 physical cores).
- **RAM:** Minimum 16 GB DDR4 (1x 16GB or 2x 8GB SODIMM); 32 GB (2x 16GB) is the sweet spot.
- **Primary Storage (OS & Fast Storage):** 512 GB or 1 TB NVMe SSD (PCIe Gen3, e.g., Crucial P3, Samsung 970 Evo, or Kioxia).
- **Secondary Storage (Optional):** 1x 2.5" SATA SSD (500GB–2TB) in the drive bay for dedicated backups or data volume pools.
- **Networking:** Built-in 1GbE RJ-45 port (Intel I219-LM or Realtek).
  *(Optional: If you need 2.5GbE for fast Ceph clustering, add a cheap $15–$20 Realtek RTL8156BG USB 3.0 to 2.5GbE adapter or an M.2 to 2.5GbE NIC).*

---

## 3. Essential BIOS / UEFI Settings

Before installing Proxmox or Linux, enter BIOS (usually `F10` on HP, `F1` or `Enter` on Lenovo, `F2` on Dell):
1. **Enable Virtualization:**
   - Intel Virtualization Technology (`VT-x`): **Enabled**
   - Intel Directed I/O (`VT-d`): **Enabled**
2. **Power Management:**
   - Power State After AC Loss: **Power On** (crucial for automatic recovery after a power outage).
   - Intel SpeedStep / C-States: **Enabled** (ensures low idle power draw).
3. **Boot:**
   - Secure Boot: **Disabled** (simplifies custom kernel modules and DKMS).
   - UEFI Boot: **Enabled** (disable Legacy/CSM).
