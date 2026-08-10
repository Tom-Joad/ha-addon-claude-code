ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.1
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Claude Code keeps all of its state under $CLAUDE_CONFIG_DIR and $HOME. Both
# point into /data, the only directory an add-on gets that survives a restart:
# everything else lives in the Docker overlay and is discarded.
ENV \
    TERM="xterm-256color" \
    HOME="/data/home" \
    CLAUDE_CONFIG_DIR="/data/claude" \
    HASS_SERVER="http://supervisor/core" \
    PATH="/data/home/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    S6_STAGE2_HOOK="/etc/s6-overlay/scripts/enable-check.sh"

# python3 is installed without pip and without any extra modules on purpose:
# the Home Assistant tooling this add-on is meant to run is written against the
# standard library only. The claude binary is NOT installed here; it is fetched
# into /data at runtime so the image stays small and updates need no rebuild.
RUN \
    apk add --no-cache \
        bash=5.3.9-r1 \
        coreutils=9.11-r0 \
        curl=8.21.0-r0 \
        git=2.54.0-r0 \
        jq=1.8.1-r0 \
        less=702-r0 \
        ncurses=6.6_p20260516-r0 \
        python3=3.14.5-r0 \
        sqlite=3.53.2-r0 \
        tmux=3.6b-r0 \
        ttyd=1.7.7-r0

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
