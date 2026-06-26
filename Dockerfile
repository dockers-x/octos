# syntax=docker/dockerfile:1

# Octos Docker image built from upstream source.
# The Rust binaries are built for musl so octos itself does not depend on
# glibc. The runtime remains Debian because Node, Chromium, and LibreOffice
# are still installed from Debian packages.

FROM node:22-bookworm AS source

ARG OCTOS_SOURCE_BASE=https://github.com/octos-org/octos
ARG OCTOS_WEB_SOURCE_BASE=https://github.com/octos-org/octos-web
ARG OCTOS_VERSION=v1.1.0
ARG OCTOS_WEB_REF=

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tar \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN set -eux; \
    main_url="${OCTOS_SOURCE_BASE%/}/archive/refs/tags/${OCTOS_VERSION}.tar.gz"; \
    echo "Downloading Octos source: ${main_url}"; \
    curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 \
        "${main_url}" \
        -o /tmp/octos-source.tar.gz; \
    mkdir -p /tmp/octos-source; \
    tar -xzf /tmp/octos-source.tar.gz -C /tmp/octos-source --strip-components=1; \
    web_ref="${OCTOS_WEB_REF}"; \
    if [ -z "${web_ref}" ]; then \
        web_ref="$(curl -fsSL --retry 5 --retry-delay 5 --connect-timeout 30 \
            "https://api.github.com/repos/octos-org/octos/contents/octos-web?ref=${OCTOS_VERSION}" \
            | sed -n 's/.*"sha": *"\([^"]*\)".*/\1/p' \
            | head -n 1)"; \
    fi; \
    test -n "${web_ref}"; \
    web_url="${OCTOS_WEB_SOURCE_BASE%/}/archive/${web_ref}.tar.gz"; \
    echo "Downloading octos-web source: ${web_url}"; \
    curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 \
        "${web_url}" \
        -o /tmp/octos-web.tar.gz; \
    mkdir -p /tmp/octos-web; \
    tar -xzf /tmp/octos-web.tar.gz -C /tmp/octos-web --strip-components=1; \
    rm -rf /tmp/octos-source/octos-web; \
    mv /tmp/octos-web /tmp/octos-source/octos-web; \
    mv /tmp/octos-source octos; \
    rm -f /tmp/octos-source.tar.gz /tmp/octos-web.tar.gz

FROM source AS builder

ARG TARGETARCH
ARG RUST_TOOLCHAIN=1.88.0
ARG OCTOS_RUST_TARGET=
ARG OCTOS_FEATURES=api,telegram,discord,whatsapp,feishu,twilio,wecom,wecom-bot,audio_mp3
ARG OCTOS_SKILL_CRATES="-p news_fetch -p deep-search -p deep-crawl -p send-email -p account-manager -p voice -p clock -p weather -p skill-evolve"

ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        musl-tools \
        pkg-config \
        python3 \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --profile minimal --default-toolchain "${RUST_TOOLCHAIN}" \
    && rust_target="${OCTOS_RUST_TARGET}"; \
        if [ -z "${rust_target}" ]; then \
            case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
                amd64|x86_64) rust_target="x86_64-unknown-linux-musl" ;; \
                arm64|aarch64) rust_target="aarch64-unknown-linux-musl" ;; \
                *) echo "Unsupported TARGETARCH: ${TARGETARCH:-unknown}" >&2; exit 1 ;; \
            esac; \
        fi; \
        rustup target add "${rust_target}"; \
        printf '%s' "${rust_target}" > /tmp/octos-rust-target \
    && cargo --version \
    && node --version \
    && npm --version

WORKDIR /src/octos

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/octos/target \
    set -eux; \
    rust_target="$(cat /tmp/octos-rust-target)"; \
    target_env="$(printf '%s' "${rust_target}" | tr '-' '_')"; \
    # Keep Rust's default musl linker so the final executables stay static-pie.
    eval "export CC_${target_env}=musl-gcc"; \
    ./scripts/build-dashboard.sh; \
    bash scripts/build-web-app.sh; \
    CARGO_BUILD_TARGET="${rust_target}" \
        FEATURES="${OCTOS_FEATURES}" \
        SKILL_CRATES="${OCTOS_SKILL_CRATES}" \
        ./scripts/milestone-ci.sh release-bundle; \
    mkdir -p /out/bin /out/skills; \
    artifact_dir="target/${rust_target}/release"; \
    for binary in octos news_fetch deep-search deep_crawl send_email account_manager voice clock weather skill-evolve; do \
        install -m 0755 "${artifact_dir}/${binary}" "/out/bin/${binary}"; \
    done; \
    cp -a crates/octos-agent/skills/. /out/skills/

FROM node:22-bookworm-slim

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
        tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pptxgenjs react-icons react react-dom sharp \
    && npm cache clean --force

COPY --from=builder /out/bin/ /usr/local/bin/
COPY --from=builder /out/skills/ /opt/octos/skills/

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
