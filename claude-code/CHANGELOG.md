# Changelog

## 0.1.4

- Text in the terminal can be selected and copied again. Claude Code captures
  mouse events for its own selection, which in a browser terminal means the
  drag never reaches xterm.js and the copy it makes instead ends up in
  `pbcopy`, `xclip`, or the tmux paste buffer — never in the browser's
  clipboard. The add-on now sets `CLAUDE_CODE_DISABLE_MOUSE=1`, so the terminal
  handles selection itself: drag, then Ctrl+Shift+C (Cmd+C on macOS). This was
  most visible at `/login`, where the OAuth URL could not be copied out at all.
  Mouse capture can be restored for one session with
  `env -u CLAUDE_CODE_DISABLE_MOUSE claude`.
- Refreshed the pinned Alpine package versions for python3, sqlite, and tmux
  (tmux moves from 3.6b to 3.7c). The pinned versions had aged out of the
  repository, so the image no longer built.

## 0.1.3

- Remote Control is now off by default. A fresh installation stays local: no
  session is registered, nothing is stored on Anthropic servers, and telemetry
  and non-essential traffic are switched off with it. Set `remote_control` to
  `session` or `server` to turn it on.
- An unreadable configuration now falls back to `disabled` rather than to
  `server`, so a failure to read the setting cannot end in a connection nobody
  asked for.

Existing installations keep whatever they have configured; this only changes
what a new installation starts out with.

## 0.1.2

Fixes from a review pass, plus two more that verifying those fixes uncovered.

Worth applying rather than skipping: on the default `claude_version: latest`,
updating never took effect, and the add-on wrote roughly 300 MB to the
persistent volume on every start trying again. Everything here failed quietly,
which is the reason it went unnoticed.

- `claude_version: stable` froze the version. A channel was never resolved to a
  concrete version, so after the first install the freshness check could not
  tell "up to date" from "unknown" and always chose to do nothing. Both `latest`
  and `stable` are now resolved before the check, and a value that is neither a
  channel nor a version is reported and treated as `latest` instead of being
  handed to the installer to reject.
- The state import carried over the very symlink it replaces. `cp -a` preserves
  symlinks, so the old `projects/<project>/memory` link into the configuration
  directory came along and kept pointing at the old location, ready to dangle
  once that location was cleaned up. Imported symlinks that lead outside `/data`
  are now dropped, and named in the log.
- The Remote Control mode was read in two places with different fallbacks, so a
  failed configuration read removed the Remote Control service while the rest of
  the add-on carried on as if it were enabled. Both callers now share one
  function, which also reports an unreadable or unknown value instead of
  silently treating it as "not server".
- `claude-memory-baseline update` on an empty memory directory wrote an empty
  baseline, which `sha256sum` rejects as malformed -- so every later session
  start reported a mismatch that looked like memory loss. It now refuses, and
  `check` ignores an empty baseline it finds.
- Updating never actually updated. The official installer delegates to
  `claude install` without `--force`, which sees an existing installation and
  leaves the launcher pointing at the old build, so the version stayed put and
  every single start downloaded 300 MB and concluded it still had to update.
  With a binary already present the add-on now calls `claude install --force`
  directly, which also skips the installer's redundant download of its own copy,
  and it warns if the version still does not match afterwards.
- Superseded builds are removed. Nothing cleaned up the previous build, so each
  update left another ~300 MB behind on the persistent volume.
- The Remote Control restart delay was cut short. s6 kills a `finish` script
  after 5 seconds by default, well before the intended 15, so the service
  respawned faster than designed after an immediate failure. The service
  directory now ships a `timeout-finish` that allows for it.

## 0.1.1

- Fix the terminal failing to start with `iface hassio ... DOESN'T EXIST`. ttyd
  was told to bind an interface named `hassio`, which only exists for add-ons
  running with `host_network`. This add-on is an ordinary member of the
  Supervisor bridge, so it now binds normally and is reached through Ingress.

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
