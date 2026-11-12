#!/usr/bin/env bash
# ==============================================================================
# Checks that the terminal comes up, whatever the user's options contain:
#   - init commands that use an unset variable, call exit, fail, or overwrite
#     the loop variable must not stop later commands or ttyd;
#   - init commands are logged by position, never verbatim;
#   - package entries that look like apk options or contain spaces are refused;
#   - an empty settings.json gets the add-on's settings instead of staying empty;
#   - Claude Code's own auto-updater is off;
#   - the image carries its own labels, not empty ones or the base image's;
#   - after a restore (backups leave the build out) the build is downloaded
#     again;
#   - remote_control: server starts Remote Control with a session name, also
#     when remote_control_name is empty;
#   - a downloaded build is checked against the release manifest's SHA-256
#     before the launcher moves to it (fake releases served locally: a match
#     is installed, a mismatch keeps the previous build or stops the start).
#
# Runs the image on a plain Docker host next to the Supervisor stub (test mode:
# TTYD_BIND_ALL=1). The first start downloads the real Claude Code and checks
# it against Anthropic's real manifest.
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
    docker ps -aq --filter "name=^${NET}-" | xargs -r docker rm -f > /dev/null 2>&1 || true
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

docker inspect -f '{{json .Config.Labels}}' "${IMAGE}" | jq -e '
    ."io.hass.name" == "Claude Code" and ."io.hass.description" != ""
    and ."org.opencontainers.image.title" == "Claude Code"
    and ."org.opencontainers.image.authors" == "Tom-Joad"
    and ."org.opencontainers.image.vendor" == "Tom-Joad"
    and (."org.opencontainers.image.url" | endswith("Tom-Joad/ha-addon-claude-code"))' > /dev/null \
    || fail "the image labels are empty or the base image's"
echo "ok: the image carries its own labels"

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
if in_log 'for 172\.30\.32\.2 only'; then
    fail 'test mode claims that only 172.30.32.2 may connect'
fi
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

# ---------------------------------------------------- checksum verification
#
# The real download above passed the check against the real manifest. These
# runs use fake releases on a local server (CLAUDE_RELEASES_URL): 1.0.0 and
# 3.0.0 match their manifest, 2.0.0's manifest lists another checksum.
docker rm -f "${NET}-addon" "${NET}-stub" > /dev/null
REL="${WORK}/releases"
for v in 1.0.0 2.0.0 3.0.0; do
    for platform in linux-x64-musl linux-arm64-musl; do
        mkdir -p "${REL}/${v}/${platform}"
        # Prints how it was called to stderr (the log), for the Remote Control case.
        printf '#!/bin/sh\necho "claude $*" >&2\necho "%s (Claude Code)"\n' "${v}" \
            > "${REL}/${v}/${platform}/claude"
    done
    sum=$(sha256sum "${REL}/${v}/linux-x64-musl/claude" | cut -d' ' -f1)
    [[ ${v} != 2.0.0 ]] || sum=$(printf 'b%.0s' $(seq 1 64))
    printf '{"platforms":{"linux-x64-musl":{"checksum":"%s"},"linux-arm64-musl":{"checksum":"%s"}}}' \
        "${sum}" "${sum}" > "${REL}/${v}/manifest.json"
done
docker run -d --name "${NET}-releases" --network "${NET}" --network-alias releases \
    --entrypoint python3 -v "${REL}:/srv:ro" "${IMAGE}" -m http.server 8000 -d /srv > /dev/null

# start_fake <name> <claude_version> [seeded-version]: an add-on container on
# fake releases, optionally with that version already installed.
start_fake() {
    local name="${1}" want="${2}" seeded="${3:-}" data="${WORK}/${1}"
    mkdir -p "${data}/claude" "${data}/home/.local/bin" "${data}/home/.local/share/claude/versions"
    printf '{"log_level": "info", "claude_version": "%s", "remote_control": "disabled"}' \
        "${want}" > "${data}/options.json"
    if [[ -n "${seeded}" ]]; then
        cp "${REL}/${seeded}/linux-x64-musl/claude" "${data}/home/.local/share/claude/versions/${seeded}"
        chmod 755 "${data}/home/.local/share/claude/versions/${seeded}"
        ln -s "/data/home/.local/share/claude/versions/${seeded}" "${data}/home/.local/bin/claude"
    fi
    # FAKE_OPTIONS replaces the options above (JSON).
    [[ -z "${FAKE_OPTIONS:-}" ]] || printf '%s' "${FAKE_OPTIONS}" > "${data}/options.json"
    docker run -d --name "${NET}-${name}s" --network "${NET}" --network-alias supervisor \
        --entrypoint python3 -e "INGRESS_PORT=${PORT}" \
        -v "${PWD}/tools/dev:/tools:ro" -v "${data}:/data" \
        "${IMAGE}" /tools/supervisor-stub.py > /dev/null
    docker run -d --name "${NET}-${name}" --network "${NET}" \
        -e SUPERVISOR_TOKEN=stub-token -e TTYD_BIND_ALL=1 -e "INGRESS_PORT=${PORT}" \
        -e CLAUDE_RELEASES_URL=http://releases:8000 \
        -v "${data}:/data" -v "${WORK}/config:/config" "${IMAGE}" > /dev/null
}

