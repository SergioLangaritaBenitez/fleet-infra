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

## OSCAR app env (namespace `oscar`)

Todas las env vars del Deployment están divididas (ver
`oscar/apps/base/oscar/`):

* `ConfigMap/oscar-env` (`configmap.yaml`, en Git, aplicado por Flux).
* `Secret/oscar-credentials` (6 claves **sensibles**) — fuera de Git,
  creado a mano. Sin él, el Pod falla al arrancar (fail-fast).
  Claves: `OSCAR_USERNAME`, `OSCAR_PASSWORD`, `MINIO_ACCESS_KEY`,
  `MINIO_SECRET_KEY`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`.

Crear (ejemplo):

```bash
ssh my_cluster "sudo kubectl -n oscar create secret generic oscar-credentials \
  --from-literal=OSCAR_USERNAME=<oscar-user> \
  --from-literal=OSCAR_PASSWORD=<oscar-password> \
  --from-literal=MINIO_ACCESS_KEY=<minio-user> \
  --from-literal=MINIO_SECRET_KEY=<minio-password> \
  --from-literal=OIDC_CLIENT_ID= \
  --from-literal=OIDC_CLIENT_SECRET= \
  --dry-run=client -o yaml | sudo kubectl apply -f -"
```

> `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` deben coincidir con
> `Secret/minio-root-credentials` (ns `minio`).
> Alternativa con fichero: copiar `secrets/oscar-credentials.env.example`
> a `secrets/oscar-credentials.env` (gitignored) y usar `--from-env-file`.
> El antiguo `Secret/oscar-config` de 6 claves queda sustituido por este.

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
