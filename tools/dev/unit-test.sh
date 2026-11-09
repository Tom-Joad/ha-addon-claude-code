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

(( failures == 0 )) || exit 1
echo "OK"
