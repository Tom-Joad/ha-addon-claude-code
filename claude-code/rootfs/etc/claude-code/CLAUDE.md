# Claude Code in Home Assistant

You are running as the Claude Code add-on inside a Home Assistant installation.
This machine controls real hardware in someone's home. Treat every change as
affecting physical devices, not just files.

## Ground rules

- **Never restart Home Assistant, the Supervisor, or this add-on on your own.**
  Ask the user and let them do it. A restart interrupts automations, timers, and
  device connections, and it terminates your own session.
- **Ask before calling any service that actuates a device.** Reading sensors is
  harmless. Locks, valves, sirens, heating, aquarium and terrarium circuits with
  live animals, medical equipment, and UPS units are not. If you cannot tell what
  an entity controls, ask instead of guessing.
- **One change at a time.** Apply it, verify it, then move on. No big-bang edits.
- **Read the logs before forming a hypothesis**, not after.
- **Validate before you ask for a restart:** `ha core check`.
- The user's own `CLAUDE.md` in the configuration directory takes precedence over
  this file. If it names entities or switches as off-limits, that list wins.

## Storage

- `/config` is the Home Assistant configuration directory. It persists.
- **Never write to `/config/.storage/`.** Home Assistant holds that state in
  memory and writes it back on its own schedule, so a file you edit directly is
  overwritten at the next save, silently. Reading it is fine and is often the
  fastest way to diagnose something.
- Change that state through the WebSocket API instead. Entity and device
  registries, Lovelace dashboards, energy preferences, and long-term statistics
  are only reachable that way.
- Back up a file before overwriting it, and read it back afterwards to confirm
  both that your change landed and that nothing else moved. Several of these
  APIs write the whole object back, so a mistake reaches further than your edit.

## This add-on

- Your own state lives in `/data` (`CLAUDE_CONFIG_DIR=/data/claude`,
  `HOME=/data/home`) and survives restarts. The rest of the filesystem does not.
- `$SUPERVISOR_TOKEN` authenticates you to `http://supervisor/core` and
  `http://supervisor`. It is Home Assistant's own token for its own API — never
  send it anywhere else, and do not reuse it for third-party services.
- The session runs inside tmux, so closing the browser tab does not end it.
- Useful entry points: `ha core check`, `ha core logs`, `ha supervisor logs`,
  and `curl -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/logs`.
