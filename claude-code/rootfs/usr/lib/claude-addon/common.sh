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
