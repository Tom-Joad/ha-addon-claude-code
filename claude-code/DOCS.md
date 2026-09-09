# Home Assistant Add-on: Claude Code

Claude Code in your browser, for maintaining a Home Assistant installation.

This is a terminal, not an IDE. It exists to let Claude work on the thing it is
attached to — configuration, automations, dashboards, the entity registry — and
nothing else is bundled in.

## Installation

The add-on lives in an add-on repository, which Home Assistant has to be told
about once:

1. Open **Settings → Add-ons → Add-on Store**, choose **Repositories** from the
   ⋮ menu, and add
   `https://github.com/Tom-Joad/ha-addon-claude-code`.
2. Install **Claude Code** from the section that appears.
3. Start it, open the **Claude** panel in the sidebar, and run `/login` once to
   sign in with your Claude account.

The first start downloads the Claude Code binary, which takes a minute or two.

The login is stored in `/data`, so it survives restarts and updates. You only do
it again if you remove the add-on or restore onto a fresh machine.

## What it does with your configuration

The add-on mounts the Home Assistant configuration directory at `/config` and
starts Claude there. Two consequences worth knowing:

- A `CLAUDE.md` in that directory is picked up automatically at the start of
  every session. That is the place for instructions specific to your house:
  which entities are off limits, which conventions you use, what Claude should
  ask about rather than decide.
- The add-on ships its own instructions as well, covering the things that hold
  for any Home Assistant installation — never restart Core unprompted, never
  write into `.storage` directly, verify a change after making it. Your file is
  read after the add-on's, so where the two disagree, yours wins.

The add-on also gets the Supervisor and Home Assistant APIs, which is what makes
`ha core check`, Core logs, and the WebSocket API reachable from the session.

## Configuration

```yaml
log_level: info
cleanup_period_days: 14
claude_version: latest
remote_control: disabled
remote_control_name: Home Assistant
import_existing_state: false
packages: []
init_commands: []
```

### Option: `cleanup_period_days`

How long session transcripts are kept. They accumulate at roughly 800 KB per
hour of session. On an SD card or eMMC that write load is worth limiting, which
is why the default here is lower than Claude Code's own default of 30 days.

### Option: `claude_version`

`latest`, `stable`, or an exact version such as `2.1.226`. Anything else is
reported in the log and treated as `latest`.

Both channels are resolved to a concrete version at startup, so the add-on can
tell an up-to-date install from one that needs replacing without downloading
anything to find out. Following a channel therefore picks up new releases, and
pinning an exact version holds it there.

After an update only the build in use is kept. Each one is close to 300 MB, and
nothing else removes the one it replaced, so a handful of updates would
otherwise cost a gigabyte on storage that rarely has one to spare.

The Claude Code binary is around 300 MB and is deliberately **not** part of the
add-on image. It is downloaded into `/data` on first start and only replaced
when the version actually changes. The image stays small, updates need no
rebuild, and an add-on update does not rewrite 300 MB to the disk.

If the download fails while a working binary is already present — a slow or
failed-over uplink, for instance — the add-on logs a warning and starts with the
version it has, rather than refusing to come up.

### Option: `remote_control`

