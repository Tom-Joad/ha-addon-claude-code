#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Claude Code
# Enables optional services based on the add-on configuration
# ==============================================================================
# shellcheck source=../../usr/lib/claude-addon/common.sh
source /usr/lib/claude-addon/common.sh

declare mode
mode=$(remote_control_mode)

# The Remote Control server is a service of its own. It only makes sense in
# "server" mode; "session" mode connects the tmux session itself and "disabled"
# turns the feature off entirely.
#
# Removing the entry edits the image, not the persistent volume, which is safe
# because the Supervisor removes and recreates the container on every start.
if [[ "${mode}" != "server" ]]; then
    bashio::log.info \
        "Remote Control mode is '${mode}'; not starting the server service."
    rm -f /etc/s6-overlay/user-bundles.d/user/contents.d/remote-control
fi
