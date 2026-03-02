#!/bin/bash
# Fedora 43 深度适配版 - 自动安装依赖与镜像

APP_PATH=$(cd "$(dirname "$0")"; pwd)
YML_FILE="$APP_PATH/docker-compose.yml"

echo "🔍 正在进行系统环境检查..."

# 1. 修正 Fedora 下的 xset 依赖包名
if ! command -v xset &> /dev/null; then
    echo "📦 正在安装缺失的 xorg-x11-server-utils (xset)..."
    sudo dnf install -y xorg-x11-server-utils
fi

# 2. 自动安装 Docker 引擎
if ! command -v docker &> /dev/null; then
    echo "🐳 未检测到 Docker，正在尝试自动安装..."
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    echo "✅ Docker 安装完成！由于权限变更，本次请使用 sudo 运行，或重启系统后运行。"
    exit 0
fi

# 3. 开放 X11 授权
echo "🔓 开放 X11 授权..."
xhost +local:docker > /dev/null

# 4. 启动容器并拉取镜像
echo "🚀 正在启动环境 (首次拉取 base 镜像约 2GB，请保持代理开启)..."
docker compose -f "$YML_FILE" up -d

# 5. 等待初始化并注入 UI 补丁
echo "⏳ 等待环境初始化 (10秒)..."
sleep 10
echo "🎨 应用 UI 优化补丁..."
docker exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Decorated' /t REG_SZ /d 'n' /f
docker exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Compositing' /t REG_SZ /d 'y' /f

# 6. 启动微信
echo "📱 启动企业微信..."
docker exec -d wine_container /usr/bin/wxwork

echo "✅ 流程执行完毕！"
