#!/usr/bin/env bash
# Stop the cluster (keeps state). Use DELETE=1 to remove it completely.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.env
if [[ "${DELETE:-0}" == "1" ]]; then
  minikube delete -p "${PROFILE}"
  rm -f "${HOME}/.minikube/cni/${PROFILE}-cilium.yaml"
else
  minikube stop -p "${PROFILE}"
fi
