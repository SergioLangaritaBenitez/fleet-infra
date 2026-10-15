Folder to store the secret values for the cluster needs.

> Files with real values (`*.yaml`, `*.env`) are gitignored.
> Only this README is committed. Never push credentials to Git.

## MinIO (namespace `minio`)

The chart reads the root credentials from `Secret/minio-root-credentials`
(`.data.rootUser` + `.data.rootPassword`), referenced with
`existingSecret: minio-root-credentials` in
`oscar/infrastructure/storage/minio/minio-release.yaml`.
Flux does not manage that Secret: it lives in the cluster and must be
kept out of Git.

> Important: the name must differ from `minio`, because the
> `Secret/minio` is created by the chart itself and Helm deletes it on
> every `upgrade` once it stops being rendered.

Show current values (read-only):

```bash
ssh my_cluster "sudo kubectl -n minio get secret minio-root-credentials -o jsonpath='{.data}'"
```

Rotate credentials:

```bash
ssh my_cluster "sudo kubectl -n minio create secret generic minio-root-credentials \
  --from-literal=rootUser=<new-user> \
  --from-literal=rootPassword=<new-password> \
  --dry-run=client -o yaml | sudo kubectl apply -f -"
sudo kubectl -n minio rollout restart deploy/minio  # if needed
```

If the Secret does not exist, `HelmRelease/minio` fails: create it with
the command above before the first reconcile.

## Per-cluster gateway TLS (namespace `flux-system`)

Hostnames and TLS Secret names vary per cluster, so
`oscar/infrastructure/networking/gateway.yaml` and
`oscar/infrastructure/storage/minio/minio-release.yaml` use variables
(`${GATEWAY_HOST_APEX}`, `${GATEWAY_HOST_BASE}`,
`${GATEWAY_TLS_APEX}`, `${GATEWAY_TLS_WILDCARD}`) that Flux substitutes
from `Secret/gateway-tls-config` (via `postBuild.substituteFrom`
in `oscar/environment/devel/networking.yaml` and `storage.yaml`).

Create per cluster (example):

```bash
ssh my_cluster "sudo kubectl -n flux-system create secret generic gateway-tls-config \
  --from-literal=GATEWAY_HOST_APEX=<oscar-dns> \
  --from-literal=GATEWAY_HOST_BASE=<oscar-dns> \
  --from-literal=GATEWAY_TLS_APEX=<oscar-dns>-tls \
  --from-literal=GATEWAY_TLS_WILDCARD=wildcard-<oscar-dns>-tls \
  --dry-run=client -o yaml | sudo kubectl apply -f -"
```

The referenced TLS Secrets must exist in the Gateway namespace
(`traefik`): usually created by cert-manager with `Certificate`
objects (also outside Git, one per cluster).

If `Secret/gateway-tls-config` is missing,
`Kustomization/networking` fails with an undefined variable (fail-fast).
