# Module 01: Solutions

## Steps

**1.** All four run on the `kcna` (control-plane) node. Their names end with the node name
(`kube-scheduler-kcna`), which marks them as mirror pods of static pods.

**2.** The owner is the **Node**, not a ReplicaSet. The kubelet creates the pod from
`/etc/kubernetes/manifests/kube-scheduler.yaml` and publishes a read-only *mirror pod* to the API so you can see it.
Deleting the mirror pod does nothing lasting: the kubelet recreates it right away because the file still exists.
To stop a static pod, remove its manifest file.

**3.** Only the **kube-apiserver** reads and writes etcd. Lose etcd without a backup and you lose all cluster state:
every Deployment, Service, Secret, ConfigMap and RBAC rule. Running containers keep going for a while, but the
cluster can't be managed.

**4.** `kubectl get deploy` sends `GET https://<api>/apis/apps/v1/deployments?limit=500` (namespaced with `-n`).
`/api/v1` is the legacy **core** group (Pods, Services, ConfigMaps, Secrets, Nodes). `/apis/<group>/<version>`
holds named groups such as `apps/v1` (Deployments) and `batch/v1` (Jobs).

**5.**

| Event | Produced by |
|---|---|
| `ScalingReplicaSet` | Deployment controller (kube-controller-manager) |
| `SuccessfulCreate` | ReplicaSet controller (kube-controller-manager) |
| `Scheduled` | kube-scheduler |
| `Pulling` / `Created` / `Started` | kubelet on the chosen node |

**6.** The **ReplicaSet controller** compares desired replicas (3) with the pods it owns that match its selector.
When there are fewer, it creates new pods, and the scheduler places them.

**7.** The kubelet is **not** a pod. It's a systemd service on each node, because it's what runs pods.
`crictl` talks to the container runtime (containerd) through the **CRI** socket. Node Leases are lightweight
**heartbeats**: the kubelet renews its Lease every few seconds, and the node controller marks the node
`NotReady`/`Unknown` if renewals stop.

**8.** `Using iptables Proxier`: iptables mode. The Service's **label selector** (`app: hello`) is matched against pods.
The EndpointSlice controller writes the matching pod IPs into EndpointSlices, and kube-proxy turns those into
iptables rules.

**9.** The new pods stayed `Pending` with no node assigned, because nothing was assigning nodes. Existing pods kept
running: the control plane manages workloads but doesn't carry their traffic, so a control-plane outage stops
*changes*, not running apps. When the manifest came back, the kubelet restarted the scheduler, and it placed the
pending pods.

## Practice questions
1. **etcd**, written to only through the kube-apiserver.
2. **kube-scheduler.** An unscheduled pod has no `Scheduled` event and no node.
3. The **kubelet**, based on the pod's `restartPolicy`.
4. No. Clients talk to the API server, which handles authentication, authorization and admission before using etcd.
5. The **ReplicaSet controller** creates the pods. The Deployment controller manages ReplicaSets, and the
   scheduler only assigns nodes.
6. `/etc/kubernetes/manifests`, read by the **kubelet** (set by `staticPodPath` in the kubelet config).
7. **kube-proxy**, for example when Cilium runs with kube-proxy replacement.
8. Node heartbeats, so the control plane can detect failed nodes cheaply.
