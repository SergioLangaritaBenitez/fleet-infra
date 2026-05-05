# Instalación de Flux en Kubernetes usando una GitHub Organization

Este documento describe cómo instalar y configurar Flux CD en un clúster de Kubernetes utilizando un repositorio dentro de una organización de GitHub como fuente de configuración (GitOps).

---

## Requisitos previos

Antes de comenzar, asegúrate de tener:

* Un clúster de Kubernetes en funcionamiento
* `kubectl` configurado y con acceso de administrador al clúster
* `git` instalado
* `flux` CLI instalado
* Acceso a una organización de GitHub
* Permisos para crear repositorios en la organización

### Instalación de Flux CLI

```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

Verifica la instalación:

```bash
flux --version
```

---

## Crear repositorio en GitHub Organization (opcional)

1. Accede a tu organización en GitHub
2. Crea un nuevo repositorio (por ejemplo: `flux-config`)
3. No es necesario inicializar con README

---

## Autenticación con GitHub

Flux requiere acceso al repositorio. Puedes usar un token personal (PAT).

### Crear Personal Access Token (PAT)

* Ve a GitHub → Settings → Developer Settings → Personal Access Tokens
* Genera un token con permisos:

  * `repo`
  * `admin:repo_hook`

El bootstrap puede ejecutarse con un PAT de tipo fine-grained, en el caso de repositorios que ya han sido creados previamente.

El PAT fine-grained debe generarse con los siguientes permisos:

* `Administration` → Acceso: solo lectura
* `Contents` → Acceso: lectura y escritura
* `Metadata` → Acceso: solo lectura

Si quieres hacer bootstrap de Flux para un repositorio que pertenece a una organización de GitHub, se recomienda crear un usuario dedicado para Flux dentro de tu organización.

Guarda el token en una variable de entorno:

```bash
export GITHUB_TOKEN=<flux_token>
export GITHUB_USER=<flux_usuario>
```

---

## Bootstrap de Flux

Ejecuta el siguiente comando para instalar Flux en el clúster y conectarlo al repositorio:

```bash
flux bootstrap github \
  --token-auth \
  --owner=my-github-organization \
  --repository=my-repository \
  --branch=main \
  --path=mira-instalando-oscar
```

Al crear un repositorio nuevo, puedes especificar una lista de equipos de GitHub con `--team=team1-slug,team2-slug`; esos equipos recibirán permisos de maintainer sobre el repositorio.

### Parámetros clave

* `--owner`: nombre de la organización
* `--repository`: nombre del repositorio
* `--branch`: rama principal
* `--path`: ruta donde se almacenará la configuración
* `--token-auth`: usar autenticación mediante token

---

## Instalando OSCAR

Para instalar OSCAR con todos sus componentes necesarios, duplica la carpeta oscar de este repositorio, el path del bootstrap debe establecerse en `\oscar\environment\devel`

Si solo se quiere instalar OSCAR sin sus dependencias, solo será necesario copiar la carpeta `apps` y de la carpeta `environmnet` el archivo `apps.yaml`, asi como remover la entrada `dependsOn` dentro de las spec

## Verificación

Comprueba que los pods de Flux estén en ejecución:

```bash
kubectl get pods -n flux-system
```

Verifica el estado:

```bash
flux get all
```

---

## Estructura del repositorio

Después del bootstrap, el repositorio tendrá una estructura similar a:

```
clusters/
  my-cluster/
    flux-system/
```

Aquí puedes añadir manifiestos Kubernetes para que Flux los sincronice automáticamente.

---

## Despliegue de aplicaciones

1. Añade manifiestos YAML al repositorio
2. Haz commit y push
3. Flux aplicará los cambios automáticamente al clúster

Ejemplo:

```bash
git add .
git commit -m "Add app"
git push
```

---

## Buenas prácticas

* Usa ramas para cambios grandes
* Aplica revisiones mediante pull requests
* Organiza los manifiestos por entorno (dev, staging, prod)
* Usa Kustomize o Helm para gestión avanzada

---

## Solución de problemas

Ver logs:

```bash
kubectl logs -n flux-system deployment/source-controller
```

Reconcilia manualmente:

```bash
flux reconcile source git flux-system
```

---

## Referencias

* [https://fluxcd.io/flux/installation/bootstrap/github/](https://fluxcd.io/flux/installation/bootstrap/github/)
* [https://github.com/fluxcd/flux2](https://github.com/fluxcd/flux2)

---

## Licencia

Este proyecto se distribuye bajo licencia MIT.
