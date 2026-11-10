# Module 00: Solutions

**Step 4:** `cilium` and `kube-proxy` run on every node (they're DaemonSets). `etcd`, `kube-apiserver`,
`kube-scheduler` and `kube-controller-manager` run only on the control plane (they're static pods).
`coredns` and `cilium-operator` are Deployments, so they can land on any node.

## Practice questions
1. The **kubelet**.
2. They stay in `ContainerCreating`, and nodes report `NotReady` with "network plugin not ready".
3. CNI: Cilium, Calico, Flannel, Weave. CRI runtimes: containerd, CRI-O.
4. Docker builds **OCI** images, and containerd runs any OCI image.
