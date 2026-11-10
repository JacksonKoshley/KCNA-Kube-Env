# Module 00: Setup

Build the lab cluster and learn what each part of the setup does.

## Objectives
- Create a 3-node minikube cluster with its own profile and kube-context
- Understand why the cluster uses **containerd** and **Cilium**
- Check that the cluster is healthy

## What gets built

| Setting | Value | Why |
|---|---|---|
| Profile / context | `kcna` | Keeps this lab separate from other clusters |
| Nodes | 3 (1 control plane, 2 workers) | Needed for scheduling, taints and DaemonSet labs |
| Container runtime | containerd | The most common CRI runtime; Kubernetes removed dockershim in v1.24 |
| CNI | Cilium (eBPF) | Enforces NetworkPolicy and adds Hubble flow visibility |
| kube-proxy | Kept | So you can study it in Module 01 (Cilium can replace it) |
| Addons | metrics-server | Powers `kubectl top` and the HPA in later modules |

## Steps

1. Create the cluster:
   ```bash
   make up
   ```
   containerd needs a CNI when the cluster is created. The script renders the Cilium Helm chart to a
   manifest, passes it to `minikube start --cni=<file>`, then has Helm take ownership of it so later
   upgrades work with `helm upgrade`.

2. Check the context. Every command in this repo assumes the `kcna` context:
   ```bash
   kubectl config current-context
   kubectl config get-contexts
   ```

3. Look at the nodes:
   ```bash
   kubectl get nodes -o wide
   ```
   Note the `CONTAINER-RUNTIME` column and the `control-plane` role.

4. Look at the system pods:
   ```bash
   kubectl get pods -n kube-system -o wide
   ```
   Which pods run on every node? Which run only on the control plane?

5. Check Cilium:
   ```bash
   kubectl -n kube-system exec ds/cilium -- cilium-dbg status --brief
   ```

6. Run the health check any time:
   ```bash
   make verify
   ```

## Day-to-day
```bash
make down      # stop; state is kept
make up        # start again
make destroy   # delete and start over
```

## Exam notes
- **CRI** (Container Runtime Interface) is how the kubelet talks to a runtime such as containerd or CRI-O.
- **CNI** (Container Network Interface) is a spec plus plugins. The plugin (Cilium, Calico, Flannel)
  gives pods IP addresses and connects them. Kubernetes does not provide pod networking itself.
- Docker images still work on containerd because both follow the **OCI** image spec.

## Practice questions
1. Which component calls the container runtime through CRI?
2. What happens to pods if no CNI plugin is installed?
3. Name two CNI plugins and two CRI-compatible runtimes.
4. Why do Docker-built images run on a containerd cluster?

Answers: [solutions/README.md](solutions/README.md)
