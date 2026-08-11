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
remote_control_mode() {
    local mode
    mode=$(bashio::config 'remote_control' 'server')

    if [[ ! "${mode}" =~ ^(disabled|session|server)$ ]]; then
        bashio::log.warning \
            "Could not read a valid remote_control value (got '${mode}')," \
            "assuming 'server'."
        mode="server"
    fi

    printf '%s' "${mode}"
}
