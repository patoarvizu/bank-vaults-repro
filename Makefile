start: check-kubeconfig cluster import apply

restart: destroy start

destroy:
	k3d cluster delete

check-kubeconfig:
	@test $(KUBECONFIG) || (echo "KUBECONFIG override is not set"; exit 1)

cluster: check-kubeconfig
	k3d cluster get k3s-default || k3d cluster create --port 8200:8200@loadbalancer  --k3s-arg "--no-deploy=traefik@server:*" --k3s-arg "--no-deploy=metrics-server@server:*" --k3s-arg "--kube-apiserver-arg=feature-gates=ServerSideApply=false@server:*" --wait

import:
	k3d image import patoarvizu/bank-vaults:latest

apply:
	helmfile apply

sync:
	helmfile sync

get-root-token:
	@kubectl -n vault get secret vault-unseal-keys -o json | jq -r '.data["vault-root"]' | base64 -D