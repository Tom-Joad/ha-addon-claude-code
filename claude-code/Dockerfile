ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.1
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

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
ENV \
    TERM="xterm-256color" \
    HOME="/data/home" \
    CLAUDE_CONFIG_DIR="/data/claude" \
    HASS_SERVER="http://supervisor/core" \
    CLAUDE_CODE_DISABLE_MOUSE="1" \
    PATH="/data/home/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    S6_STAGE2_HOOK="/etc/s6-overlay/scripts/enable-check.sh"

# python3 is installed without pip and without any extra modules on purpose:
# the Home Assistant tooling this add-on is meant to run is written against the
# standard library only. The claude binary is NOT installed here; it is fetched
# into /data at runtime so the image stays small and updates need no rebuild.
#
# The package versions are deliberately not pinned. What makes a build
# reproducible here is the pinned base image tag; the Alpine branch behind it
# keeps receiving updates, so an exact pin freezes nothing -- it only makes the
# build fail once that version ages out of the repository, which is what
# happened to python3, sqlite, and tmux between two builds.
# hadolint ignore=DL3018
RUN \
    apk add --no-cache \
        bash \
        coreutils \
        curl \
        git \
        jq \
        less \
        ncurses \
        python3 \
        sqlite \
        tmux \
        ttyd

# Copy root filesystem
COPY rootfs /

# The "top" bundle of s6-overlay references both "user" and "user2", so both
# have to exist. user2 stays empty, and an empty directory cannot be tracked in
# git without putting a file inside it -- which s6-rc would then read as the
# name of a service. Hence it is created here instead.
RUN \
    mkdir -p /etc/s6-overlay/user-bundles.d/user2/contents.d \
    && echo -n bundle > /etc/s6-overlay/user-bundles.d/user2/type

# Ensure the scripts we ship are executable regardless of how git checked them out
RUN \
    chmod a+x /etc/s6-overlay/scripts/enable-check.sh \
        /usr/bin/claude-session \
        /usr/bin/claude-memory-baseline \
    && find /etc/s6-overlay/s6-rc.d -type f \( -name run -o -name finish -o -name up \) \
        -exec chmod a+x {} +

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Tom-Joad" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
