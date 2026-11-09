#!/usr/bin/env bash
# ==============================================================================
# Checks that the terminal comes up, whatever the user's options contain:
#   - init commands that use an unset variable, call exit, fail, or overwrite
#     the loop variable must not stop later commands or ttyd;
#   - init commands are logged by position, never verbatim;
#   - package entries that look like apk options or contain spaces are refused;
#   - an empty settings.json gets the add-on's settings instead of staying empty;
#   - Claude Code's own auto-updater is off.
#
# Runs the image on a plain Docker host next to the Supervisor stub (test mode:
# TTYD_BIND_ALL=1). The first start downloads Claude Code.
#
# Usage: tools/dev/startup-test.sh [image]
# ==============================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

IMAGE="${1:-claude-addon:test}"
NET=claude-startup-test-$$
PORT=8098
WORK=$(mktemp -d)

cleanup() {
    docker rm -f "${NET}-addon" "${NET}-stub" > /dev/null 2>&1 || true
    docker network rm "${NET}" > /dev/null 2>&1 || true
    # The add-on writes /data as root; remove it through a container.
    docker run --rm --entrypoint sh -v "${WORK}:/w" "${IMAGE}" -c 'rm -rf /w/*' > /dev/null 2>&1 || true
    rm -rf "${WORK}"
}
trap cleanup EXIT

in_log() {
    local out
    out=$(docker logs "${NET}-addon" 2>&1)
    grep -qE -- "$1" <<<"${out}"
}

fail() {
    echo "FAIL: $*" >&2
    docker logs "${NET}-addon" >&2 2>&1 || true
    exit 1
}

if [[ "${1:-}" == "" ]]; then
    docker build -q -t "${IMAGE}" claude-code > /dev/null
fi

mkdir -p "${WORK}/data/claude" "${WORK}/config"
# A settings file a power cut left empty.
: > "${WORK}/data/claude/settings.json"

# The first command prints an unset variable (fatal under bashio's nounset), the
# second one exits (the only one that fails),
# the third overwrites the variable the loop used to count with, the fourth
# carries a "credential" and must not appear in the log, the fifth proves the
# loop got this far.
cat > "${WORK}/data/options.json" <<'JSON'
{"log_level": "info", "cleanup_period_days": 14, "claude_version": "latest",
 "remote_control": "session", "remote_control_name": "test",
 "packages": ["--allow-untrusted", "with space", "jq"],
 "init_commands": [
   "echo $SURELY_NOT_SET_VARIABLE",
   "exit 3",
   "for i in a b; do :; done; for idx in a b; do :; done",
   "true ghp_SECRET_TOKEN_VALUE",
   "touch /tmp/init-reached-the-end"
 ]}
JSON

docker network create "${NET}" > /dev/null
docker run -d --name "${NET}-stub" --network "${NET}" \
    --network-alias supervisor --entrypoint python3 -e "INGRESS_PORT=${PORT}" \
    -v "${PWD}/tools/dev:/tools:ro" -v "${WORK}/data:/data" \
    "${IMAGE}" /tools/supervisor-stub.py > /dev/null
docker run -d --name "${NET}-addon" --network "${NET}" \
    -e SUPERVISOR_TOKEN=stub-token -e TTYD_BIND_ALL=1 -e "INGRESS_PORT=${PORT}" \
    -v "${WORK}/data:/data" -v "${WORK}/config:/config" "${IMAGE}" > /dev/null

# The first start downloads Claude Code; wait for ttyd.
for _ in $(seq 1 120); do
    in_log 'Starting the ttyd daemon' && break
    # A container that stopped will not get there.
    [[ $(docker inspect -f '{{.State.Running}}' "${NET}-addon") == true ]] || break
    sleep 3
done
in_log 'Starting the ttyd daemon' || fail 'ttyd never started'
echo "ok: ttyd starts although the init commands fail"

sleep 3
code=$(docker exec "${NET}-addon" curl -s -o /dev/null -w '%{http_code}' \
    --max-time 5 "http://127.0.0.1:${PORT}/")
[[ ${code} == 200 ]] || fail "the terminal page answered ${code}, expected 200"
echo "ok: the terminal page is served"

docker exec "${NET}-addon" test -f /tmp/init-reached-the-end \
    || fail 'the last init command did not run'
echo "ok: every init command ran"

in_log 'Init command 2 of 5 failed \(exit code 3\)' || fail 'exit code of command 2 not reported'
if in_log 'Init command [1345] of 5 failed'; then
    fail 'a working command was reported as failed'
fi
echo "ok: failures are reported with their position"

if in_log 'ghp_SECRET_TOKEN_VALUE|SURELY_NOT_SET_VARIABLE'; then
    fail 'an init command appears verbatim in the log'
fi
echo "ok: init commands are not logged verbatim"

in_log "Skipping package entry '--allow-untrusted'" || fail 'option-like package not refused'
in_log "Skipping package entry 'with space'" || fail 'package with a space not refused'
in_log 'Installing package jq' || fail 'the valid package was not installed'
echo "ok: package entries are checked"

# Read by jq inside the container: jq is part of the image.
docker exec "${NET}-addon" jq -e '.cleanupPeriodDays == 14 and .remoteControlAtStartup == true' \
    /data/claude/settings.json > /dev/null \
    || fail 'an empty settings.json did not get the add-on settings'
echo "ok: an empty settings.json is filled in"

# /proc/<pid>/environ of ttyd, and a login shell as the tmux session runs it.
env_of_ttyd=$(docker exec "${NET}-addon" sh -c 'tr "\0" "\n" < /proc/$(pgrep -o ttyd)/environ')
grep -qx 'DISABLE_AUTOUPDATER=1' <<<"${env_of_ttyd}" || fail 'ttyd runs without DISABLE_AUTOUPDATER'
shell_value=$(docker exec -e DISABLE_AUTOUPDATER= "${NET}-addon" bash -lc 'echo "${DISABLE_AUTOUPDATER}"')
[[ "${shell_value}" == 1 ]] || fail "a login shell has DISABLE_AUTOUPDATER='${shell_value}'"
echo "ok: Claude Code's auto-updater is off"

echo "OK"
