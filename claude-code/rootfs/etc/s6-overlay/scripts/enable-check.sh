#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Claude Code
# Enables optional services based on the add-on configuration
# ==============================================================================

# The Remote Control server is a service of its own. It only makes sense in
# "server" mode; "session" mode connects the tmux session itself and "disabled"
# turns the feature off entirely.
if [[ "$(bashio::config 'remote_control')" != "server" ]]; then
    bashio::log.info \
        "Remote Control server mode is not enabled; not starting the service."
    rm -f /etc/s6-overlay/user-bundles.d/user/contents.d/remote-control
fi
