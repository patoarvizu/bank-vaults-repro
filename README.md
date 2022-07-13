# bank-vaults-repro

Reproduction repo for PRs/issues with Banzai Cloud's bank-vaults

# Prerequisites

* `make`
* [`k3d`](https://github.com/k3d-io/k3d)
* [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)
  * Alternatively, you can use any other Kubernetes API interaction tool like [`k9s`](https://k9scli.io/topics/install/).
* [`helm`](https://helm.sh/docs/intro/install/)
* [`helmfile`](https://github.com/roboll/helmfile)
* [`vault`](https://www.vaultproject.io/downloads)
* Have the [bank-vaults](https://github.com/banzaicloud/bank-vaults) repo (or a fork of it, e.g. [patoarvizu/bank-vaults](https://github.com/patoarvizu/bank-vaults)) cloned locally.

# Reproducing feature in PR [1651](https://github.com/banzaicloud/bank-vaults/pull/1651)

This repo deploys a `Vault` object in a local Kubernetes instance that leverages the feature introduced in bank-vaults PR [1651](https://github.com/banzaicloud/bank-vaults/pull/1651) to use placeholders for mount accessor ids in templated policies.

* Go to the directory where the [patoarvizu/bank-vaults](https://github.com/patoarvizu/bank-vaults) clone is, and checkout the `parameterize-mount-accessor` branch.
* Run `DOCKER_REGISTRY=patoarvizu DOCKER_TAG=latest make docker`.
* Set `KUBECONFIG` to a k3d-specific file, to avoid having your default configuration or default Kubernetes edited by accident, e.g. `export KUBECONFIG=~/.k3d/k3s-default-config`.
* Run `make start`, wait for all charts to finish installing.
  * This installs the following:
    * The bank-vaults operator.
    * A `Vault` instance with pre-configured roles, a templated policy, and startup secrets.
    * A `cert-manager` instance.
    * The `vault-secrets-webhook`.
    * Demo cronjobs running workloads on different namespaces that echo secrets injected by the `vault-secrets-webhook`, fetched from prefixed that they should/shouldn't have access to.
* Run `export VAULT_ADDR=http://localhost:8200`.
* Run `export VAULT_TOKEN=$(make get-root-token)`.
* Run `vault policy read templated`.
  * It should display the something like the following, with the correct interpolation of the `${ accessor ... }` placeholder defined in the `Vault` object:
```
path "secret/data/{{identity.entity.aliases.auth_kubernetes_abcd1234.metadata.service_account_namespace}}" {
  capabilities = ["read"]
}
```
* Inspect the workloads in the `repro-ns1` namespace, i.e. `kubectl -n repro-ns1 get pods`. If you don't see any pods yet, wait up to one minute until Kubernetes schedules the next cronjob run.
* You'll see you'll have one pod called something like `echo-secret-found-01234567--1-abcde` in `Completed` status, and another one called `echo-secret-not-found-76543210--1-edcba` in either `Error` or `CrashLoopBackOff` status.
* Inspect the logs of the `echo-secret-found` pod with `kubectl -n repro-ns1 logs -l secret=found`.
  * You should see a line that says `Found secret foo at secret/data/repro-ns1`.
* Inspect the logs of the `echo-secret-not-found` pod with `kubectl -n repro-ns1 logs -l secret=not-found`.
  * You should see a line with an error that says `failed to inject secrets from vault: failed to read secret from path: secret/data/repro-ns2: Error making API request.\n\nURL: GET http://vault.vault:8200/v1/secret/data/repro-ns2?version=-1\nCode: 403. Errors:\n\n* 1 error occurred:\n\t* permission denied\n\n"`.
* Conversely, inspect the analogous workloads in the `repro-ns2` namespaces, and you'll see that the pattern is the same, the `secret-found` pods could fetch secret `bar` from `secret/data/repro-ns2`, but the `secret-not-found` pods fail when trying to fetch secrets from `secret/data/repro-ns1`.