# Changelog

## 0.1.0

First release.

- Claude Code in the browser through Home Assistant Ingress: ttyd serving a
  tmux session, so reloading the page or closing the tab does not interrupt a
  running task.
- All Claude Code state on the persistent volume via `CLAUDE_CONFIG_DIR` and
  `HOME`, so the login and the accumulated memory survive restarts and updates.
- The Claude Code binary is installed into `/data` rather than baked into the
  image, and only re-downloaded when the version changes.
- Remote Control with three modes: `server`, `session`, and `disabled`.
- Add-on instructions shipped as a managed `CLAUDE.md`, loaded before any
  project instructions.
- One-time, non-destructive import of state from an earlier setup under
  `<config>/.claude`.
- Options for transcript retention, Claude Code version, extra packages, and
  init commands.
