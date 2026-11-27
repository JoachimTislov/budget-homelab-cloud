#!/usr/bin/env bash
# ==============================================================================
# k3s Server (Control Plane) Automated Installer
# Suitable for: Single-node or multi-node primary control plane on cheap hardware
# ==============================================================================

set -euo pipefail

NODE_IP="${1:-$(hostname -I | awk '{print $1}')}"

echo "==> Configuring system prerequisites..."
# Enable IPv4 forwarding and bridge netfilter
sudo modprobe overlay || true
sudo modprobe br_netfilter || true

sudo tee /etc/sysctl.d/99-kubernetes-cri.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system > /dev/null

echo "==> Installing k3s server on node IP: ${NODE_IP}..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=${NODE_IP} \
  --advertise-address=${NODE_IP} \
  --flannel-backend=wireguard-native \
  --write-kubeconfig-mode=644 \
  --disable=servicelb" sh -

echo "==> Waiting for k3s server to initialize..."
sleep 10
sudo k3s kubectl get nodes

echo ""
echo "========================================================================"
echo " k3s Server successfully installed!"
echo " Cluster API: https://${NODE_IP}:6443"
echo " Node Token for joining workers:"
echo "------------------------------------------------------------------------"
sudo cat /var/lib/rancher/k3s/server/node-token
echo ""
echo "========================================================================"
echo "Kubeconfig is available at: /etc/rancher/k3s/k3s.yaml"
