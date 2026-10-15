#!/bin/bash
# Example: recreate all out-of-band cluster Secrets.
# Copy the commands, replace <PLACEHOLDERS>, and run them against the target
# cluster. Real values must NEVER be committed to Git.
# See secrets/README.md for details on each Secret.
set -euo pipefail

KUBECTL="sudo kubectl"
CLUSTER_SSH="ssh my_cluster"

# ---------------------------------------------------------------------------
# 1. MinIO root credentials (namespace: minio)
#    Referenced by: existingSecret in
#    oscar/infrastructure/storage/minio/minio-release.yaml
#    NOTE: the name must differ from `minio` (the chart owns that one).
# ---------------------------------------------------------------------------
# $CLUSTER_SSH "$KUBECTL -n minio create secret generic minio-root-credentials \
#   --from-literal=rootUser=<minio-user> \
#   --from-literal=rootPassword=<minio-password> \
#   --dry-run=client -o yaml | $KUBECTL apply -f -"

# ---------------------------------------------------------------------------
# 2. Per-cluster gateway TLS names/hosts (namespace: flux-system)
#    Consumed by: postBuild.substituteFrom in
#    oscar/environment/devel/networking.yaml and storage.yaml
# ---------------------------------------------------------------------------
# $CLUSTER_SSH "$KUBECTL -n flux-system create secret generic gateway-tls-config \
#   --from-literal=GATEWAY_HOST_APEX=<oscar-dns> \
#   --from-literal=GATEWAY_HOST_BASE=<oscar-dns> \
#   --from-literal=GATEWAY_TLS_APEX=<oscar-dns>-tls \
#   --from-literal=GATEWAY_TLS_WILDCARD=wildcard-<oscar-dns>-tls \
#   --dry-run=client -o yaml | $KUBECTL apply -f -"
#
# The referenced TLS Secrets must exist in the Gateway namespace (traefik),
# usually issued by cert-manager Certificate objects (also per cluster).

# ---------------------------------------------------------------------------
# 3. SOPS age key (namespace: flux-system)
#    Consumed by: decryption.provider=sops in Kustomizations that apply
#    encrypted manifests. BACK UP ~/.config/sops/age/keys.txt off-cluster.
# ---------------------------------------------------------------------------
# age-keygen -o ~/.config/sops/age/keys.txt   # run once, keep private
# $CLUSTER_SSH "$KUBECTL -n flux-system create secret generic sops-age \
#   --from-file=age.agekey=$HOME/.config/sops/age/keys.txt \
#   --dry-run=client -o yaml | $KUBECTL apply -f -"

# ---------------------------------------------------------------------------
# 4. OSCAR app config (namespace: oscar, managed BY Flux via SOPS)
#    Generated with flux, encrypted with sops, committed to
#    oscar/infrastructure/secrets/oscar-config.yaml
# ---------------------------------------------------------------------------
# flux create secret generic oscar-config -n oscar \
#   --from-env-file=secrets/oscar-config.env \
#   --export > oscar/infrastructure/secrets/oscar-config.yaml
# sops --encrypt --in-place oscar/infrastructure/secrets/oscar-config.yaml
#
# With secrets/oscar-config.env containing (gitignored, never commit):
#   OSCAR_USERNAME=<oscar-user>
#   OSCAR_PASSWORD=<oscar-password>
#   MINIO_ACCESS_KEY=<minio-user>        # must match minio-root-credentials
#   MINIO_SECRET_KEY=<minio-password>    # must match minio-root-credentials
#   MINIO_TLS_VERIFY=false
#   MINIO_ENDPOINT=https://storage-<oscar-dns>
