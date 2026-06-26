# Octos Docker 镜像

这个镜像用于自托管 [Octos](https://github.com/octos-org/octos/)。它从上游源码 tag 编译 `octos` 和 bundled skill 二进制，并补齐浏览器、文档处理、媒体处理和 Node 运行依赖，适合直接用 Docker 或 Docker Compose 跑 `octos serve`。

镜像不再下载官方 Linux release bundle。构建阶段从源码编译 musl 目标的静态 Rust 二进制，`octos` 和 bundled skill binaries 本身不依赖 glibc。运行阶段仍使用 Debian bookworm 系列镜像，用来提供 Node、Chromium、LibreOffice、FFmpeg 等系统运行依赖。

当前跟踪的上游版本见 [latest.txt](latest.txt)。

## 镜像地址

```text
ghcr.io/dockers-x/octos:latest
ghcr.io/dockers-x/octos:v1.1.0
```

支持的平台：

- `linux/amd64`
- `linux/arm64`

## 快速启动

### Docker Compose

```bash
cp .env.example .env
# 编辑 .env，设置 OCTOS_AUTH_TOKEN，并至少填一个 LLM provider API key。
docker compose pull
docker compose up -d --no-build
```

启动后访问：

- 管理后台：`http://localhost:8080/admin/`
- 用户应用：`http://localhost:8080/app/`

查看日志：

```bash
docker compose logs -f
```

### Docker Run

```bash
docker run -d \
  --name octos \
  --restart unless-stopped \
  -p 8080:8080 \
  -v octos-data:/root/.octos \
  -e OCTOS_AUTH_TOKEN=change-me-to-a-long-random-token \
  -e OPENAI_API_KEY=sk-... \
  ghcr.io/dockers-x/octos:latest
```

## 这个镜像包含什么

- 从上游源码 tag 编译出的静态 musl `octos` 二进制。
- 从同一源码 tag 编译出的静态 musl bundled app/platform skill 二进制。
- 上游内置的本地 skills，镜像内路径是 `/opt/octos/skills`。
- Chromium、FFmpeg、LibreOffice、Poppler 等常用运行依赖，用于浏览器自动化、文档转换、媒体处理等场景。
- Node 22 运行环境，以及 `pptxgenjs`、`react`、`react-dom`、`react-icons`、`sharp` 这些全局 Node 包。

容器默认执行：

```bash
octos serve --host 0.0.0.0 --port 8080
```

如果设置了 `OCTOS_AUTH_TOKEN`，入口脚本会自动加上 `--auth-token`。

## 数据目录

容器内的 Octos 数据目录是：

```text
/root/.octos
```

Compose 默认把它挂到 `octos-data` volume。这个目录里会保存配置、会话、记忆、日志、用户 skills 等数据。升级或重建容器时，只要保留这个 volume，数据就不会丢。

首次启动时，入口脚本会做几件事：

- 创建 `/root/.octos/config.json`。
- 创建 `profiles`、`memory`、`sessions`、`skills`、`logs`、`research`、`history` 等目录。
- 把镜像内置的 skills 从 `/opt/octos/skills` 同步到数据目录，已存在的同名目录不会覆盖。
- 如果还没有 `SOUL.md` 和 `USER.md`，写入默认文件。

## 配置

主要配置都在 [.env.example](.env.example) 里：

| 变量 | 说明 | 默认值 |
| --- | --- | --- |
| `OCTOS_IMAGE` | Compose 使用的镜像名 | `ghcr.io/dockers-x/octos:latest` |
| `OCTOS_HTTP_PORT` | 映射到宿主机的端口 | `8080` |
| `OCTOS_AUTH_TOKEN` | 传给 `octos serve --auth-token` 的访问 token | 空 |
| `TZ` | 容器时区 | `Asia/Shanghai` |
| `OPENAI_API_KEY` | OpenAI provider key | 空 |
| `ANTHROPIC_API_KEY` | Anthropic provider key | 空 |
| `GEMINI_API_KEY` | Gemini provider key | 空 |
| `DEEPSEEK_API_KEY` | DeepSeek provider key | 空 |
| `MOONSHOT_API_KEY` / `KIMI_API_KEY` | Moonshot/Kimi provider key | 空 |
| `DASHSCOPE_API_KEY` | DashScope provider key | 空 |
| `OCTOS_VERSION` | 本地构建时下载的上游源码 tag | `v1.1.0` |
| `OCTOS_SOURCE_BASE` | 本地构建时使用的上游 Octos GitHub 项目地址 | `https://github.com/octos-org/octos` |
| `OCTOS_WEB_SOURCE_BASE` | 本地构建时使用的上游 octos-web GitHub 项目地址 | `https://github.com/octos-org/octos-web` |
| `OCTOS_WEB_REF` | 覆盖 octos-web submodule commit；留空时自动读取 `OCTOS_VERSION` 对应的 submodule commit | 空 |
| `RUST_TOOLCHAIN` | 本地构建源码时使用的 Rust toolchain | `1.88.0` |
| `OCTOS_RUST_TARGET` | 覆盖 Rust 编译 target；留空时按 Docker `TARGETARCH` 自动选择 musl target | 空 |

首次启动时，如果还没有 `config.json`，入口脚本会根据已设置的 API key 生成最小配置。自动识别顺序是 Anthropic、Gemini、DeepSeek、Moonshot/Kimi、DashScope，最后回退到 OpenAI。如果没有设置任何 key，也会生成 OpenAI 模板配置，之后需要补上 `OPENAI_API_KEY` 或手动修改配置。

`.env.example` 里还保留了 Minimax、NVIDIA、Zhipu 等 provider key 变量，它们会透传给容器。如果你要用这些 provider，或者想指定不同模型，可以直接改 volume 里的 `/root/.octos/config.json`，然后重启容器。

## 常用命令

```bash
# 启动
docker compose up -d --no-build

# 查看日志
docker compose logs -f

# 重启
docker compose restart

# 停止并删除容器，保留数据卷
docker compose down

# 停止并删除容器，同时删除数据卷
docker compose down -v
```

删除数据卷会清掉 `/root/.octos` 里的配置和运行数据，执行前先确认不再需要这些数据。

## 自己构建镜像

本地构建时默认从 GitHub 下载 `octos-org/octos` 的 `OCTOS_VERSION` 源码 tag，然后在镜像 builder 阶段编译源码：

```bash
docker compose up -d --build
```

也可以直接用 `docker build`：

```bash
docker build \
  --build-arg OCTOS_SOURCE_BASE=https://github.com/octos-org/octos \
  --build-arg OCTOS_WEB_SOURCE_BASE=https://github.com/octos-org/octos-web \
  --build-arg OCTOS_VERSION=v1.1.0 \
  --build-arg RUST_TOOLCHAIN=1.88.0 \
  --build-arg OCTOS_RUST_TARGET=x86_64-unknown-linux-musl \
  -t ghcr.io/dockers-x/octos:v1.1.0 .
```

`OCTOS_VERSION` 对应上游 Octos 源码 tag。当前默认值是 `v1.1.0`。

## 安全建议

- 不要把未设置 `OCTOS_AUTH_TOKEN` 的服务直接暴露到公网。
- 公网部署建议放在反向代理后面，并配置 HTTPS。
- API key 建议通过 Compose `.env`、Docker secrets 或 CI secrets 注入，不要写进镜像。

## 维护说明

这个仓库带有两个 GitHub Actions workflow：

- [check-update.yml](.github/workflows/check-update.yml)：每天检查 `octos-org/octos` 最新 release tag，版本变化时更新 `latest.txt`。
- [docker-build.yml](.github/workflows/docker-build.yml)：根据 `latest.txt` 从源码构建并推送多架构镜像。

也可以手动触发：

```bash
gh workflow run check-update.yml
gh workflow run docker-build.yml
gh workflow run docker-build.yml -f version=v1.1.0
```

## 上游项目

- Octos：https://github.com/octos-org/octos/
- 上游 release：https://github.com/octos-org/octos/releases
