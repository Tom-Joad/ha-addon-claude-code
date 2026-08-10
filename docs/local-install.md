# Installing without adding the repository

The normal way to install this add-on is to add the repository URL to the Home
Assistant add-on store. That requires the repository to be readable by the
Supervisor, which clones it anonymously — so it does not work for a private
repository, and it is not what you want while testing a build that is not
released yet.

There is a second route. The Supervisor decides between building an add-on
locally and pulling a prebuilt image purely on whether `config.yaml` contains an
`image:` field. It does not care where the add-on definition came from. So a
local add-on consisting of nothing but a `config.yaml` will pull the prebuilt
image, and the repository never enters the picture.

That also means no build load on the Home Assistant machine, which matters on
an SD card or eMMC.

## Prebuilt image from a private package

If the container image is private, the Supervisor needs credentials for the
registry. Create a GitHub personal access token with the `read:packages` scope,
then, on the Home Assistant machine:

```bash
ha docker registries add ghcr.io --username <github-user> --password <token>
```

## Add the add-on locally

Create `/addons/claude-code/config.yaml` on the Home Assistant machine with the
same content as [`claude-code/config.yaml`](../claude-code/config.yaml) in this
repository. That single file is the whole local add-on — no `Dockerfile` and no
`rootfs`, because nothing is built.

Then reload the add-on store (**Settings → Add-ons → Add-on store → ⋮ → Check
for updates**) and install **Claude Code** from the *Local add-ons* section.

## Updating

The Supervisor pulls `image:version`, with `version` taken from that same file.
To move to a new release, change the `version:` line in
`/addons/claude-code/config.yaml` to match the release, reload the store, and
the add-on offers the update.

## Switching to the normal route later

Once the repository and the package are public, delete
`/addons/claude-code/`, remove the registry credentials if you no longer need
them, and add the repository URL to the add-on store instead. The same
`config.yaml` is used either way, so nothing else changes — but note that the
add-on is then a different installation as far as the Supervisor is concerned,
so back up `/data` first if you want to keep your login and memory.
