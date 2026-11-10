#!/usr/bin/env bash
# ==============================================================================
# Unit tests for the helpers in claude-code/rootfs/usr/lib/claude-addon/common.sh
# that need no Supervisor and no image: version parsing and the settings file.
#
# Usage: tools/dev/unit-test.sh
# ==============================================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# shellcheck source=../../claude-code/rootfs/usr/lib/claude-addon/common.sh
source claude-code/rootfs/usr/lib/claude-addon/common.sh

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT
failures=0

check() {
    local name="${1}" expected="${2}" actual="${3}"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "ok: ${name}"
    else
        echo "FAIL: ${name}: expected '${expected}', got '${actual}'" >&2
        failures=$((failures + 1))
    fi
}

# parse_channel_version: only a plain X.Y.Z, optionally with a line ending.
channel() { parse_channel_version "${1}" 2>/dev/null || printf 'FAILED'; }
check 'channel: plain version' '2.1.230' "$(channel '2.1.230')"
check 'channel: trailing newline' '2.1.230' "$(channel $'2.1.230\n')"
check 'channel: CRLF' '2.1.230' "$(channel $'2.1.230\r\n')"
check 'channel: CR only' '2.1.230' "$(channel $'2.1.230\r')"
check 'channel: text after the version' 'FAILED' "$(channel '2.1.230 beta')"
check 'channel: suffix' 'FAILED' "$(channel '2.1.230-beta.1')"
check 'channel: second line' 'FAILED' "$(channel $'2.1.230\n2.1.231')"
check 'channel: html error page' 'FAILED' "$(channel '<html>404</html>')"
check 'channel: empty' 'FAILED' "$(channel '')"

# read_settings_json: empty means {}, anything but an object fails.
settings() {
    printf '%s' "${1}" > "${WORK}/settings.json"
    read_settings_json "${WORK}/settings.json" 2>/dev/null || printf 'FAILED'
}
check 'settings: empty file' '{}' "$(settings '')"
check 'settings: whitespace only' '{}' "$(settings $' \n\t\n')"
check 'settings: object' '{"a":1}' "$(settings '{ "a": 1 }')"
check 'settings: array' 'FAILED' "$(settings '[1]')"
check 'settings: string' 'FAILED' "$(settings '"x"')"
check 'settings: null' 'FAILED' "$(settings 'null')"
check 'settings: truncated' 'FAILED' "$(settings '{"a": ')"
check 'settings: missing file' 'FAILED' \
    "$(read_settings_json "${WORK}/none.json" 2>/dev/null || printf 'FAILED')"

# claude_platform: the manifest's platform names, as the official installer picks them.
check 'platform: x86_64 musl' 'linux-x64-musl' "$(claude_platform x86_64 musl)"
check 'platform: aarch64 musl' 'linux-arm64-musl' "$(claude_platform aarch64 musl)"
check 'platform: x86_64 glibc' 'linux-x64' "$(claude_platform x86_64 glibc)"
check 'platform: arm64 glibc' 'linux-arm64' "$(claude_platform arm64 glibc)"
check 'platform: unknown machine' 'FAILED' "$(claude_platform riscv64 musl 2>/dev/null || printf 'FAILED')"

# manifest_checksum: a valid SHA-256 for the platform, nothing else.
sum64=$(printf 'a%.0s' $(seq 1 64))
manifest="{\"version\":\"9.9.9\",\"platforms\":{\"linux-x64-musl\":{\"checksum\":\"${sum64}\",\"size\":3},
  \"linux-arm64-musl\":{\"checksum\":\"too-short\"}}}"
mchecksum() { manifest_checksum "${1}" "${2}" 2>/dev/null || printf 'FAILED'; }
check 'manifest: checksum of the platform' "${sum64}" "$(mchecksum "${manifest}" linux-x64-musl)"
check 'manifest: platform missing' 'FAILED' "$(mchecksum "${manifest}" linux-x64)"
check 'manifest: malformed checksum' 'FAILED' "$(mchecksum "${manifest}" linux-arm64-musl)"
check 'manifest: not JSON' 'FAILED' "$(mchecksum '<html>404</html>' linux-x64-musl)"
check 'manifest: empty' 'FAILED' "$(mchecksum '' linux-x64-musl)"

