PROFILE ?= kcna

.PHONY: help up verify down destroy status
help:  ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

up:  ## Create or start the cluster and install Cilium
	./cluster/up.sh

verify:  ## Check cluster health
	./cluster/verify.sh

down:  ## Stop the cluster (keeps state)
	./cluster/down.sh

destroy:  ## Delete the cluster
	DELETE=1 ./cluster/down.sh

status:  ## Show minikube and node status
	minikube -p $(PROFILE) status; kubectl --context $(PROFILE) get nodes -o wide