# Waits until the container logs $2 (success) or stops.
wait_for() {
    local c="${NET}-${1}" _
    for _ in $(seq 1 60); do
        grep -qE -- "${2}" <<<"$(docker logs "${c}" 2>&1)" && return 0
        [[ $(docker inspect -f '{{.State.Running}}' "${c}") == true ]] || return 1
        sleep 2
    done
    return 1
}
# One stub at a time: all of them answer to the name "supervisor".
stop_fake() { docker rm -f "${NET}-${1}" "${NET}-${1}s" > /dev/null; }
log_of() { docker logs "${NET}-${1}" 2>&1; }

# A fake build that matches is installed and the launcher moves to it.
start_fake fa 3.0.0 1.0.0
wait_for fa 'Starting the ttyd daemon' || { log_of fa >&2; fail 'matching build: ttyd never started'; }
[[ $(docker exec "${NET}-fa" readlink /data/home/.local/bin/claude) == */versions/3.0.0 ]] \
    || fail 'matching build: the launcher did not move to 3.0.0'
[[ $(docker exec "${NET}-fa" claude --version) == '3.0.0 (Claude Code)' ]] \
    || fail 'matching build: claude does not report 3.0.0'
docker exec "${NET}-fa" test ! -e /data/home/.local/share/claude/versions/1.0.0 \
    || fail 'matching build: the superseded build was not removed'
grep -q 'matches the release manifest' <<<"$(log_of fa)" || fail 'matching build: no confirmation logged'
stop_fake fa
echo "ok: a build that matches the manifest is installed"

# A mismatch keeps the previous build and says why.
start_fake fb 2.0.0 1.0.0
wait_for fb 'Starting the ttyd daemon' || { log_of fb >&2; fail 'mismatch with a previous build: ttyd never started'; }
out=$(log_of fb)
grep -qE 'Checksum mismatch for Claude Code 2.0.0 .*expected b{64}, got [a-f0-9]{64}' <<<"${out}" \
    || fail 'mismatch: no ERROR with expected and actual checksum'
grep -q 'keeping the installed 1.0.0' <<<"${out}" || fail 'mismatch: previous build not kept'
[[ $(docker exec "${NET}-fb" readlink /data/home/.local/bin/claude) == */versions/1.0.0 ]] \
    || fail 'mismatch: the launcher moved'
docker exec "${NET}-fb" sh -c 'ls /data/home/.local/share/claude/versions' | grep -qx 1.0.0 \
    || fail 'mismatch: previous build is gone'
[[ $(docker exec "${NET}-fb" sh -c 'ls -A /data/home/.local/share/claude/versions | wc -l') == 1 ]] \
    || fail 'mismatch: the rejected download was left behind'
stop_fake fb
echo "ok: a mismatch keeps the previous build"

# A restored backup has the launcher but not the build it points at.
mkdir -p "${WORK}/fr/home/.local/bin"
ln -s /data/home/.local/share/claude/versions/3.0.0 "${WORK}/fr/home/.local/bin/claude"
start_fake fr 3.0.0
wait_for fr 'Starting the ttyd daemon' || { log_of fr >&2; fail 'restore: ttyd never started'; }
[[ $(docker exec "${NET}-fr" claude --version) == '3.0.0 (Claude Code)' ]] \
    || fail 'restore: the build was not downloaded again'
stop_fake fr
echo "ok: a restore without the build downloads it again"

# Server mode with a blank name: the service starts Remote Control under the
# default name (the fake claude logs its arguments), and settings.json keeps
# neither session-mode key.
mkdir -p "${WORK}/fs/claude"
printf '{}' > "${WORK}/fs/claude/.credentials.json"
FAKE_OPTIONS='{"log_level": "info", "claude_version": "3.0.0", "remote_control": "server",
               "remote_control_name": " "}' start_fake fs 3.0.0 3.0.0
wait_for fs 'claude remote-control --spawn same-dir --name Home Assistant$' \
    || { log_of fs >&2; fail 'server: Remote Control did not start under the default name'; }
docker exec "${NET}-fs" jq -e 'has("remoteControlAtStartup") or has("disableRemoteControl") | not' \
    /data/claude/settings.json > /dev/null || fail 'server: settings.json keeps a session-mode key'
stop_fake fs
echo "ok: remote_control server starts Remote Control under the default name"

# A mismatch with nothing installed stops the start instead of running it.
start_fake fc 2.0.0
wait_for fc 'Starting the ttyd daemon' && fail 'mismatch without a previous build: ttyd started'
out=$(log_of fc)
grep -qE 'Checksum mismatch for Claude Code 2.0.0 .*expected b{64}, got [a-f0-9]{64}' <<<"${out}" \
    || fail 'mismatch without a previous build: no ERROR with both checksums'
grep -q 'no previous installation exists' <<<"${out}" || fail 'mismatch without a previous build: start not refused clearly'
# The container has stopped; its /data is the host directory.
[[ ! -e "${WORK}/fc/home/.local/bin/claude" && ! -L "${WORK}/fc/home/.local/bin/claude" ]] \
    || fail 'mismatch without a previous build: a launcher exists'
echo "ok: a mismatch without a previous build stops the start"

echo "OK"
