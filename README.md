# Octos Docker

这个仓库用于把 [octos-org/octos](https://github.com/octos-org/octos/) 的上游二进制 release 成品打包成 Docker 镜像。镜像不编译 Octos 源码，不安装 Rust/Cargo 工具链，只下载上游 `octos-bundle-*-unknown-linux-gnu.tar.gz` 并启动其中的 `octos` 二进制。

默认 release 成品下载源使用你提供的 gh-proxy 镜像前缀：

```text
https://gh-proxy.org/https://github.com/octos-org/octos/releases/download
```

当前上游版本记录在 [latest.txt](latest.txt)。

## 快速启动

```bash
cp .env.example .env
# 编辑 .env，至少设置 OCTOS_AUTH_TOKEN 和一个 LLM Provider API Key。
# 如需本地打包镜像，compose 会直接下载上游二进制 release 成品。
docker compose up -d --build
```

启动后打开：

- 管理后台：`http://localhost:8080/admin/`
- 用户应用：`http://localhost:8080/app/`

如果设置了 `OCTOS_AUTH_TOKEN`，访问后台 API 或受保护页面时使用该 token。

## docker-compose

[docker-compose.yml](docker-compose.yml) 会启动一个长期运行的 `octos serve` 服务：

- 容器内端口：`8080`
- 宿主端口：由 `OCTOS_HTTP_PORT` 控制，默认 `8080`
- 数据卷：`octos-data:/root/.octos`
- 配置文件：首次启动自动生成到 `/root/.octos/config.json`
- bundled skills：镜像内置到 `/opt/octos/skills`，首次启动同步到数据卷

常用命令：

```bash
docker compose logs -f
docker compose restart
docker compose down
docker compose down -v  # 删除数据卷，慎用
```

## 环境变量

主要变量在 [.env.example](.env.example) 中：

| 变量 | 作用 | 默认值 |
| --- | --- | --- |
| `OCTOS_VERSION` | 构建时下载的 Octos release tag | `v1.1.0` |
| `OCTOS_RELEASE_BASE` | release bundle 下载前缀 | gh-proxy release 前缀 |
| `OCTOS_IMAGE` | Compose 使用/标记的镜像名 | `ghcr.io/dockers-x/octos:latest` |
| `OCTOS_HTTP_PORT` | 宿主机暴露端口 | `8080` |
| `OCTOS_AUTH_TOKEN` | `octos serve --auth-token` | 空 |
| `OPENAI_API_KEY` 等 | LLM provider key | 空 |

首次启动时，入口脚本会根据已设置的 API key 自动生成最小 `config.json`。如果没有任何 key，会默认写入 OpenAI provider，但你仍需要设置 `OPENAI_API_KEY` 或手动修改数据卷里的配置。

## 手动打包镜像

默认使用 gh-proxy 下载上游二进制 bundle。这里的 `docker build` 只是打包镜像，不会编译 Octos：

```bash
docker build \
  --build-arg OCTOS_VERSION=v1.1.0 \
  --build-arg OCTOS_RELEASE_BASE=https://gh-proxy.org/https://github.com/octos-org/octos/releases/download \
  -t ghcr.io/dockers-x/octos:v1.1.0 .
```

如需改回 GitHub 官方地址：

```bash
docker build \
  --build-arg OCTOS_RELEASE_BASE=https://github.com/octos-org/octos/releases/download \
  -t octos:local .
```

## GitHub Actions

本仓库包含两个 workflow：

- [check-update.yml](.github/workflows/check-update.yml)：每天检查 `octos-org/octos` 最新 release。如果版本变化，更新 `latest.txt` 并提交。
- [docker-build.yml](.github/workflows/docker-build.yml)：在 `latest.txt`、Dockerfile、入口脚本或 compose 变化时，把上游二进制成品打包并推送多架构镜像。

也可以用 GitHub CLI 手动触发：

```bash
# 检查上游 release，有新版本时更新 latest.txt
gh workflow run check-update.yml

# 直接按 latest.txt 打包并推送镜像
gh workflow run docker-build.yml

# 指定上游 release tag 打包
gh workflow run docker-build.yml -f version=v1.1.0
```

镜像推送到：

```text
ghcr.io/<github-owner>/octos:latest
ghcr.io/<github-owner>/octos:<version>
```

当前矩阵支持：

- `linux/amd64`
- `linux/arm64`

## 安全建议

- 不要把未设置 `OCTOS_AUTH_TOKEN` 的管理后台直接暴露到公网。
- 生产环境建议放在反向代理后面，并配置 HTTPS。
- API key 建议通过 Compose `.env`、Docker secrets 或 CI secrets 注入，不要写入镜像。

## 上游信息

- Octos 项目：https://github.com/octos-org/octos/
- v1.1.0 安装脚本镜像地址：https://gh-proxy.org/https://github.com/octos-org/octos/releases/download/v1.1.0/install.sh
- 上游 self-hosted 默认入口：`octos serve --host 0.0.0.0 --port 8080`
