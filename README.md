# KCNA-Kube-Env

A hands-on Kubernetes lab for studying for the **KCNA (Kubernetes and Cloud Native Associate)** exam.
Every module runs on a local multi-node [minikube](https://minikube.sigs.k8s.io/) cluster and maps to an exam domain.

## Exam domains

| Domain | Weight | Modules |
|---|---|---|
| D1 Kubernetes Fundamentals | 44% | 01–05 |
| D2 Container Orchestration | 28% | 06–09 |
| D3 Cloud Native Application Delivery | 16% | 10 |
| D4 Cloud Native Architecture | 12% | 11–12 |

See [docs/kcna-domains.md](docs/kcna-domains.md) for the full breakdown.

## Prerequisites

- Docker, minikube, kubectl, Helm
- About 6 CPUs and 11 GB RAM free for the default 3-node cluster

## Quick start

```bash
make up        # create/start the 3-node "kcna" cluster with Cilium
make verify    # health check
make down      # stop the cluster (keeps state)
make destroy   # delete the cluster
```

The cluster uses its own minikube profile and kube-context named `kcna`, so it doesn't touch other clusters.
Cluster settings live in [cluster/config.env](cluster/config.env).

## Modules

Each module has a `README.md` with objectives, guided steps, exam notes and practice questions.
Try the steps yourself first; answers are in each module's `solutions/` folder.

| # | Module | Domain | Status |
|---|---|---|---|
| 00 | [Setup](modules/00-setup/) | — | ✅ |
| 01 | [Architecture](modules/01-architecture/) | D1 Core Concepts | ✅ |
| 02 | Containerization | D1 Containerization | ⬜ |
| 03 | Workloads | D1 Core Concepts | ⬜ |
| 04 | Probes and Resources | D1 Core Concepts / Scheduling | ⬜ |
| 05 | Scheduling | D1 Scheduling / Administration | ⬜ |
| 06 | Networking | D2 Networking | ⬜ |
| 07 | Security | D2 Security | ⬜ |
| 08 | Storage | D2 Storage | ⬜ |
| 09 | Troubleshooting | D2 Troubleshooting / D3 Debugging | ⬜ |
| 10 | Application Delivery (Helm, Kustomize, Argo CD) | D3 Application Delivery | ⬜ |
| 11 | Observability | D4 Observability | ⬜ |
| 12 | Ecosystem and Autoscaling | D4 Ecosystem and Principles | ⬜ |
