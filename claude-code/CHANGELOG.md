# Changelog

All notable changes to the add-on are listed here. Versions follow
[semantic versioning](https://semver.org/): from 1.0.0 on, a change that needs
action when updating (a removed or renamed option, moved state) only comes
with a new major version, and its entry says what to do.

## 1.0.3 - 2026-10-27

### Security
- Security updates of the distribution packages, picked up by rebuilding the image:
  - `python3` 3.14.10-r0 (CVE-2026-114583, CVE-2026-115557, CVE-2026-12345)

## 1.0.2 - 2026-10-26

### Security
- Security updates of the distribution packages, picked up by rebuilding the image:
  - `curl` 8.23.0-r0 (CVE-2026-92392)
  - `libcurl` 8.23.0-r0 (CVE-2026-92392)

## 1.0.1 - 2026-10-22

Security updates, nothing to do when updating.

- nginx 1.30.6 (six CVEs fixed, among them session forgery with TLS session
  tickets and an HTTP/3 request body injection) and musl 1.2.6-r3
  (CVE-2026-107891). The image now upgrades its Alpine packages when it is
  built, so it no longer waits for a new base image to get them.
- The `ha` CLI 5.6.0 (was 5.5.0): newer Go libraries, three of its eight
  known HIGH vulnerabilities gone; the rest await a CLI release built with
  the fixed libraries.
- Base image 21.0.9.

## 1.0.0 - 2026-10-21

The first stable release: the options and where the add-on keeps its state
are settled, and change only with a new major version.

- **Removed:** the option `import_existing_state`. It copied state once from
  `<config>/.claude` when moving from a setup that ran Claude Code elsewhere.
  Nothing to do when updating: a value still saved for it is ignored (the
  Supervisor logs it as an unknown option until the configuration is saved
  again), and state imported earlier stays where it is.
- The add-on has its own icon and logo in the add-on store.

## 0.1.9 - 2026-10-20

- Same add-on as 0.1.8, which was never published: its release build
  stopped at the new secret scan, which doesn't run for releases. Update
  from 0.1.7 straight to 0.1.9.

## 0.1.8 - 2026-10-20 (not published)

- The add-on is built on the current base image (`hassio-addons/base`
  21.0.8, Alpine 3.24.2) instead of 21.0.1. The base image was named behind
  a build argument, where Dependabot couldn't see it, so it was never
  updated; it is now on the Dockerfile's `FROM` line, and future base images
  arrive as pull requests.
- The repository's checks run shellcheck over every script and scan the
  history for secrets on every change.

## 0.1.7 - 2026-10-20

- **Security:** the terminal is reachable only through Home Assistant's
  Ingress. ttyd used to listen on a port of the Supervisor's internal network,
  where every other add-on could open it without a Home Assistant login and
  get a root shell with this add-on's Supervisor token (`manager` role). ttyd
  now listens on a socket inside the container, and nginx in front of it
  accepts only the Ingress proxy (`172.30.32.2`), as Home Assistant requires
  for Ingress add-ons. Update right away if other add-ons run next to this one.

## 0.1.6

- PyYAML is now installed (`py3-yaml`), so `import yaml` works out of the box
  for reading Home Assistant's YAML files. Note that `yaml.safe_load` rejects
  Home Assistant's `!include` and `!secret` tags; those need a custom loader.

## 0.1.5

- The `ha` CLI is now installed. The add-on's own instructions have always
  pointed at it — `ha core check` before asking for a restart, `ha core logs`
  to see what happened — but the base image does not carry it, so those
  commands failed with `not found`. It reads the add-on's Supervisor token by
  itself and needs no configuration.

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
- The Alpine package versions are no longer pinned to exact releases. The pins
  had aged out of the repository and broke the build without freezing anything
  the pinned base image tag does not already fix. tmux moves from 3.6b to 3.7c
  as a result.

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
