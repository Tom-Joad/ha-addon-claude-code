# Home Assistant Add-on Repository: Claude Code

Claude Code in your browser, for maintaining a Home Assistant installation.

## Add-ons

### [Claude Code](./claude-code)

A terminal in the Home Assistant sidebar running Claude Code against your
configuration directory. Not an IDE — the point is to let Claude work on
Home Assistant itself: configuration, automations, dashboards, the entity
registry.

- Runs behind Ingress, so it uses Home Assistant's own authentication and needs
  no port of its own.
- The session lives in tmux: reloading the page or closing the tab does not
  interrupt a running task.
- Login and accumulated memory persist across restarts and add-on updates.
- Optional Remote Control, to continue a session from your phone or another
  browser. Outbound HTTPS only.

See [the documentation](./claude-code/DOCS.md) for options and details.

## Installation

Add this repository to the Home Assistant add-on store, then install the
**Claude Code** add-on from it.

## Requirements

- A Home Assistant OS or Supervised installation, `aarch64` or `amd64`.
- A Claude account. Remote Control additionally requires a Pro or Max
  subscription.

## License

MIT. See [LICENSE](./LICENSE).
