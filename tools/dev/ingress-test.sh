#!/usr/bin/env bash
# ==============================================================================
# Checks that the terminal is reachable for Home Assistant's Ingress proxy and
# for nothing else on the Supervisor's bridge.
#
# Rebuilds the bridge's address range (172.30.32.0/23), runs the add-on in its
# production mode next to the Supervisor stub, and connects once as the Ingress
# proxy (172.30.32.2) and once as another add-on.
#
# Usage: tools/dev/ingress-test.sh [image]
# ==============================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

IMAGE="${1:-claude-addon:test}"
CURL=curlimages/curl:8.17.0
NET=claude-ingress-test-$$
PORT=8099
WORK=$(mktemp -d)

cleanup() {
    docker rm -f "${NET}-addon" "${NET}-stub" > /dev/null 2>&1 || true
    docker network rm "${NET}" > /dev/null 2>&1 || true
    # The add-on writes /data as root; remove it through a container.
    docker run --rm --entrypoint sh -v "${WORK}:/w" "${IMAGE}" -c 'rm -rf /w/*' > /dev/null 2>&1 || true
    rm -rf "${WORK}"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    docker logs "${NET}-addon" >&2 2>&1 || true
    exit 1
}

if [[ "${1:-}" == "" ]]; then
    docker build -q -t "${IMAGE}" claude-code > /dev/null
fi

mkdir -p "${WORK}/data" "${WORK}/config"
cat > "${WORK}/data/options.json" <<'EOF'
{"log_level": "info", "cleanup_period_days": 14, "claude_version": "latest",
 "remote_control": "disabled", "remote_control_name": "test",
 "import_existing_state": false, "packages": [], "init_commands": []}
EOF

docker network create --subnet 172.30.32.0/23 "${NET}" > /dev/null
docker run -d --name "${NET}-stub" --network "${NET}" --ip 172.30.32.20 \
    --network-alias supervisor --entrypoint python3 -e "INGRESS_PORT=${PORT}" \
    -v "${PWD}/tools/dev:/tools:ro" -v "${WORK}/data:/data" \
    "${IMAGE}" /tools/supervisor-stub.py > /dev/null
# Production mode: no TTYD_BIND_ALL, the port comes from the Supervisor stub.
docker run -d --name "${NET}-addon" --network "${NET}" --ip 172.30.32.30 \
    -e SUPERVISOR_TOKEN=stub-token \
    -v "${WORK}/data:/data" -v "${WORK}/config:/config" "${IMAGE}" > /dev/null

# The first start downloads Claude Code; wait for the proxy to come up.
for _ in $(seq 1 120); do
    docker logs "${NET}-addon" 2>&1 | grep -q 'Ingress on port' && break
    sleep 3
done
sleep 3

# from <ip> <curl args...>: one request from a container with that address.
from() {
    local ip="$1"
    shift
    docker run --rm --network "${NET}" --ip "${ip}" "${CURL}" \
        -s -o /dev/null -w '%{http_code}' --max-time 5 "$@" || true
}
URL="http://172.30.32.30:${PORT}"

code=$(from 172.30.32.2 "${URL}/")
[[ ${code} == 200 ]] || fail "Ingress proxy got ${code} for the page, expected 200"
echo "ok: Ingress proxy (172.30.32.2) gets the terminal page"

code=$(from 172.30.32.2 --http1.1 -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
    -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
    -H 'Sec-WebSocket-Protocol: tty' "${URL}/ws")
[[ ${code} == 101 ]] || fail "Ingress proxy got ${code} for the WebSocket, expected 101"
echo "ok: Ingress proxy opens the terminal WebSocket"

for path in / /token /ws; do
    code=$(from 172.30.32.40 "${URL}${path}")
    [[ ${code} == 403 ]] || fail "another add-on got ${code} for ${path}, expected 403"
done
echo "ok: another add-on (172.30.32.40) is refused"

# ttyd itself listens on no port at all, only on its socket. (127.0.0.11 is
# Docker's own DNS resolver inside the test network.) Read into a variable
# first: under pipefail an early-exiting grep fails the pipeline at random.
listeners=$(docker exec "${NET}-addon" netstat -ltn)
if grep LISTEN <<<"${listeners}" | grep -v -e ":${PORT} " -e "127.0.0.11:" | grep -q .; then
    fail "something besides nginx listens on a TCP port: ${listeners}"
fi
echo "ok: only nginx listens on a TCP port"
echo "OK"
