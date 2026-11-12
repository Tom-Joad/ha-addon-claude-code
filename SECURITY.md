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
configuration, read access to the add-on configurations and `/share`, and
with the Supervisor's `manager` role. `/backup` is not mapped; the
`manager` role still lets it create and restore backups through the
Supervisor. That is its purpose; treat access to the
**Claude** panel like access to a Home Assistant administrator account. It
is only reachable through Home Assistant's Ingress, behind Home Assistant's
own login, and opens no port of its own. Inside the Supervisor's network,
ttyd listens on a socket only, and nginx accepts connections from the
Ingress proxy (`172.30.32.2`) and nothing else, so other add-ons can't reach
the terminal (since 0.1.7; `tools/dev/ingress-test.sh` checks it).

ttyd runs without `--check-origin`, and nginx passes the `Host` header on
unchanged. A web page on another site can't open the terminal's WebSocket
today because Home Assistant's Ingress session cookie isn't sent cross-site;
that cookie is the only barrier. If browsers or Home Assistant ever relaxed
it, a page that knows the Ingress path could reach the terminal. Turning on
`--check-origin` needs a test on a real Home Assistant first (which `Origin`
and `Host` the Ingress proxy passes on), tracked in issue #47.

Of particular interest:

- a way to reach the terminal without a Home Assistant login
- the Supervisor token, your Claude login or Home Assistant secrets ending
  up in logs, in the add-on's options or anywhere outside `/data`
- Remote Control (off by default) exposing more than the session it was
  started for

## Supply chain

Images are built by GitHub Actions with Home Assistant's builder for each
published release. Third-party actions are pinned to commit SHAs, the base
image to a version tag, and the `ha` CLI to a release whose SHA-256 is
checked during the build.

**What the signature does not cover:** the Claude Code binary. At every
add-on start the add-on reads the version of the chosen channel from
`downloads.claude.ai`, and when it differs from the installed one it downloads
that version's binary from the same place. Before the launcher moves to it, the
add-on compares the binary's SHA-256 with the checksum in Anthropic's release
manifest (`manifest.json` of that version, the same source Anthropic's own
installer uses). A build that doesn't match is deleted, the log says `ERROR`
with the expected and the actual checksum, and the add-on keeps the previous
build (or, with none installed, doesn't start). The add-on no longer runs
Anthropic's installer script or `claude install` for this.

That check has limits. The manifest comes from the same host as the binary,
over TLS, so it catches a corrupt or truncated download and a binary replaced
without its manifest, not a compromise of Anthropic's download service itself:
it is a checksum, not a signature. A build that is already installed isn't
checked again at start. What it installs runs with the add-on's rights: as
root, with the Supervisor token and write access to `/config`. Pin `claude_version` to an exact version to limit it to
a release you chose; the download still happens when that version isn't
installed yet.

Home Assistant's builder signs each image and the multi-arch manifest with
cosign, keyless through GitHub's OIDC token. To check the image your
system runs (`amd64` or `aarch64`), with cosign 3:

```sh
cosign verify ghcr.io/tom-joad/amd64-ha-addon-claude-code:<VERSION> \
  --certificate-identity-regexp '^https://github.com/Tom-Joad/ha-addon-claude-code/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

There is no SBOM or provenance attestation: the builder doesn't produce
them. A daily scan of the published image opens an issue for every fixable
vulnerability.
