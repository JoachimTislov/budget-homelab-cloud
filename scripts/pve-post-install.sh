#!/usr/bin/env bash
# ==============================================================================
# Proxmox VE Post-Install Optimization Script
# Purpose: Configures no-subscription repos, disables nag popup, updates system.
# Run as: root on Proxmox VE 8.x
# ==============================================================================

set -euo pipefail

echo "==> [1/4] Disabling enterprise repository..."
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    sed -i.bak "s/^deb/#deb/" /etc/apt/sources.list.d/pve-enterprise.list || true
    echo "    Enterprise repo disabled."
fi

echo "==> [2/4] Adding Proxmox VE no-subscription repository..."
cat <<'EOF' > /etc/apt/sources.list.d/pve-no-subscription.list
# Proxmox VE No-Subscription Repository
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

echo "==> [3/4] Disabling 'No Subscription' GUI nag dialog..."
JS_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
if [ -f "$JS_FILE" ]; then
    # Backup original if not already backed up
    if [ ! -f "${JS_FILE}.bak" ]; then
        cp "$JS_FILE" "${JS_FILE}.bak"
    fi
    # Patch out the subscription alert
    sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" "$JS_FILE" || true
    systemctl restart pveproxy.service
    echo "    Nag dialog disabled. pveproxy restarted."
fi

echo "==> [4/4] Updating package index and upgrading system..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y

echo "==> Proxmox VE post-install complete! Enjoy your homelab hypervisor."
