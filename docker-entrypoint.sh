#!/bin/sh
set -eu

: "${OCTOS_HOME:=/root/.octos}"
: "${OCTOS_CONFIG_DIR:=${OCTOS_HOME}}"
: "${OCTOS_HOST:=0.0.0.0}"
: "${OCTOS_PORT:=8080}"

export OCTOS_HOME OCTOS_CONFIG_DIR

mkdir -p \
    "${OCTOS_HOME}/profiles" \
    "${OCTOS_HOME}/memory" \
    "${OCTOS_HOME}/sessions" \
    "${OCTOS_HOME}/skills" \
    "${OCTOS_HOME}/logs" \
    "${OCTOS_HOME}/research" \
    "${OCTOS_HOME}/history" \
    "${OCTOS_CONFIG_DIR}"

if [ -d /opt/octos/skills ]; then
    for skill in /opt/octos/skills/*; do
        [ -e "${skill}" ] || continue
        target="${OCTOS_HOME}/skills/$(basename "${skill}")"
        if [ ! -e "${target}" ]; then
            cp -a "${skill}" "${target}"
        fi
    done
fi

if [ ! -f "${OCTOS_CONFIG_DIR}/config.json" ]; then
    provider="openai"
    model="gpt-4.1-mini"
    api_key_env="OPENAI_API_KEY"

    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        provider="anthropic"
        model="claude-sonnet-4-20250514"
        api_key_env="ANTHROPIC_API_KEY"
    elif [ -n "${GEMINI_API_KEY:-}" ]; then
        provider="gemini"
        model="gemini-2.5-flash"
        api_key_env="GEMINI_API_KEY"
    elif [ -n "${DEEPSEEK_API_KEY:-}" ]; then
        provider="deepseek"
        model="deepseek-chat"
        api_key_env="DEEPSEEK_API_KEY"
    elif [ -n "${MOONSHOT_API_KEY:-}" ]; then
        provider="moonshot"
        model="kimi-k2.5"
        api_key_env="MOONSHOT_API_KEY"
    elif [ -n "${KIMI_API_KEY:-}" ]; then
        provider="moonshot"
        model="kimi-k2.5"
        api_key_env="KIMI_API_KEY"
    elif [ -n "${DASHSCOPE_API_KEY:-}" ]; then
        provider="dashscope"
        model="qwen-plus"
        api_key_env="DASHSCOPE_API_KEY"
    fi

    cat > "${OCTOS_CONFIG_DIR}/config.json" <<EOF
{
  "provider": "${provider}",
  "model": "${model}",
  "api_key_env": "${api_key_env}",
  "mode": "local"
}
EOF
    chmod 600 "${OCTOS_CONFIG_DIR}/config.json"
fi

if [ ! -f "${OCTOS_HOME}/SOUL.md" ]; then
    cat > "${OCTOS_HOME}/SOUL.md" <<'EOF'
# Soul - Who You Are

## Core Principles

- Help, don't perform. Skip filler phrases - just do the thing.
- Be resourceful. Come back with answers, not questions.
- Have a voice. You can disagree and suggest alternatives.
- Match the medium. Short channels get concise replies. CLI gets detail.

## Trust & Safety

- Private things stay private.
- External actions need care. Internal actions are yours.
- Never send half-finished replies to messaging channels.
EOF
fi

if [ ! -f "${OCTOS_HOME}/USER.md" ]; then
    cat > "${OCTOS_HOME}/USER.md" <<'EOF'
# User Info

Add your information and preferences here.
EOF
fi

has_arg() {
    needle="$1"
    shift
    for arg in "$@"; do
        case "${arg}" in
            "${needle}"|"${needle}="*) return 0 ;;
        esac
    done
    return 1
}

if [ "$#" -eq 0 ]; then
    set -- serve
fi

if [ "$1" = "octos" ]; then
    shift
fi

if [ "$#" -eq 0 ]; then
    set -- serve
fi

if [ "${1#-}" != "$1" ]; then
    set -- serve "$@"
fi

if [ "$1" = "serve" ]; then
    if ! has_arg "--host" "$@"; then
        set -- "$@" --host "${OCTOS_HOST}"
    fi
    if ! has_arg "--port" "$@"; then
        set -- "$@" --port "${OCTOS_PORT}"
    fi
    if [ -n "${OCTOS_AUTH_TOKEN:-}" ] && ! has_arg "--auth-token" "$@"; then
        set -- "$@" --auth-token "${OCTOS_AUTH_TOKEN}"
    fi
fi

exec octos "$@"
