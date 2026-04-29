portInUse(){
    local port=$1
    if command -v lsof &> /dev/null; then
        if lsof -PiTCP -sTCP:LISTEN -n -P 2>/dev/null | grep -q ":${port} " ; then
            return 0
        fi
    fi
    if command -v netstat &> /dev/null; then
        if netstat -an 2>/dev/null | grep -E "[:\.]${port}[[:space:]].*LISTEN" >/dev/null; then
            return 0
        fi
    fi
    if command -v docker &> /dev/null; then
        if docker ps --format '{{.Ports}}' 2>/dev/null | tr ',' '\n' | grep -E "(:|::)${port}->" >/dev/null; then
            return 0
        fi
    fi
    if command -v nc &> /dev/null; then
        if nc -z localhost "$port" >/dev/null 2>&1; then
            return 0
        fi
        if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
            return 0
        fi
    elif command -v python3 &> /dev/null; then
        python3 - "$port" <<'PY'
import socket, sys
port = int(sys.argv[1])
for family, host in ((socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::1")):
    try:
        with socket.socket(family, socket.SOCK_STREAM) as s:
            s.settimeout(0.2)
            if s.connect_ex((host, port)) == 0:
                sys.exit(0)
    except OSError:
        continue
sys.exit(1)
PY
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi
    if [ "$port" -ge 1024 ]; then
        if command -v python3 &> /dev/null; then
            if ! python3 - "$port" <<'PY'
import errno
import socket
import sys

port = int(sys.argv[1])

def can_bind(family, addr):
    try:
        s = socket.socket(family, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((addr, port))
        s.close()
        return True
    except OSError as exc:
        if exc.errno in (getattr(errno, "EADDRINUSE", 98), getattr(errno, "EACCES", 13)):
            return False
        if exc.errno in (
            getattr(errno, "EAFNOSUPPORT", 97),
            getattr(errno, "EOPNOTSUPP", 95),
            getattr(errno, "EPROTONOSUPPORT", 93),
            getattr(errno, "EADDRNOTAVAIL", 99),
            getattr(errno, "EINVAL", 22),
        ):
            return True
        return False

if not can_bind(socket.AF_INET, "0.0.0.0"):
    sys.exit(1)

if not can_bind(socket.AF_INET6, "::"):
    sys.exit(1)

sys.exit(0)
PY
            then
                return 0
            fi
        elif command -v python &> /dev/null; then
            if ! python - "$port" <<'PY'
import errno
import socket
import sys

port = int(sys.argv[1])

def can_bind(family, addr):
    try:
        s = socket.socket(family, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((addr, port))
        s.close()
        return True
    except socket.error as exc:
        if exc.errno in (getattr(errno, "EADDRINUSE", 98), getattr(errno, "EACCES", 13)):
            return False
        if exc.errno in (
            getattr(errno, "EAFNOSUPPORT", 97),
            getattr(errno, "EOPNOTSUPP", 95),
            getattr(errno, "EPROTONOSUPPORT", 93),
            getattr(errno, "EADDRNOTAVAIL", 99),
            getattr(errno, "EINVAL", 22),
        ):
            return True
        return False

if not can_bind(socket.AF_INET, "0.0.0.0"):
    sys.exit(1)

if not can_bind(socket.AF_INET6, "::"):
    sys.exit(1)

sys.exit(0)
PY
            then
                return 0
            fi
        fi
    fi
    return 1
}

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
source ./export_token.sh
flux bootstrap github --owner=desustanciao --repository=fleet-infra --branch=main --path=./oscar/environment/devel --personal --components-extra source-watcher,image-reflector-controller,image-automation-controller