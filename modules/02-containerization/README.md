# Module 02: Containerization

**Domain:** D1 Kubernetes Fundamentals · Containerization

Build a container image, see what's inside it, get it into the cluster, and look at how containerd and the Linux
kernel actually run it.

## Objectives
- Write a multi-stage Dockerfile and explain why it produces a smaller, safer image
- Explain image layers, tags, digests and the OCI specs
- Load a local image into a cluster and predict `imagePullPolicy` behavior
- Use `crictl` to see what the kubelet asks containerd to do
- Show that a container is just a Linux process in namespaces and cgroups

## Background

```
Dockerfile ──docker build──► OCI image ──push / load──► registry or node
                                                          │
kubelet ──CRI (gRPC)──► containerd ──► runc ──► process in namespaces + cgroups
```

| Spec | Defines | Example |
|---|---|---|
| OCI **Image** spec | Image format: manifest, config, layers | What `docker build` produces |
| OCI **Runtime** spec | How to run a container from a filesystem bundle | runc, crun |
| OCI **Distribution** spec | Registry API for push and pull | Docker Hub, GHCR, Harbor |
| **CRI** (Kubernetes) | API between the kubelet and a runtime | containerd, CRI-O |

The demo app lives in [`app/`](../../app/). It's a small Go HTTP server that returns its version, hostname and user ID.
Later modules reuse it.

## Steps

Run the commands from the repo root unless a step says otherwise.

### 1. Build two images and compare
```bash
docker build -t demo-app:v1 --build-arg VERSION=v1 app
docker build -t demo-app:single -f app/Dockerfile.single app
docker images | grep demo-app
```
Read [`app/Dockerfile`](../../app/Dockerfile) and [`app/Dockerfile.single`](../../app/Dockerfile.single).
- Why is one image about 30 times bigger than the other?
- What does `COPY --from=build` do?

### 2. Run them and compare
```bash
docker run -d --name multi  -p 18080:8080 demo-app:v1
docker run -d --name single -p 18081:8080 demo-app:single
curl -s localhost:18080/ ; echo
curl -s localhost:18081/ ; echo
docker exec multi sh
docker exec single id
```
- Which one runs as root? Where is that decided?
- Why does `docker exec multi sh` fail? Is that good or bad?

### 3. Layers
```bash
docker history demo-app:v1
docker history demo-app:single
docker image inspect demo-app:v1 --format '{{len .RootFS.Layers}} layers'
```
- Which instructions add layers with size, and which only change metadata?
- In the Dockerfile, why is `go.mod` copied before `main.go`?

### 4. The OCI image layout
```bash
docker save demo-app:v1 -o /tmp/demo-v1.tar
tar tf /tmp/demo-v1.tar | head
tar xOf /tmp/demo-v1.tar oci-layout ; echo
tar xOf /tmp/demo-v1.tar index.json ; echo
rm /tmp/demo-v1.tar
```
- What are the files in `blobs/sha256/` named after?
- Any OCI-compliant runtime can run this image. Which one will run it in our cluster?

### 5. Signals
```bash
docker stop multi
docker logs multi
docker rm -f multi single
```
- What signal did `docker stop` send? Kubernetes does the same when it deletes a pod. What happens if the app
  ignores it?

### 6. Tags are mutable
```bash
docker image inspect demo-app:v1 --format '{{.Id}}'
docker build -q -t demo-app:v1 --build-arg VERSION=v1-hotfix app
docker image inspect demo-app:v1 --format '{{.Id}}'
docker build -q -t demo-app:v1 --build-arg VERSION=v1 app      # put it back
```
- Same tag, different image. Why is that dangerous on a cluster where nodes cache images?

### 7. Get the image into the cluster
The cluster runs containerd inside each node, not your local Docker, so it can't see `demo-app:v1` yet.
```bash
minikube -p kcna image load demo-app:v1      # or: make image
for n in kcna kcna-m02 kcna-m03; do minikube -p kcna ssh -n $n -- sudo crictl images | grep demo-app; done
```
In a real cluster you would push to a registry instead. `image load` copies the image onto every node.

