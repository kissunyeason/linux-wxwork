#!/bin/bash
# Fedora 43 (DNF5) 深度适配自动化脚本

APP_PATH=$(cd "$(dirname "$0")"; pwd)
YML_FILE="$APP_PATH/docker-compose.yml"

echo "🔍 正在进行系统环境检查 (Fedora 43 DNF5 兼容模式)..."

# 1. 修正 Fedora 43 包名：xset 归属于 xorg-x11-utils
if ! command -v xset &> /dev/null; then
    echo "📦 正在安装依赖 xorg-x11-utils..."
    sudo dnf install -y xorg-x11-utils
fi

# 2. 适配 DNF5 的 Docker 安装逻辑
if ! command -v docker &> /dev/null; then
    echo "🐳 未检测到 Docker，正在自动配置 DNF5 仓库并安装..."
    # DNF5 专用添加仓库语法
    sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable --now docker
    # 确保 docker 用户组存在并加入
    sudo groupadd docker 2>/dev/null
    sudo usermod -aG docker $USER
    echo "✅ Docker 安装完成。请注意：若首次安装，建议执行 sudo ./launcher.sh 或重启系统。"
fi

# 3. 开放 X11 授权
echo "🔓 开放 X11 授权..."
xhost +local:docker > /dev/null

# 4. 启动容器 (会自动拉取 :base 镜像)
echo "🚀 正在启动环境 (首次运行请确保代理开启以拉取 2GB 镜像)..."
docker compose -f "$YML_FILE" up -d

# 5. 等待初始化并注入 UI 补丁
echo "⏳ 等待环境初始化 (10秒)..."
sleep 10
echo "🎨 应用 Fedora 43 UI 优化补丁 (消除黑边)..."
docker exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Decorated' /t REG_SZ /d 'n' /f
docker exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Compositing' /t REG_SZ /d 'y' /f

# 6. 启动微信
echo "📱 启动企业微信..."
docker exec -d wine_container /usr/bin/wxwork

echo "✅ 流程执行完毕！"
