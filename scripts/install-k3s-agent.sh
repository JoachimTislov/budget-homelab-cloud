#!/usr/bin/env bash
# ==============================================================================
# k3s Agent (Worker Node) Automated Join Script
# Usage:
#   sudo ./install-k3s-agent.sh <K3S_SERVER_URL> <K3S_NODE_TOKEN>
# Example:
#   sudo ./install-k3s-agent.sh https://192.168.1.50:6443 K10...::server:...
# ==============================================================================

set -euo pipefail

K3S_URL="${1:-}"
K3S_TOKEN="${2:-}"

if [ -z "$K3S_URL" ] || [ -z "$K3S_TOKEN" ]; then
    echo "Error: Missing arguments."
    echo "Usage: sudo $0 <K3S_SERVER_URL> <K3S_NODE_TOKEN>"
    echo "Example: sudo $0 https://192.168.1.50:6443 K10...::server:..."
    exit 1
fi

NODE_IP="$(hostname -I | awk '{print $1}')"

echo "==> Configuring system prerequisites..."
sudo modprobe overlay || true
sudo modprobe br_netfilter || true

sudo tee /etc/sysctl.d/99-kubernetes-cri.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system > /dev/null

echo "==> Joining k3s cluster at ${K3S_URL} with node IP ${NODE_IP}..."
curl -sfL https://get.k3s.io | K3S_URL="${K3S_URL}" K3S_TOKEN="${K3S_TOKEN}" INSTALL_K3S_EXEC="agent --node-ip=${NODE_IP}" sh -

echo "==> k3s agent started successfully!"
echo "Check your master node using: kubectl get nodes"
