# 企业微信 Docker 版 (Fedora 43 适配版)

本项目专为 **Fedora 43** 深度优化，解决了 DNF5 环境下的依赖安装、Docker 仓库配置及 Wine 窗口黑边等兼容性问题。

## 🚀 快速开始 (Fedora 43)

### 1. 配置系统代理 (推荐)
由于镜像约 2GB，建议先配置 DNF 代理以加速下载：
```bash
sudo bash -c 'echo "proxy=http://10.0.2.2:20122" >> /etc/dnf/dnf.conf'
```

### 2. 一键克隆与启动
无需手动安装 Docker，脚本将全自动处理依赖并启动：
```bash
git clone https://github.com/kissunyeason/linux-wxwork.git
cd linux-wxwork
chmod +x launcher.sh
./launcher.sh
```

## 🛠️ 脚本核心功能
- **DNF5 自动适配**：使用 `addrepo` 命令自动配置 Docker 官方源。
- **依赖自动补全**：识别并安装 Fedora 43 中的 `xorg-x11-utils` (包含 xset)。
- **UI 视觉优化**：自动注入注册表补丁，消除 Wine 窗口黑边。
- **权限智能处理**：检测 Docker 权限，若不足会自动引导使用 `sudo`运行。

## ⚠️ 注意事项
- **首次安装 Docker**：安装完成后建议重启系统使权限生效。
- **镜像版本**：目前强制指向 `zwhy2025/wine-docker:base` 镜像。

## 🌟 特别致谢
本项目核心镜像能力源自 [zwhy2025/wine-docker](https://github.com/zwhy2025/wine-docker)，感谢原作者在 Wine-Docker 封装上所做的杰出工作！
