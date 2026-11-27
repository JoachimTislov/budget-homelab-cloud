#!/usr/bin/env bash
# ==============================================================================
# Universal Node Bootstrap Script
# Streamlines post-install setup for bare-metal & VM nodes.
#
# Usage:
#   sudo ./bootstrap-node.sh --role <pve|k3s-server|k3s-agent|coolify|docker> [OPTIONS]
#
# Options:
#   --role <name>          Node role (pve, k3s-server, k3s-agent, coolify, docker)
#   --hostname <name>      Set system hostname
#   --server-url <url>     k3s server URL (required for k3s-agent)
#   --token <token>        k3s join token (required for k3s-agent)
#   --ssh-key <pubkey>     Append public SSH key to authorized_keys
#   --tailscale-key <key>  Optional Tailscale auth key for instant VPN mesh
#   --reboot               Reboot system when bootstrap completes
# ==============================================================================

set -euo pipefail

ROLE=""
CUSTOM_HOSTNAME=""
SERVER_URL=""
NODE_TOKEN=""
SSH_PUB_KEY=""
TAILSCALE_KEY=""
DO_REBOOT=false

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      ROLE="$2"
      shift 2
      ;;
    --hostname)
      CUSTOM_HOSTNAME="$2"
      shift 2
      ;;
    --server-url)
      SERVER_URL="$2"
      shift 2
      ;;
    --token)
      NODE_TOKEN="$2"
      shift 2
      ;;
    --ssh-key)
      SSH_PUB_KEY="$2"
      shift 2
      ;;
    --tailscale-key)
      TAILSCALE_KEY="$2"
      shift 2
      ;;
    --reboot)
      DO_REBOOT=true
      shift
      ;;
    -h|--help)
      echo "Usage: sudo $0 --role <pve|k3s-server|k3s-agent|coolify|docker> [OPTIONS]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ -z "$ROLE" ]; then
  echo "Error: --role is required (pve, k3s-server, k3s-agent, coolify, docker)"
  exit 1
fi

echo "========================================================================"
echo " Starting Node Bootstrap (Role: ${ROLE})"
echo "========================================================================"

# ------------------------------------------------------------------------------
# 1. Base Host Configuration
# ------------------------------------------------------------------------------
if [ -n "$CUSTOM_HOSTNAME" ]; then
  echo "==> Setting hostname to: ${CUSTOM_HOSTNAME}..."
  hostnamectl set-hostname "$CUSTOM_HOSTNAME"
  sed -i "s/127.0.1.1.*/127.0.1.1\t${CUSTOM_HOSTNAME}/" /etc/hosts || echo "127.0.1.1\t${CUSTOM_HOSTNAME}" >> /etc/hosts
fi

if [ -n "$SSH_PUB_KEY" ]; then
  echo "==> Configuring SSH authorized_keys..."
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  echo "$SSH_PUB_KEY" >> /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi

# ------------------------------------------------------------------------------
# 2. Kernel & OS Tuning for Virtualization / Containers
# ------------------------------------------------------------------------------
echo "==> Applying OS kernel & sysctl tuning..."
cat <<'EOF' > /etc/sysctl.d/99-homelab-tuning.conf
# Max open file descriptors
fs.file-max = 2097152

# Network & bridge settings for containers/VMs
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# Reduce swappiness to preserve SSD endurance
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Max inotify watchers for containers
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
EOF

modprobe overlay 2>/dev/null || true
modprobe br_netfilter 2>/dev/null || true
sysctl --system > /dev/null 2>&1 || true

# ------------------------------------------------------------------------------
# 3. Base Utilities Installation
# ------------------------------------------------------------------------------
echo "==> Installing essential packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  curl wget git htop tmux jq iotop net-tools \
  ca-certificates gnupg lsb-release qemu-guest-agent

systemctl enable --now qemu-guest-agent 2>/dev/null || true

# ------------------------------------------------------------------------------
# 4. Optional Tailscale Mesh Setup
# ------------------------------------------------------------------------------
if [ -n "$TAILSCALE_KEY" ]; then
  echo "==> Installing & connecting Tailscale mesh..."
  curl -fsSL https://tailscale.com/install.sh | sh
  tailscale up --authkey="${TAILSCALE_KEY}" --accept-routes
fi

# ------------------------------------------------------------------------------
# 5. Role-Specific Setup
# ------------------------------------------------------------------------------
case "$ROLE" in
  pve)
    echo "==> Executing Proxmox VE optimizations..."
    # Disable enterprise repo
    if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
      sed -i "s/^deb/#deb/" /etc/apt/sources.list.d/pve-enterprise.list || true
    fi
    # Add no-subscription repo
    cat <<'EOF' > /etc/apt/sources.list.d/pve-no-subscription.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
    # Disable nag popup
    JS_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
    if [ -f "$JS_FILE" ]; then
      sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" "$JS_FILE" || true
      systemctl restart pveproxy.service 2>/dev/null || true
    fi
    # Limit ZFS ARC if ZFS is active
    if command -v zpool >/dev/null 2>&1; then
      echo "options zfs zfs_arc_max=4294967296" > /etc/modprobe.d/zfs.conf
      update-initramfs -u 2>/dev/null || true
    fi
    apt-get update -qq
    ;;

  k3s-server)
    echo "==> Deploying k3s control plane..."
    NODE_IP="$(hostname -I | awk '{print $1}')"
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
      --node-ip=${NODE_IP} \
      --advertise-address=${NODE_IP} \
      --flannel-backend=wireguard-native \
      --write-kubeconfig-mode=644 \
      --disable=servicelb" sh -
    echo "--> k3s server active. Node Token:"
    cat /var/lib/rancher/k3s/server/node-token
    ;;

  k3s-agent)
    if [ -z "$SERVER_URL" ] || [ -z "$NODE_TOKEN" ]; then
      echo "Error: k3s-agent requires --server-url and --token"
      exit 1
    fi
    echo "==> Joining k3s cluster at ${SERVER_URL}..."
    NODE_IP="$(hostname -I | awk '{print $1}')"
    curl -sfL https://get.k3s.io | K3S_URL="${SERVER_URL}" K3S_TOKEN="${NODE_TOKEN}" \
      INSTALL_K3S_EXEC="agent --node-ip=${NODE_IP}" sh -
    ;;

  coolify)
    echo "==> Deploying Coolify PaaS..."
    curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
    ;;

  docker)
    echo "==> Installing Docker Engine & Compose..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    ;;

  *)
    echo "Error: Unknown role '$ROLE'"
    exit 1
    ;;
esac

echo "========================================================================"
echo " Node bootstrap completed successfully for role: ${ROLE}"
echo "========================================================================"

if [ "$DO_REBOOT" = true ]; then
  echo "Rebooting system in 5 seconds..."
  sleep 5
  reboot
fi
