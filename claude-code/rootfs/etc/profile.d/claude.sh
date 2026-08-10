# shellcheck shell=bash
# ==============================================================================
# Home Assistant Add-on: Claude Code
# ==============================================================================
#
# The tmux session runs a login shell, which sources /etc/profile and can reset
# PATH to the system default. That would put the claude binary in /data out of
# reach, so the environment is restated here.

export HOME="${HOME:-/data/home}"
export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-/data/claude}"
export HASS_SERVER="${HASS_SERVER:-http://supervisor/core}"

case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac
