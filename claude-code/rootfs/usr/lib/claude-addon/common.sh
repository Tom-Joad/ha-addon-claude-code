# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Claude Code
# Helpers shared between the stage-2 hook and the init service
# ==============================================================================

# The Remote Control mode is read from two separate processes: the stage-2 hook,
# which decides whether the service exists at all, and the init service, which
# writes the settings that go with it. If those two ever reach different
# conclusions the add-on lands in a state that no option describes -- the
# service missing while the logs and settings say it is running. Reading it
# through one function keeps them in step, and pins down what happens when the
# value cannot be read at all: fall back to the documented default instead of to
# an empty string, which matches neither branch.
#
# That default is 'disabled', which is also the safer direction to fail in: a
# configuration the add-on could not read must not end up opening a connection
# the user never asked for.
remote_control_mode() {
    local mode
    mode=$(bashio::config 'remote_control' 'disabled')

    if [[ ! "${mode}" =~ ^(disabled|session|server)$ ]]; then
        bashio::log.warning \
            "Could not read a valid remote_control value (got '${mode}')," \
            "assuming 'disabled'."
        mode="disabled"
    fi

    printf '%s' "${mode}"
}

# Both the version the add-on wants and the one it finds installed are compared
# as plain strings, so both have to be cut the same way: exactly X.Y.Z. A suffix
# such as -beta.1 or a stray "\r" on one side only means the two never match,
# and every start reinstalls roughly 300 MB.
readonly VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$'

# Prints the version a release channel answered with, or fails when the answer
# is anything other than a plain X.Y.Z (plus a line ending).
parse_channel_version() {
    local answer="${1}"

    answer="${answer%$'\n'}"
    answer="${answer%$'\r'}"
    [[ "${answer}" =~ ${VERSION_PATTERN} ]] || return 1

    printf '%s' "${answer}"
}

# Prints the settings file's content as one compact JSON object. A file without
# content (a full disk or a power cut can leave one) counts as {}; anything that
# is not a JSON object fails. Without the check "jq ." accepts an empty file and
# prints nothing, and every later step then writes an empty file back.
read_settings_json() {
    local file="${1}" content

    content=$(<"${file}") || return 1
    if [[ -z "${content//[[:space:]]/}" ]]; then
        printf '{}'
        return 0
    fi

    printf '%s' "${content}" | jq -ec 'select(type == "object")'
}

# ------------------------------------------------------- Claude Code download
#
# Anthropic publishes every release as
#   <releases>/<version>/manifest.json            (platforms.<platform>.checksum)
#   <releases>/<version>/<platform>/claude        (the binary)
# and its own installer (claude.ai/install.sh) checks the binary against that
# SHA-256 before it uses it. The add-on does the same, so a binary that does
# not match the manifest is never switched to.
#
# This only moves the trust to the manifest's host: the checksum is fetched
# from the same place as the binary, over TLS. It catches a corrupt or
# truncated download and a binary that was replaced without its manifest; it
# is not a signature.

# Prints the manifest platform name for a machine (uname -m) and a libc
# ("musl" or "glibc"), as the official installer names them.
claude_platform() {
    local machine="${1}" libc="${2}" arch

    case "${machine}" in
        x86_64 | amd64) arch="x64" ;;
        aarch64 | arm64) arch="arm64" ;;
        *) return 1 ;;
    esac

    if [[ "${libc}" == "musl" ]]; then
        printf 'linux-%s-musl' "${arch}"
    else
        printf 'linux-%s' "${arch}"
    fi
}

# Same musl test as the official installer.
detect_libc() {
    if [[ -f /lib/libc.musl-x86_64.so.1 || -f /lib/libc.musl-aarch64.so.1 ]] \
        || ldd /bin/ls 2>&1 | grep -q musl; then
        printf 'musl'
    else
        printf 'glibc'
    fi
}

# Prints the SHA-256 the manifest lists for a platform; fails unless it is 64
# lower-case hex digits (a missing platform, an error page, a changed format).
manifest_checksum() {
    local manifest="${1}" platform="${2}" checksum

    checksum=$(printf '%s' "${manifest}" \
        | jq -er --arg platform "${platform}" '.platforms[$platform].checksum // empty' \
            2>/dev/null) || return 1
    [[ "${checksum}" =~ ^[a-f0-9]{64}$ ]] || return 1

    printf '%s' "${checksum}"
}

# Downloads one release's binary to <destination> and checks it against the
# manifest. On failure nothing is left at <destination>.
#
#   download_verified_binary <releases-url> <version> <platform> <destination>
#
# Returns 0 when the binary matches the manifest, 1 when a download failed,
# 2 when the manifest has no valid checksum for the platform, 3 when the
# checksum differs (CLAUDE_EXPECTED_SHA256 and CLAUDE_ACTUAL_SHA256 are set
# for the caller to log).
download_verified_binary() {
    local base="${1}" version="${2}" platform="${3}" destination="${4}"
    local manifest

    CLAUDE_EXPECTED_SHA256=""
    CLAUDE_ACTUAL_SHA256=""

    manifest=$(curl -fsSL --retry 3 --retry-delay 5 --max-time 60 \
        "${base}/${version}/manifest.json" 2>/dev/null) || return 1
    CLAUDE_EXPECTED_SHA256=$(manifest_checksum "${manifest}" "${platform}") || return 2

    if ! curl -fsSL --retry 3 --retry-delay 5 --max-time 1800 \
        -o "${destination}" "${base}/${version}/${platform}/claude" 2>/dev/null; then
        rm -f "${destination}"
        return 1
    fi

    CLAUDE_ACTUAL_SHA256=$(sha256sum "${destination}" | cut -d' ' -f1)
    if [[ "${CLAUDE_ACTUAL_SHA256}" != "${CLAUDE_EXPECTED_SHA256}" ]]; then
        rm -f "${destination}"
        return 3
    fi

    return 0
}

# Makes a verified binary the one the launcher runs: moved into the versions
# directory (the same filesystem, so the move is atomic), then the launcher
# symlink is replaced in one step. The previous build stays untouched until
# the caller prunes it.
#
#   activate_claude_binary <binary> <version> <versions-dir> <launcher>
activate_claude_binary() {
    local binary="${1}" version="${2}" versions_dir="${3}" launcher="${4}"

    mkdir -p "${versions_dir}" "$(dirname "${launcher}")" || return 1
    chmod 755 "${binary}" || return 1
    mv -f "${binary}" "${versions_dir}/${version}" || return 1
    ln -sfn "${versions_dir}/${version}" "${launcher}.new" || return 1
    mv -fT "${launcher}.new" "${launcher}"
}
