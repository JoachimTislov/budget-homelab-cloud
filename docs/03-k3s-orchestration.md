# Container & Cloud Orchestration with k3s (Lightweight Kubernetes)

k3s is a fully compliant, certified Kubernetes distribution packaged as a single binary (<100MB) designed specifically for resource-constrained environments, edge nodes, and budget homelabs.

---

## 1. Why k3s Beats Upstream Kubernetes (k8s) & MicroK8s on Cheap Hardware

* **RAM Usage:** Upstream k8s control planes idle at 2.5 GB–4 GB RAM per node. k3s idles at **~500 MB RAM**.
* **Zero Bloat:** Strips out legacy, in-tree cloud provider plugins and storage drivers, replacing them with lightweight defaults (`local-path-provisioner`, `traefik`, `flannel`, and `sqlite` / embedded `etcd`).
* **Maintenance:** Upgrades and installations are a single `curl | sh` script.

---

## 2. Cluster Topology Options

### Option A: Single-Node All-in-One (Server + Worker on 1 Mini-PC)
- Footprint: ~600 MB RAM for control-plane + your application workloads.
- Storage: Uses `local-path-provisioner` directly on host NVMe.

### Option B: 3-Node High-Availability (HA) Embedded etcd Cluster
- 3 Mini-PCs (Nodes 1, 2, 3), each running `k3s server --cluster-init`.
- High availability: Survives 1 node failure without taking down the Kubernetes API or state.
- Ingress VIP: Managed seamlessly via `kube-vip`.

---

## 3. Automated Installation Instructions

### Step 1: Install k3s on the First Server (Master)

Run `scripts/install-k3s-server.sh` or execute:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable servicelb \
  --flannel-backend=wireguard-native \
  --write-kubeconfig-mode 644" sh -
```

**Parameters explained:**
- `--disable servicelb`: Disables default k3s ServiceLB so you can use standard MetalLB or kube-vip if desired (or leave it enabled for simple home LAN setups).
- `--flannel-backend=wireguard-native`: Encrypts all pod-to-pod cross-node traffic using in-kernel WireGuard with almost zero CPU overhead.
- `--write-kubeconfig-mode 644`: Allows non-root users to read `/etc/rancher/k3s/k3s.yaml`.

Verify the server is running:
```bash
kubectl get nodes
kubectl get pods -A
```

### Step 2: Retrieve Cluster Join Token

On the primary server node, grab the node token:
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```
*(Example: `K10fa49382b...::server:7492c0182...`)*

### Step 3: Join Additional Worker (Agent) Nodes

On Node 2 and Node 3:
```bash
export K3S_URL="https://192.168.1.50:6443"
export K3S_TOKEN="<PASTE_YOUR_NODE_TOKEN_HERE>"

curl -sfL https://get.k3s.io | sh -
```

Check from your master node:
```bash
kubectl get nodes -o wide
```
You will see your nodes ready in the cluster.

---

## 4. Ingress, SSL, and Storage Architecture

### 1. Ingress Routing (Traefik)
k3s includes **Traefik v2** out of the box. You can expose services using simple Ingress manifests or Traefik IngressRoutes.

### 2. Automated TLS / SSL (Cert-Manager)
Install `cert-manager` with Helm:
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

Then create a Cloudflare DNS-01 or Let's Encrypt HTTP-01 ClusterIssuer for wildcard SSL certificates without exposing port 80/443 to the public internet!

### 3. Persistent Storage
- **Single-Node / Local Bound:** The built-in `local-path` storage class is fast and uses the node's local NVMe drive.
- **Distributed Shared Storage (Multi-Node):**
  If your apps need to fail over to other nodes with their volumes intact:
  - **[Longhorn](https://longhorn.io/):** Easy Kubernetes-native distributed block storage (requires decent SSDs and gigabit network).
  - **NFS Client Provisioner:** If you have a NAS or dedicated storage machine.
