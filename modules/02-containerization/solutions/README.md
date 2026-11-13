# Module 02: Solutions

## Steps

**1.** `demo-app:single` ships the whole Go toolchain and Alpine (about 490 MB). The multi-stage image keeps only the
compiled binary on a distroless base (about 15 MB). `COPY --from=build` copies files out of an earlier stage, so
nothing else from that stage ends up in the final image.

**2.** `single` runs as **root** (uid 0) because it never sets a user. `multi` runs as **uid 65532** (`nonroot`)
because of `USER nonroot:nonroot` in the Dockerfile. `sh` fails because distroless images contain no shell.
That's good for security, since an attacker who gets in has no tools to use, but it makes debugging harder.

**3.** `COPY` and `RUN` add filesystem layers with size. `USER`, `EXPOSE`, `ENTRYPOINT` and `CMD` only change the
image config (0 B). `go.mod` is copied first so the dependency layer stays cached while only the source code changes.
Fewer layers is not the goal: `single` has fewer layers but is about 30 times larger.

**4.** Each blob is named after the **SHA-256 digest of its content**: the index, manifest, config and each layer.
This is content addressing. Our cluster runs it with **containerd**, which uses **runc**.

**5.** `SIGTERM`, and the log shows the app shutting down cleanly. If the app ignores it, it's force-killed with
`SIGKILL` when the grace period ends (10 s for Docker, `terminationGracePeriodSeconds` = 30 s by default in
Kubernetes). In-flight requests are dropped.

**6.** A tag is just a pointer and can be moved to different content. With `IfNotPresent`, a node that already
cached the old `v1` keeps running it, while a new node pulls the new one. The cluster then runs two versions under
one tag. Use unique tags per build (for example the Git SHA) or digests.

**7.** Every node has `docker.io/library/demo-app:v1`. Short names get `docker.io/library/` added.

**8.**
- `demo-v1`: the tag isn't `latest`, so the policy defaults to **IfNotPresent**. The image is on the node, so no pull.
- `demo-latest`: `:latest` defaults to **Always**. The kubelet asks Docker Hub for `docker.io/library/demo-app:latest`,
  which doesn't exist, so `ErrImagePull` then `ImagePullBackOff`.
- `demo-always`: **Always** contacts the registry even if the image is cached. The image was never pushed, so the
  pull fails.

**9.** The hostname is the **pod name** (`demo-v1`), and the uid is 65532. To debug a container without a shell, use
`kubectl debug` to add an ephemeral debug container that shares the pod's namespaces.

**10.** A digest identifies exact content and can't be changed. Every node runs the same bytes, and a compromised
or re-pushed tag can't swap the image under you. The `imageID` in the status shows the digest the node actually ran.

**11.**
- On the node, `sleep` has a normal host PID (for example 3855), not 1. The PID namespace only remaps how the
  container sees it.
- `pid`, `mnt`, `uts`, `ipc`, `net` and `cgroup` differ. `user` is usually shared unless user namespaces are enabled.
- `memory.max` = 67108864 bytes = the 64Mi limit. `cpu.max` = `25000 100000`: 25 ms of CPU per 100 ms period, which
  is the 250m limit. Requests guide scheduling; limits become cgroup settings.
- The **pause** container holds the pod's network (and IPC) namespace so the app containers can join it, restart,
  and keep the same pod IP.
- containerd namespaces separate clients. The CRI plugin stores Kubernetes images and containers in `k8s.io`, so
  they don't mix with other clients such as Docker (`moby`).

## Practice questions
1. **Namespaces** (isolation) and **cgroups** (resource limits).
2. `nginx` (no tag means `latest`): `Always`. `nginx:1.29`: `IfNotPresent`.
3. Image spec, Runtime spec, Distribution spec.
4. The **kubelet**, through the **CRI** (gRPC).
5. Low-level: runc or crun. Sandboxed: gVisor (runsc) or Kata Containers.
6. The tag was re-pushed with new content, and the nodes cached different versions under `IfNotPresent`.
7. Create a `docker-registry` Secret and reference it in `imagePullSecrets` (on the pod or its ServiceAccount).
8. Docker builds standard **OCI** images, which containerd and CRI-O run. Only the Docker *runtime* integration
   (dockershim) was removed.
9. It's the pod's sandbox and holds the shared network namespace (one IP per pod) for all its containers.
