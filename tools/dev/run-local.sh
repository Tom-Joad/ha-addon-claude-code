#!/usr/bin/env bash
# ==============================================================================
# Builds the add-on image and runs it on a plain Docker host.
#
# bashio reads the add-on options and metadata from the Supervisor API, not from
# /data/options.json, so without something answering on http://supervisor the s6
# init chain stops before any of this add-on's services start. supervisor-stub.py
# answers just enough of it.
#
# Usage:
#   tools/dev/run-local.sh                     # defaults
#   REMOTE_CONTROL=server tools/dev/run-local.sh
#   PORT=8080 tools/dev/run-local.sh
# ==============================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
ROOT="$(pwd -W 2>/dev/null || pwd)"

# Git Bash rewrites arguments that look like absolute Unix paths into Windows
# paths, which turns container-side paths such as /testenv into nonsense.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

IMAGE="${IMAGE:-claude-addon:test}"
BASE="${BASE:-ghcr.io/hassio-addons/base:21.0.1}"
NET=claude-test-net
PORT="${PORT:-7681}"
REMOTE_CONTROL="${REMOTE_CONTROL:-disabled}"
CLAUDE_VERSION="${CLAUDE_VERSION:-latest}"

mkdir -p .testenv/data .testenv/config

cat > .testenv/data/options.json <<EOF
{
  "log_level": "info",
  "cleanup_period_days": 14,
  "claude_version": "${CLAUDE_VERSION}",
  "remote_control": "${REMOTE_CONTROL}",
  "remote_control_name": "Home Assistant (local)",
  "import_existing_state": false,
  "packages": [],
  "init_commands": []
}
EOF

if [[ ! -f .testenv/config/CLAUDE.md ]]; then
    cat > .testenv/config/CLAUDE.md <<'EOF'
# Local test project

Stands in for the Home Assistant configuration directory.
EOF
fi

echo "==> Building ${IMAGE}"
docker build -q --build-arg "BUILD_FROM=${BASE}" -t "${IMAGE}" claude-code > /dev/null

docker rm -f claude-test supervisor-stub > /dev/null 2>&1 || true
docker network create "${NET}" > /dev/null 2>&1 || true

echo "==> Starting the Supervisor stub"
docker run -d --name supervisor-stub \
    --network "${NET}" --network-alias supervisor \
    --entrypoint python3 \
    -e "INGRESS_PORT=${PORT}" \
    -v "${ROOT}/tools/dev:/tools:ro" \
    -v "${ROOT}/.testenv/data:/data" \
    "${IMAGE}" /tools/supervisor-stub.py > /dev/null

# The add-on container is recreated rather than restarted on purpose: bashio
# caches the options under /tmp, which a plain "docker restart" would keep. The
# Supervisor recreates the container on start, so this matches production.
echo "==> Starting the add-on (remote_control=${REMOTE_CONTROL})"
docker run -d --name claude-test \
    --network "${NET}" \
    -e SUPERVISOR_TOKEN=stub-token \
    -e TTYD_BIND_ALL=1 \
    -e "INGRESS_PORT=${PORT}" \
    -p "${PORT}:${PORT}" \
    -v "${ROOT}/.testenv/data:/data" \
    -v "${ROOT}/.testenv/config:/config" \
    "${IMAGE}" > /dev/null

echo "==> Terminal at http://localhost:${PORT}"
echo "    docker logs -f claude-test"
