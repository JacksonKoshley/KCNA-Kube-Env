# Module 01: Architecture

**Domain:** D1 Kubernetes Fundamentals · Core Concepts / Administration

See every control-plane and node component working, and trace what happens when you create a Deployment.

## Objectives
- Name the control-plane components and what each one does
- Explain static pods and why the control plane runs as them
- Read data directly from etcd
- Talk to the API server without the usual `kubectl get` output
- Trace a Deployment through the API server, controllers, scheduler and kubelet
- See the kubelet, container runtime and kube-proxy on a worker node

## Background

```
                ┌──────────────── Control plane (node: kcna) ────────────────┐
 kubectl ──────►│ kube-apiserver ◄──► etcd                                   │
                │      ▲   ▲                                                 │
                │      │   └── kube-scheduler        (which node?)           │
                │      └────── kube-controller-manager (make it so)          │
                └──────┼─────────────────────────────────────────────────────┘
                       │ watch / update
        ┌──────────────┴──── Every node (kcna, kcna-m02, kcna-m03) ──────────┐
        │ kubelet ──CRI──► containerd ──► runc ──► containers                │
        │ kube-proxy (Service rules) · Cilium agent (CNI, pod networking)    │
        └────────────────────────────────────────────────────────────────────┘
```

Only the **API server** talks to etcd. Every other component watches and updates objects through the API server.

## Steps

### 1. Find the control plane
```bash
kubectl get pods -n kube-system -l tier=control-plane -o wide
```
- Which node are they on?
- What's the pattern in their names?

### 2. Static pods
The kubelet on the control-plane node starts these pods from files on disk, not from the API server.
```bash
minikube -p kcna ssh -- sudo grep staticPodPath /var/lib/kubelet/config.yaml
minikube -p kcna ssh -- sudo ls /etc/kubernetes/manifests
kubectl -n kube-system get pod kube-scheduler-kcna \
  -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.mirror}{"\n"}{.metadata.ownerReferences[0].kind}{"\n"}'
```
- What object owns the scheduler pod? How is that different from a pod created by a Deployment?
- Try `kubectl -n kube-system delete pod kube-scheduler-kcna`, then list the pods again. What happened, and why?

### 3. etcd: the cluster's database
```bash
ETCD="kubectl -n kube-system exec etcd-kcna -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/minikube/certs/etcd/ca.crt \
  --cert=/var/lib/minikube/certs/etcd/server.crt \
  --key=/var/lib/minikube/certs/etcd/server.key"

$ETCD get /registry/namespaces --prefix --keys-only
kubectl create configmap etcd-demo --from-literal=hello=world
$ETCD get /registry/configmaps/default/etcd-demo --keys-only
kubectl delete configmap etcd-demo
```
- Which component is the only one allowed to read and write etcd?
- What's lost if etcd is lost?

### 4. The API server
```bash
kubectl get --raw '/readyz?verbose' | tail -5
kubectl get deploy -A -v=6 2>&1 | grep -E 'GET|Response'
kubectl api-resources | head -20
kubectl explain deployment.spec.strategy
```
- What HTTP method and URL does `kubectl get deploy` use?
- What's the difference between `/api/v1` and `/apis/apps/v1`?

### 5. Trace a Deployment
```bash
kubectl apply -f manifests/hello-deployment.yaml
kubectl -n kcna-arch rollout status deploy/hello
kubectl -n kcna-arch get deploy,rs,pods -o wide
kubectl events -n kcna-arch
```
Match each event to the component that produced it:

| Event | Produced by |
|---|---|
| `ScalingReplicaSet` | ? |
| `SuccessfulCreate` | ? |
| `Scheduled` | ? |
| `Pulling` / `Created` / `Started` | ? |

### 6. Self-healing (controllers)
```bash
kubectl -n kcna-arch delete pod -l app=hello --wait=false
kubectl -n kcna-arch get pods -w     # Ctrl+C when 3 are Running
```
- Which controller noticed, and what did it compare?

### 7. Node components
```bash
minikube -p kcna ssh -n kcna-m02 -- systemctl is-active kubelet
minikube -p kcna ssh -n kcna-m02 -- sudo crictl ps
kubectl -n kube-node-lease get lease
```
- Is the kubelet a pod? How is it run?
- What does `crictl` talk to?
- What are the leases in `kube-node-lease` for?

### 8. kube-proxy and Services
```bash
kubectl -n kube-system logs ds/kube-proxy | grep -i proxier
kubectl -n kcna-arch get svc hello
kubectl -n kcna-arch get endpointslices
minikube -p kcna ssh -n kcna-m02 -- "sudo iptables -t nat -L KUBE-SERVICES -n | grep kcna-arch"
```
- Which mode is kube-proxy using?
- How does the Service find its pods?

### 9. Break it: stop the scheduler
```bash
minikube -p kcna ssh -- sudo mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/
kubectl -n kube-system get pods -l component=kube-scheduler     # gone
kubectl -n kcna-arch scale deploy/hello --replicas=5
kubectl -n kcna-arch get pods                                  # what status?
minikube -p kcna ssh -- sudo mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/
kubectl -n kcna-arch get pods -w
```
- Which status did the new pods have, and why?
- Did the existing pods stop? What does that tell you about the control plane vs. running workloads?

## Cleanup
```bash
kubectl delete namespace kcna-arch
```

## Lab vs. production
- minikube runs one control-plane node and sets `--leader-elect=false`. In production with several control-plane
  nodes, the scheduler and controller-manager use **leader election** (Lease objects in `kube-system`) so only one
  instance is active at a time.
- minikube doesn't taint its control-plane node, so your pods can run there. Most clusters add the
  `node-role.kubernetes.io/control-plane:NoSchedule` taint (see Module 05).
- Managed services (AKS, EKS, GKE) run the control plane for you, and you never see these static pods.

## Exam notes
- **kube-apiserver:** the front door for all clients; the only component that talks to etcd; handles authentication, authorization and admission.
- **etcd:** a consistent, distributed key-value store holding all cluster state. Back it up.
- **kube-scheduler:** picks a node for each unscheduled pod. It doesn't start the pod.
- **kube-controller-manager:** runs control loops that move the current state toward the desired state.
- **cloud-controller-manager:** connects to a cloud provider for load balancers, routes and nodes.
- **kubelet:** an agent on every node; runs pods via CRI and reports node and pod status.
- **kube-proxy:** programs Service routing (iptables, IPVS or nftables). Some CNIs, such as Cilium, can replace it.
- **Container runtime:** containerd or CRI-O, using runc to create containers.

## Practice questions
1. Which component stores the desired state of the cluster?
2. A pod is stuck in `Pending` with no events. Which component is most likely down?
3. Which component restarts a pod on a node when its container crashes?
4. Can kubectl talk to etcd directly?
5. What creates the pods for a Deployment: the Deployment controller, the ReplicaSet controller or the scheduler?
6. Where do static pod manifests live by default, and which component reads them?
7. Which component is optional when the CNI provides Service load balancing?
8. What's the purpose of node Leases in `kube-node-lease`?

Answers: [solutions/README.md](solutions/README.md)
