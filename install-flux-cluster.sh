findAvailablePort(){
    local default_port=$1
    shift
    local candidates=("$default_port" "$@")
    for candidate in "${candidates[@]}"; do
        if ! portInUse "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done
    echo ""
    return 1
}

findAvailablePortExclude(){
    local default_port=$1
    local excluded_port=$2
    shift 2
    local candidates=("$default_port" "$@")
    for candidate in "${candidates[@]}"; do
        if [ "$candidate" == "$excluded_port" ]; then
            continue
        fi
        if ! portInUse "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done
    echo ""
    return 1
}

HTTP_PORT_FALLBACKS=(8080 8081 8082 8880 9080 10080)
HTTPS_PORT_FALLBACKS=(444 8443 9443 10443)
MINIO_API_PORT_FALLBACKS=(30302 30304 30306 31300 32000 32500)
MINIO_CONSOLE_PORT_FALLBACKS=(30303 30305 30307 31301 32001 32501)
DEFAULT_HTTP_PORT=80
DEFAULT_HTTPS_PORT=443
DEFAULT_MINIO_API_PORT=30300
DEFAULT_MINIO_CONSOLE_PORT=30301
DEFAULT_REGISTRY_PORT=5001
OSCAR_IMAGE_BRANCH="master"
OSCAR_HELM_IMAGE_OVERRIDES=""
OSCAR_POST_DEPLOYMENT_IMAGE=""
OSCAR_TARGET_REPLICAS=1
SKIP_PROMPTS="false"

HOST_HTTP_PORT=$(findAvailablePort "$DEFAULT_HTTP_PORT" "${HTTP_PORT_FALLBACKS[@]}")
HOST_HTTPS_PORT=$(findAvailablePort "$DEFAULT_HTTPS_PORT" "${HTTPS_PORT_FALLBACKS[@]}")
HOST_MINIO_API_PORT=$(findAvailablePort "$DEFAULT_MINIO_API_PORT" "${MINIO_API_PORT_FALLBACKS[@]}")
HOST_MINIO_CONSOLE_PORT=$(findAvailablePortExclude "$DEFAULT_MINIO_CONSOLE_PORT" "$HOST_MINIO_API_PORT" "${MINIO_CONSOLE_PORT_FALLBACKS[@]}")


kind create cluster --config ./kind-flux-config.yaml