Off by default. Turned on, it lets you continue a session from your phone,
tablet, or another browser through [claude.ai/code](https://claude.ai/code) or
the Claude mobile app. All traffic is outbound HTTPS; nothing listens for
incoming connections.

| Value | Behaviour |
| --- | --- |
| `disabled` | Default. The feature is off, and `DISABLE_TELEMETRY`, `DO_NOT_TRACK`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` and `DISABLE_GROWTHBOOK` are set. Claude Code talks to the Anthropic API and to nothing else. |
| `session` | No extra service. The terminal session connects itself, so the browser terminal, the web, and your phone all show the same session. |
| `server` | A dedicated service keeps a session available at all times, whether or not a browser terminal is open. Supports several concurrent sessions. |

The three values are one setting rather than several because Remote Control and
those environment variables are mutually exclusive: each of them disables the
feature-flag lookup that Remote Control availability depends on, and setting
both leaves you with a feature that reports itself as unavailable for no visible
reason.

The default is the quiet one on purpose. Turning Remote Control on means the
session transcript is stored on Anthropic servers for as long as the connection
lasts, so that the conversation stays in sync across your devices -- worth
having when you want it, not worth switching on for someone who never asked.
Note that `disabled` also switches off feature-flag evaluation in general, not
only the part Remote Control needs.

Requirements: a Claude Pro or Max subscription, signed in with `/login`. API keys
and long-lived tokens from `claude setup-token` cannot establish a Remote Control
session. Run `claude doctor` if something does not connect.

In `server` mode the service waits until you have signed in and starts on its
own afterwards. If the machine loses network for more than about ten minutes the
remote session times out and the process exits; the add-on restarts it, so the
connection comes back by itself.

### Option: `import_existing_state`

For migrating from a setup that ran Claude Code elsewhere — for example as a
VS Code extension inside another add-on — with state under
`<config>/.claude`.

Set it to `true` and restart once. Curated memory, transcripts, the settings
file and an existing memory baseline are copied into the add-on's own storage.
Nothing already present is overwritten, and the source directory is not
modified. A marker file makes sure the import runs only once; you can set the
option back to `false` afterwards.

### Option: `packages` / `init_commands`

Extra Alpine packages and shell commands to run at startup. Failures in either
are logged but do not stop the add-on: a typo in an init command should not cost
you the terminal you would fix it from.

## Where state is kept

Everything Claude Code owns lives on the add-on's persistent volume:

| Path | Contents |
| --- | --- |
| `/data/claude` | `CLAUDE_CONFIG_DIR` — credentials, global config, settings |
| `/data/claude/memory` | Curated memory, kept apart from the transcripts |
| `/data/claude/projects` | Session transcripts |
| `/data/home` | `HOME`, including the installed binary under `.local` |

Curated memory is separated from transcripts on purpose: one is maintained, the
other is a recording you can throw away. The `autoMemoryDirectory` setting is
what puts it there.

Note that add-on backups include `/data`, and therefore include your credentials
and your transcripts. If that is not what you want, exclude them.

## Session handling

The terminal runs inside tmux. Closing the browser tab, reloading the page, or
losing your connection does not interrupt what Claude is doing — reopening the
panel reattaches to the same session. This matters for anything long-running,
where the alternative is losing the work to an accidental refresh.

If Claude exits, the pane drops to a shell in `/config` rather than dying, so
you can start it again without restarting the add-on.

## Known limitations

**Selecting text in the terminal.** Claude Code captures mouse events to drive
its own selection and click handling. In a browser terminal that leaves nothing
to select: the drag is consumed by Claude Code and never reaches xterm.js, and
the copy Claude Code performs in its place goes to `pbcopy`, `xclip`, or the
tmux paste buffer — none of which reach the browser — so nothing arrives in
your clipboard either. Logging in is where this hurts first, because the OAuth
URL has to get out of the terminal somehow.

The add-on therefore sets
[`CLAUDE_CODE_DISABLE_MOUSE=1`](https://code.claude.com/docs/en/fullscreen#keep-native-text-selection),
which hands selection back to the terminal: drag with the mouse, then press
Ctrl+Shift+C, or Cmd+C on macOS. What this costs is click-to-position,
click-to-expand, and wheel scrolling inside Claude Code; PgUp and PgDn still
scroll, and tmux scrollback (`Ctrl+b` `[`) still works. For a session with
mouse capture back on, run `env -u CLAUDE_CODE_DISABLE_MOUSE claude`.

**Copy/paste on mobile browsers.** None of the above helps on a touch device.
The terminal is rendered by [xterm.js](https://xtermjs.org/) (via ttyd), which
draws text to a canvas instead of real DOM text. Touch devices can't select
canvas text the way they select a normal web page, so long-press-to-select and
the system copy/paste menu don't work reliably in Mobile Safari or Chrome. This
is an upstream limitation of xterm.js, not something specific to this add-on —
see [xterm.js#3727](https://github.com/xtermjs/xterm.js/issues/3727) and
[xterm.js#5377](https://github.com/xtermjs/xterm.js/issues/5377), both still
open with no fix. Enabling tmux mouse mode does not help either: even ttyd's
own tracker shows a selection can be made but nothing ends up on the clipboard
([ttyd#1454](https://github.com/tsl0922/ttyd/issues/1454)).

If you need to work from a phone or tablet, enable the `remote_control`
option and continue the session from the Claude mobile app or
[claude.ai/code](https://claude.ai/code) instead of the in-add-on terminal —
that's a native UI with normal text, so copy/paste behaves as expected.

## Support

Open an issue at
<https://github.com/Tom-Joad/ha-addon-claude-code/issues>.
