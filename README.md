# 企业微信 Docker 版 (Fedora 43 适配版)

本项目专为 **Fedora 43 (DNF5)** 优化，解决了依赖冲突、官方 Docker 仓库配置及 Wine UI 兼容性问题。

## 🚀 快速开始

### 1. 配置 Docker 代理 (必备)
若拉取镜像超时，请配置 Docker 守护进程代理。编辑或创建以下文件：
`/etc/systemd/system/docker.service.d/http-proxy.conf`

内容模板：
```ini
[Service]
Environment="HTTP_PROXY=http://您的代理服务器IP:端口"
Environment="HTTPS_PROXY=http://您的代理服务器IP:端口"
```

完成后执行：
```bash
sudo systemctl daemon-reload && sudo systemctl restart docker
```

### 2. 启动项目
```bash
git clone https://github.com/kissunyeason/linux-wxwork.git
cd linux-wxwork
chmod +x launcher.sh
./launcher.sh
```

## 🛠️ 功能特性
- **DNF5 兼容**：自动配置 Docker 官方 Repo。
- **依赖自愈**：按需自动安装 X11 相关组件。
- **视觉优化**：自动消除 Wine 窗口黑边。

## 🌟 特别致谢
本项目核心镜像能力源自 [zwhy2025/wine-docker](https://github.com/zwhy2025/wine-docker)。
