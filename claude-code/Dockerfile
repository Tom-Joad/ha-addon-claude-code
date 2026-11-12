# The base image is named here and nowhere else (no build.yaml, no
# BUILD_FROM argument): Dependabot only updates a FROM line it can read, and
# with the tag behind an argument the image stayed on 21.0.1 for weeks.
FROM ghcr.io/hassio-addons/base:21.0.11

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Claude Code keeps all of its state under $CLAUDE_CONFIG_DIR and $HOME. Both
# point into /data, the only directory an add-on gets that survives a restart:
# everything else lives in the Docker overlay and is discarded.
#
# CLAUDE_CODE_DISABLE_MOUSE turns off Claude Code's own mouse capture. In a
# browser terminal that capture makes text unselectable: the drag is consumed
# by Claude Code and never reaches xterm.js, and the copy it performs instead
# targets pbcopy/xclip or the tmux paste buffer, none of which reach the
# browser. Without the capture the terminal handles selection itself.
#
# DISABLE_AUTOUPDATER: the add-on manages the version itself (claude_version).
# Claude Code's own updater would move the launcher past a pinned or stable
# version during a session, and the next start would then download 300 MB
# again to move it back.
ENV \
    TERM="xterm-256color" \
    HOME="/data/home" \
    CLAUDE_CONFIG_DIR="/data/claude" \
    HASS_SERVER="http://supervisor/core" \
    CLAUDE_CODE_DISABLE_MOUSE="1" \
    DISABLE_AUTOUPDATER="1" \
    PATH="/data/home/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    S6_STAGE2_HOOK="/etc/s6-overlay/scripts/enable-check.sh"

# The builder passes the add-on version as a build argument. Declared before
# the package step, a new version makes that step miss the build cache, so
# every release runs `apk upgrade` again: without it, 1.0.2 reused the cached
# layer of 1.0.1 and shipped the old curl.
ARG BUILD_VERSION

# python3 is installed without pip on purpose, and with a single extra module,
# PyYAML (py3-yaml), for reading Home Assistant's YAML files; everything else
# the Home Assistant tooling this add-on is meant to run needs comes from the
# standard library. The claude binary is NOT installed here; it is fetched
# into /data at runtime so the image stays small and updates need no rebuild.
#
# The package versions are deliberately not pinned. What makes a build
# reproducible here is the pinned base image tag; the Alpine branch behind it
# keeps receiving updates, so an exact pin freezes nothing -- it only makes the
# build fail once that version ages out of the repository, which is what
# happened to python3, sqlite, and tmux between two builds.
# The upgrade picks up Alpine fixes newer than the base image (musl, nginx).
# The base image pins exact versions in /etc/apk/world (curl=8.22.0-r0 in
# 21.0.9), and apk upgrade never moves a pinned package, so the pins are
# dropped first: 1.0.3 kept curl 8.22.0 because of that pin.
# hadolint ignore=DL3017,DL3018
RUN \
    sed -i '/^[^.]/s/[=<>~].*$//' /etc/apk/world \
    && apk upgrade --no-cache \
    && apk add --no-cache \
        bash \
        coreutils \
        curl \
        git \
        jq \
        less \
        ncurses \
        nginx \
        py3-yaml \
        python3 \
        sqlite \
        tmux \
        ttyd

# The `ha` CLI is not part of the base image, but the add-on's own instructions
# point at it -- `ha core check` before asking for a restart, `ha core logs` to
# see what happened. It reads $SUPERVISOR_TOKEN by itself and defaults its
# endpoint to the `supervisor` host, both of which this add-on already has, so
# it needs no configuration. Pinned to a release asset rather than a package:
# a published asset stays available, so this pin cannot rot the way the apk
# pins above did.
#
# The SHA-256 of each architecture's asset is pinned next to the version and
# checked before the binary is installed, so a replaced release asset fails
# the build instead of going into the image. Dependabot can't update these:
# bump the version and both sums together (GitHub lists each asset's sha256 on
# the release, e.g. `gh api repos/home-assistant/cli/releases/tags/<version>`).
ARG HA_CLI_VERSION="5.6.0"
ARG HA_CLI_SHA256_AMD64="9d259c700bfcd45b6a793709e1fcfd304a595624dda10cfa5edde66f0b8a9656"
ARG HA_CLI_SHA256_AARCH64="4ecdbd67002defbf96e4668e62f631e9767b92d18e1ce54bfee6ddd040c20e73"
RUN \
    case "$(uname -m)" in \
        aarch64) asset="ha_aarch64"; sha256="${HA_CLI_SHA256_AARCH64}" ;; \
        x86_64) asset="ha_amd64"; sha256="${HA_CLI_SHA256_AMD64}" ;; \
        *) echo "Unsupported architecture $(uname -m)" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o /usr/bin/ha \
        "https://github.com/home-assistant/cli/releases/download/${HA_CLI_VERSION}/${asset}" \
    && echo "${sha256}  /usr/bin/ha" | sha256sum -c - \
    && chmod a+x /usr/bin/ha \
    && ha --help > /dev/null

# Copy root filesystem
COPY rootfs /

# The "top" bundle of s6-overlay references both "user" and "user2", so both
# have to exist. user2 stays empty, and an empty directory cannot be tracked in
# git without putting a file inside it -- which s6-rc would then read as the
# name of a service. Hence it is created here instead.
RUN \
    mkdir -p /etc/s6-overlay/user-bundles.d/user2/contents.d \
    && printf bundle > /etc/s6-overlay/user-bundles.d/user2/type

# Ensure the scripts we ship are executable regardless of how git checked them out
RUN \
    chmod a+x /etc/s6-overlay/scripts/enable-check.sh \
        /usr/bin/claude-session \
        /usr/bin/claude-memory-baseline \
    && find /etc/s6-overlay/s6-rc.d -type f \( -name run -o -name finish -o -name up \) \
        -exec chmod a+x {} +

# The HA builder passes only BUILD_ARCH and BUILD_VERSION, and sets the arch,
# version, created and source labels itself; the revision comes from the
# workflow. Everything else is written out here. The base image's own authors,
# vendor, url and documentation labels are overridden, or the published image
# would name the base image's maintainer.
ARG BUILD_ARCH

LABEL \
    io.hass.name="Claude Code" \
    io.hass.description="Claude Code in your browser, for maintaining this Home Assistant installation" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Tom-Joad" \
    org.opencontainers.image.title="Claude Code" \
    org.opencontainers.image.description="Claude Code in your browser, for maintaining this Home Assistant installation" \
    org.opencontainers.image.authors="Tom-Joad" \
    org.opencontainers.image.vendor="Tom-Joad" \
    org.opencontainers.image.url="https://github.com/Tom-Joad/ha-addon-claude-code" \
    org.opencontainers.image.documentation="https://github.com/Tom-Joad/ha-addon-claude-code/blob/main/claude-code/DOCS.md" \
    org.opencontainers.image.source="https://github.com/Tom-Joad/ha-addon-claude-code" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.version="${BUILD_VERSION}"
