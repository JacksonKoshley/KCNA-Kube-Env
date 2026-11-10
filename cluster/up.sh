#!/usr/bin/env bash
# Create (or start) the kcna minikube profile and install Cilium.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.env

# containerd needs a CNI when the cluster is created, so Cilium is rendered to a
# manifest and passed to minikube with --cni. minikube re-reads that file on every
# start, so it lives at a stable path and is re-rendered each run to match the values.
CILIUM_MANIFEST="${HOME}/.minikube/cni/${PROFILE}-cilium.yaml"
mkdir -p "$(dirname "${CILIUM_MANIFEST}")"
helm repo add cilium https://helm.cilium.io >/dev/null 2>&1 || true
helm repo update cilium >/dev/null
helm template cilium cilium/cilium \
  --namespace kube-system \
  --version "${CILIUM_VERSION}" \
  --values cilium-values.yaml > "${CILIUM_MANIFEST}"

if [[ -f "${HOME}/.minikube/profiles/${PROFILE}/config.json" ]]; then
  echo ">> Profile ${PROFILE} exists, starting it"
  minikube start -p "${PROFILE}"
else
  echo ">> Creating profile ${PROFILE} (${NODES} nodes, ${CPUS} CPU / ${MEMORY}MB each)"
  minikube start -p "${PROFILE}" \
    --driver="${DRIVER}" \
    --container-runtime="${CONTAINER_RUNTIME}" \
    --nodes="${NODES}" \
    --cpus="${CPUS}" \
    --memory="${MEMORY}" \
    --kubernetes-version="${K8S_VERSION}" \
    --cni="${CILIUM_MANIFEST}"
fi

kubectl config use-context "${PROFILE}"

# Helm takes ownership of the bootstrap objects. --force-conflicts lets it take over
# fields that kubectl set when minikube applied the manifest.
echo ">> Installing Cilium ${CILIUM_VERSION}"
helm upgrade --install cilium cilium/cilium \
  --kube-context "${PROFILE}" \
  --namespace kube-system \
  --version "${CILIUM_VERSION}" \
  --values cilium-values.yaml \
  --take-ownership \
  --force-conflicts \
  --wait --timeout 10m

echo ">> Enabling addons"
minikube -p "${PROFILE}" addons enable metrics-server

./verify.sh
