# syntax=docker/dockerfile:1

# Octos Docker image packaged from upstream prebuilt release artifacts.
# This image does not compile Octos from source: no Rust toolchain, no Cargo.
# The upstream Linux release assets are glibc builds, so use Debian.

FROM node:22-bookworm-slim

ARG TARGETARCH
ARG OCTOS_VERSION=v1.1.0
ARG OCTOS_RELEASE_BASE=https://gh-proxy.org/https://github.com/octos-org/octos/releases/download

ENV DEBIAN_FRONTEND=noninteractive \
    OCTOS_HOME=/root/.octos \
    OCTOS_CONFIG_DIR=/root/.octos \
    OCTOS_HOST=0.0.0.0 \
    OCTOS_PORT=8080

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        chromium \
        curl \
        ffmpeg \
        gcc \
        libc6-dev \
        libreoffice \
        poppler-utils \
        tar \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pptxgenjs react-icons react react-dom sharp \
    && npm cache clean --force

RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "${arch}" in \
        amd64|x86_64) triple="x86_64-unknown-linux-gnu" ;; \
        arm64|aarch64) triple="aarch64-unknown-linux-gnu" ;; \
        *) echo "Unsupported TARGETARCH: ${arch}" >&2; exit 1 ;; \
    esac; \
    bundle="octos-bundle-${triple}.tar.gz"; \
    download_url="${OCTOS_RELEASE_BASE%/}/${OCTOS_VERSION}/${bundle}"; \
    echo "Downloading prebuilt Octos bundle: ${download_url}"; \
    mkdir -p /tmp/octos-bundle /opt/octos/skills; \
    curl -fL --retry 5 --retry-delay 2 "${download_url}" -o /tmp/octos-bundle.tar.gz; \
    tar -xzf /tmp/octos-bundle.tar.gz -C /tmp/octos-bundle; \
    bundle_root="$(dirname "$(find /tmp/octos-bundle -maxdepth 3 -type f -name octos | head -n 1)")"; \
    test -n "${bundle_root}" && test -f "${bundle_root}/octos"; \
    for file in "${bundle_root}"/*; do \
        if [ -f "${file}" ]; then \
            install -m 0755 "${file}" "/usr/local/bin/$(basename "${file}")"; \
        fi; \
    done; \
    if [ -d "${bundle_root}/skills" ]; then \
        cp -a "${bundle_root}/skills/." /opt/octos/skills/; \
    fi; \
    rm -rf /tmp/octos-bundle /tmp/octos-bundle.tar.gz

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && mkdir -p /root/.octos

WORKDIR /root/.octos

EXPOSE 8080
VOLUME ["/root/.octos"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD sh -c 'curl -fsS "http://127.0.0.1:${OCTOS_PORT:-8080}/health" >/dev/null'

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["serve"]