# download_verified_binary / activate_claude_binary against a fake release
# tree read through file:// URLs: 1.0.0 matches its manifest, 2.0.0 lists a
# different checksum, 3.0.0 has no manifest, 4.0.0 has no entry for the platform.
REL="${WORK}/releases"
mkdir -p "${REL}"/{1.0.0,2.0.0,4.0.0}/linux-x64-musl
for v in 1.0.0 2.0.0 4.0.0; do printf 'fake claude %s\n' "${v}" > "${REL}/${v}/linux-x64-musl/claude"; done
good=$(sha256sum "${REL}/1.0.0/linux-x64-musl/claude" | cut -d' ' -f1)
printf '{"platforms":{"linux-x64-musl":{"checksum":"%s"}}}' "${good}" > "${REL}/1.0.0/manifest.json"
printf '{"platforms":{"linux-x64-musl":{"checksum":"%s"}}}' "${sum64}" > "${REL}/2.0.0/manifest.json"
printf '{"platforms":{"linux-x64":{"checksum":"%s"}}}' "${good}" > "${REL}/4.0.0/manifest.json"

verify() {
    local code=0
    rm -f "${WORK}/dl"
    download_verified_binary "file://${REL}" "${1}" linux-x64-musl "${WORK}/dl" || code=$?
    printf '%s' "${code}"
}
check 'download: matching checksum' '0' "$(verify 1.0.0)"
download_verified_binary "file://${REL}" 1.0.0 linux-x64-musl "${WORK}/dl"
check 'download: matching binary is kept' 'fake claude 1.0.0' "$(< "${WORK}/dl")"
code=0
download_verified_binary "file://${REL}" 2.0.0 linux-x64-musl "${WORK}/dl" || code=$?
check 'download: mismatch is refused' '3' "${code}"
check 'download: mismatch reports expected' "${sum64}" "${CLAUDE_EXPECTED_SHA256}"
check 'download: mismatch reports actual' \
    "$(sha256sum "${REL}/2.0.0/linux-x64-musl/claude" | cut -d' ' -f1)" "${CLAUDE_ACTUAL_SHA256}"
check 'download: mismatching binary is deleted' 'gone' "$([[ -e "${WORK}/dl" ]] || printf gone)"
check 'download: no manifest' '1' "$(verify 3.0.0)"
check 'download: platform not in manifest' '2' "$(verify 4.0.0)"
check 'download: no leftover after failures' 'gone' "$([[ -e "${WORK}/dl" ]] || printf gone)"

# activate_claude_binary: a verified binary becomes the launcher's target and
# a previous build stays until pruned.
VERS="${WORK}/share/versions"
LAUNCH="${WORK}/bin/claude"
mkdir -p "${VERS}"
printf 'old\n' > "${VERS}/0.9.0"
mkdir -p "${WORK}/bin" && ln -s "${VERS}/0.9.0" "${LAUNCH}"
download_verified_binary "file://${REL}" 1.0.0 linux-x64-musl "${VERS}/.download-1.0.0"
activate_claude_binary "${VERS}/.download-1.0.0" 1.0.0 "${VERS}" "${LAUNCH}"
check 'activate: launcher points at the new build' "${VERS}/1.0.0" "$(readlink "${LAUNCH}")"
check 'activate: new build is executable' 'yes' "$([[ -x "${VERS}/1.0.0" ]] && printf yes)"
check 'activate: previous build is kept' 'old' "$(< "${VERS}/0.9.0")"
check 'activate: no download file left' 'gone' "$([[ -e "${VERS}/.download-1.0.0" ]] || printf gone)"

(( failures == 0 )) || exit 1
echo "OK"
