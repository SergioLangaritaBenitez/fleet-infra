Folder to store the secret values for the cluster needs.

> Los ficheros con valores reales (`*.yaml`, `*.env`) están gitignored.
> Solo este README se commitea. Nunca subas credenciales a Git.

## MinIO (namespace `minio`)

Las credenciales root las lee el chart desde el `Secret/minio`
(`.data.rootUser` + `.data.rootPassword`), referenciado con
`existingSecret: minio` en
`oscar/infrastructure/storage/minio/minio-release.yaml`.
Flux no gestiona ese Secret: existe en el clúster y hay que
mantenerlo fuera de Git.

Ver valores actuales (solo lectura):

```bash
ssh my_cluster "sudo kubectl -n minio get secret minio -o jsonpath='{.data}'"
```

Rotar credenciales:

```bash
ssh my_cluster "sudo kubectl -n minio create secret generic minio \
  --from-literal=rootUser=<nuevo-usuario> \
  --from-literal=rootPassword=<nueva-password> \
  --dry-run=client -o yaml | sudo kubectl apply -f -"
sudo kubectl -n minio rollout restart deploy/minio  # si aplica
```

Si el Secret no existe, el `HelmRelease/minio` falla: créalo con el
comando anterior antes del primer reconcile.
