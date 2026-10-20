# Security policy

## Supported versions

Only the latest release of the add-on receives fixes.

## Reporting a vulnerability

Please do **not** open an issue for security problems. Report them privately
through GitHub instead: on the
[Security tab](https://github.com/Tom-Joad/ha-addon-claude-code/security),
choose **Report a vulnerability**.

## Scope notes

The add-on runs Claude Code with write access to your Home Assistant
configuration, the add-on configurations, `/share` and `/backup`, and with
the Supervisor's `manager` role. That is its purpose; treat access to the
**Claude** panel like access to a Home Assistant administrator account. It
is only reachable through Home Assistant's Ingress, behind Home Assistant's
own login, and opens no port of its own. Inside the Supervisor's network,
ttyd listens on a socket only, and nginx accepts connections from the
Ingress proxy (`172.30.32.2`) and nothing else, so other add-ons can't reach
the terminal (since 0.1.7; `tools/dev/ingress-test.sh` checks it). Of particular interest:

- a way to reach the terminal without a Home Assistant login
- the Supervisor token, your Claude login or Home Assistant secrets ending
  up in logs, in the add-on's options or anywhere outside `/data`
- Remote Control (off by default) exposing more than the session it was
  started for

## Supply chain

Images are built by GitHub Actions with Home Assistant's builder for each
published release. Third-party actions are pinned to commit SHAs, the base
image to a version tag, and the `ha` CLI to a release. The Claude Code
binary is downloaded at add-on start from Anthropic's release channel.
