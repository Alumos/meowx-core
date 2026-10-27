# MeowX Core Docker

把妙妙屋 X OpenWrt 版的 `meowx-core` 构建成普通 Linux Docker 镜像。

这个项目只打包核心，不包含 OpenWrt 的 LuCI、procd、nftables、订阅服务或主控服务。订阅链接由你自己转换/下载成 mihomo 配置后，放进挂载的 `config` 目录。

## 构建来源

- 上游源码：`meowC` 的 `core/Clash.Meta`
- 固定源码提交：`1928f639aaa43dfe7fcedc85b6e06e406d86a22c`
- 核心版本：`0.3.9`
- 编译标签：`with_gvisor,no_easytier,no_tailscale,no_zerotier`
- standalone patch：`patches/001-standalone-inbound.patch`
- panel patch：`patches/002-panel-account.patch`

源码提交和两个补丁都被固定，避免上游 main 分支变化导致今天能构建、明天不能构建。

## 本地构建

需要 Docker Buildx：

```bash
docker buildx build --load -t meowx-core:local .
```

也可以使用本地构建 override：

```bash
docker compose -f docker-compose.example.yml -f docker-compose.build.yml up -d --build
```

检查核心：

```bash
docker run --rm meowx-core:local --version
docker run --rm meowx-core:local -h
```

## 使用 Compose

复制示例：

```bash
cp config/config.yaml.example config/config.yaml
cp docker-compose.example.yml docker-compose.yml
```

编辑 `docker-compose.yml`，将：

```yaml
image: ghcr.io/YOUR_GITHUB_USER/meowx-core:latest
```

改成你的实际 GHCR 镜像路径，然后把实际的 `proxies`、`proxy-groups`、`rules` 或订阅生成的配置放到 `config/config.yaml`。如果订阅链接直接返回 Clash/Mihomo 节点列表，也可以使用 `proxy-providers` 让核心自行定时拉取；示例已放在 `config/config.yaml.example`。如果链接需要妙妙屋客户端登录态或特殊加密，单独运行核心不会替代订阅服务，需要先把订阅转换成核心能识别的配置。

配置中至少需要：

```yaml
mixed-port: 7890
allow-lan: true
bind-address: "*"
external-controller: 0.0.0.0:9090
secret: "换成随机长密码"
```

启动：

```bash
docker compose pull
docker compose up -d
docker logs -f meowx
```

MetaCubeXD 地址：`http://NAS_IP:18091`。在面板里填：

- API 地址：`http://NAS_IP:9090`
- Secret：配置文件中的 `secret`

同一个 Docker 网络中的其他服务使用 `http://meowx:7890`；NAS 宿主机或局域网设备使用 `http://NAS_IP:7890`。如果其他服务使用独立 Compose 项目，可以把名为 `meowx-proxy` 的网络声明为 external 后加入该网络。

## GitHub 私有仓库和 GHCR

GitHub 仓库可以设置为 Private，GitHub Actions 仍然可以拉取公开的 meowC 源码，并把生成的镜像推送到 GHCR。

仓库中的 `.github/workflows/build-and-push.yml` 会构建并推送：

- `linux/amd64`
- `linux/arm64`

推送到默认分支后，镜像标签为：

```text
ghcr.io/<GitHub用户名>/<仓库名>:latest
ghcr.io/<GitHub用户名>/<仓库名>:sha-xxxxxxxx
```

建议 GitHub 仓库名使用全小写，例如 `meowx-core`，这样 GHCR 镜像路径不会遇到大小写问题。

首次使用时，检查仓库的 Actions 设置允许读写 Packages。工作流已经声明：

```yaml
permissions:
  contents: read
  packages: write
```

### NAS 拉取私有镜像

在 NAS 上创建一个只用于拉取的 GitHub PAT，至少授予：

- `read:packages`
- 如果组织启用了 SSO，还需要对该 PAT 授权 SSO

在 NAS 的 Docker 环境登录：

```bash
echo 'GitHub_PAT' | docker login ghcr.io -u GitHub用户名 --password-stdin
docker pull ghcr.io/GitHub用户名/仓库名:latest
```

登录成功后，Container Manager / Docker Compose 就可以正常拉取私有 GHCR 镜像。私有 GitHub 仓库和私有 GHCR 镜像是两个权限对象：仓库设置为 Private 不代表 GHCR 访问自动不需要登录，NAS 仍需要保存一个有 `read:packages` 的凭据。

## 安全提示

- 不要把订阅链接、配置文件中的 token、面板 secret 提交到仓库。
- 建议将 `config/config.yaml` 加入 `.gitignore`，只提交 `config/config.yaml.example`。
- 不要把 7890/9090 做公网端口转发；9090 必须设置 secret。
- 当前镜像默认以 root 运行，是为了后续保留 TUN/内核网络能力；仅使用普通 HTTP/SOCKS 代理时可以进一步改成非 root。

## 更新核心

更新上游版本时，同时修改 Dockerfile 中：

- `MEOWC_COMMIT`
- `MEOWX_VERSION`
- 必要时更新 `patches/`

然后重新推送 GitHub，Actions 会生成新的多架构镜像。
