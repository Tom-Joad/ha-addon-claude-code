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

This is an add-on *repository*, not an add-on. Home Assistant has to be told
about it once; after that the add-on shows up in the store like any other.

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FTom-Joad%2Fha-addon-claude-code)

The button opens the dialog with the URL already filled in. To do it by hand:

1. Open **Settings → Add-ons → Add-on Store**.
2. Choose **Repositories** from the ⋮ menu, top right.
3. Paste the URL and select **Add**, then **Close**:

   ```
   https://github.com/Tom-Joad/ha-addon-claude-code
   ```

4. The store now lists a **Tom-Joad Add-ons** section. Reload the page if it
   does not appear — the ⋮ menu also has **Check for updates**.
5. Select **Claude Code**, then **Install**.

Then start the add-on, open the **Claude** panel in the sidebar, and run
`/login` once to sign in. [The documentation](./claude-code/DOCS.md) covers the
options and what the add-on does with your configuration directory.

[![Open your Home Assistant instance and show the dashboard of the Claude Code add-on.](https://my.home-assistant.io/badges/supervisor_addon.svg)](https://my.home-assistant.io/redirect/supervisor_addon/?addon=b46aad3a_claude-code&repository_url=https%3A%2F%2Fgithub.com%2FTom-Joad%2Fha-addon-claude-code)

### Installing without adding the repository

For a build that is not released yet, or a private package, the add-on can also
be dropped in as a local add-on that pulls a prebuilt image — no repository, no
build on the Home Assistant machine. See
[docs/local-install.md](./docs/local-install.md).

## Development

`tools/dev/run-local.sh` builds the image and runs it on a plain Docker host,
next to a stub that answers the Supervisor API calls bashio makes. The terminal
comes up on `http://localhost:7681`.

## Requirements

- A Home Assistant OS or Supervised installation, `aarch64` or `amd64`.
- A Claude account. Remote Control additionally requires a Pro or Max
  subscription.

## License

MIT. See [LICENSE](./LICENSE).
