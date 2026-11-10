# KCNA exam domains

Source: the official CNCF curriculum (github.com/cncf/curriculum). Check there for the current version.

| | |
|---|---|
| Format | Online, proctored, multiple choice |
| Time | 90 minutes |
| Pass mark | 75% |

## D1 Kubernetes Fundamentals (44%)
- **Core Concepts:** control plane and node components, Pods, Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs, CronJobs, namespaces, labels and selectors
- **Administration:** kubectl, the API, cluster lifecycle, nodes
- **Scheduling:** scheduler, requests and limits, taints and tolerations, affinity
- **Containerization:** images, OCI, container runtimes (containerd, CRI)

## D2 Container Orchestration (28%)
- **Networking:** Services, DNS, CNI, Ingress, Gateway API, NetworkPolicy, service mesh
- **Security:** RBAC, ServiceAccounts, Secrets, Pod Security, securityContext
- **Troubleshooting:** `describe`, `logs`, events, common pod states
- **Storage:** PV, PVC, StorageClass, access modes, CSI

## D3 Cloud Native Application Delivery (16%)
- **Application Delivery:** GitOps (Argo CD, Flux), CI/CD, Helm, Kustomize, rollout strategies
- **Debugging:** debugging applications in a cluster

## D4 Cloud Native Architecture (12%)
- **Observability:** metrics, logs, traces, Prometheus, OpenTelemetry
- **Ecosystem and Principles:** CNCF landscape, maturity levels, autoscaling, serverless, open standards (OCI, CRI, CNI, CSI)
- **Community and Collaboration:** CNCF TOC, TAGs, Kubernetes SIGs, KEPs