### 8. imagePullPolicy
```bash
cd modules/02-containerization
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/pod-v1.yaml -f manifests/pod-latest.yaml -f manifests/pod-pull-always.yaml
kubectl -n kcna-images get pods
kubectl -n kcna-images get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,POLICY:.spec.containers[0].imagePullPolicy
kubectl -n kcna-images describe pod demo-latest | grep -A10 Events
```
None of these manifests sets a policy except `pod-pull-always.yaml`.
- Why does `demo-v1` run while `demo-latest` fails?
- `demo-always` uses the same `demo-app:v1` that's already on every node. Why does it fail?
- What full image name did the kubelet try to pull for `demo-app:latest`?

### 9. Inside a distroless pod
```bash
kubectl -n kcna-images port-forward pod/demo-v1 18090:8080 &
curl -s localhost:18090/ ; echo
kill %1
kubectl -n kcna-images exec demo-v1 -- sh
```
- What's the pod's hostname? What user ID does the app run as?
- How would you debug a container with no shell? (Hint: Module 09.)

### 10. Pin by digest
```bash
docker buildx imagetools inspect nginx:1.29-alpine | head -3
```
Copy the `Digest` value into `manifests/pod-digest.yaml` in place of `REPLACE_ME`, then:
```bash
kubectl apply -f manifests/pod-digest.yaml
kubectl -n kcna-images get pod web-digest -o jsonpath='{.status.containerStatuses[0].imageID}{"\n"}'
```
- Why is a digest safer than a tag for production?

### 11. A container is a process
```bash
kubectl apply -f manifests/pod-isolation.yaml
kubectl -n kcna-images exec isolation -- ps
kubectl -n kcna-images exec isolation -- hostname
kubectl -n kcna-images exec isolation -- cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/cpu.max
```
Now look at the same container from the node:
```bash
NODE=$(kubectl -n kcna-images get pod isolation -o jsonpath='{.spec.nodeName}')
minikube -p kcna ssh -n $NODE
# inside the node:
sudo crictl pods --name isolation
CID=$(sudo crictl ps --name shell -q)
sudo crictl inspect $CID | grep -E '"runtimeType"|"memory_limit_in_bytes"|"cpu_quota"'
PID=$(sudo crictl inspect -o go-template --template '{{.info.pid}}' $CID)
ps -o pid,user,cmd -p $PID
sudo ls -l /proc/$PID/ns
sudo ls -l /proc/1/ns
sudo ctr namespaces ls
sudo crictl images | grep pause
exit
```
- Inside the container `sleep` is PID 1. What's its PID on the node?
- Which namespace IDs differ between the container and the node's PID 1?
- How do `memory.max` and `cpu.max` relate to the pod's `limits`?
- What is the `pause` image for?
- Why does `ctr` show a `k8s.io` namespace?

## Cleanup
```bash
kubectl delete namespace kcna-images
git checkout manifests/pod-digest.yaml
```
Keep `demo-app:v1` loaded; later modules use it.

## Exam notes
- **Container vs VM:** containers share the host kernel and are isolated with **namespaces** (what a process can
  see) and **cgroups** (what it can use). VMs each run their own kernel on a hypervisor.
- **Image** = layers plus config and a manifest, all addressed by SHA-256 **digest**. Tags are mutable pointers;
  digests are immutable.
- **Multi-stage builds** keep compilers and build tools out of the final image: smaller size, fewer CVEs.
- **Default imagePullPolicy:** `Always` for `:latest` or no tag; `IfNotPresent` otherwise. `Never` uses only local
  images.
- `ImagePullBackOff` / `ErrImagePull`: wrong name or tag, a private registry without `imagePullSecrets`, or the
  network.
- **Runtimes:** high-level (containerd, CRI-O) manage images and lifecycle; low-level (runc, crun) create the
  container. Sandboxed runtimes (gVisor, Kata Containers) add a stronger isolation boundary.
- **dockershim** was removed in Kubernetes v1.24. Docker-built images still run because they're OCI images.
- Each pod has a **pause** (sandbox) container that holds the shared network namespace for all its containers.

## Practice questions
1. Which Linux features provide container isolation and resource limits?
2. What's the default `imagePullPolicy` for `nginx`? For `nginx:1.29`?
3. Name the three OCI specifications.
4. Which component talks to containerd, and through which interface?
5. Name a low-level runtime and a sandboxed runtime.
6. Why might two nodes run different code for the same `app:v1` tag?
7. A pod shows `ErrImagePull` for a private registry image. What's the usual fix?
8. Why did Kubernetes v1.24 not break Docker-built images?
9. What does the pause container do?

Answers: [solutions/README.md](solutions/README.md)
