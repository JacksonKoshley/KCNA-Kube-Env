#!/usr/bin/env bash
# Check that the kcna cluster is healthy.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.env
K="kubectl --context ${PROFILE}"

echo ">> Nodes"
${K} get nodes -o wide
echo
echo ">> Waiting for nodes to be Ready"
${K} wait --for=condition=Ready nodes --all --timeout=300s
echo
echo ">> Waiting for Cilium"
${K} -n kube-system rollout status daemonset/cilium --timeout=300s
${K} -n kube-system rollout status deployment/cilium-operator --timeout=300s
echo
echo ">> Waiting for CoreDNS"
${K} -n kube-system rollout status deployment/coredns --timeout=300s
echo
echo ">> DNS smoke test"
${K} run dns-test --rm -i --restart=Never --image=busybox:1.37 -- nslookup kubernetes.default.svc.cluster.local
echo
echo "Cluster ${PROFILE} is ready."
