#!/bin/bash
# Fedora 43 (DNF5) 适配版 - 纯净逻辑版

APP_PATH=$(cd "$(dirname "$0")"; pwd)
YML_FILE="$APP_PATH/docker-compose.yml"

# 1. 权限判定：只要没权限，就全局启用 sudo
if ! docker ps >/dev/null 2>&1; then
    echo "🔐 检测到 Docker 权限不足，本轮将使用 sudo 执行..."
    DOCKER_CMD="sudo docker"
    DOCKER_COMPOSE_CMD="sudo docker compose"
else
    DOCKER_CMD="docker"
    DOCKER_COMPOSE_CMD="docker compose"
fi

echo "🔍 正在检查系统环境..."

# 2. 动态定位 xset (按文件找，不猜包名)
if ! command -v xset &> /dev/null; then
    echo "📦 正在安装运行时依赖..."
    sudo dnf install -y /usr/bin/xset
fi

# 3. 开放 X11 授权
xhost +local:docker > /dev/null

# 4. 启动容器 (请确保您的 Docker Daemon 已配置好网络环境)
echo "🚀 正在拉取镜像并启动环境..."
$DOCKER_COMPOSE_CMD -f "$YML_FILE" up -d

# 5. UI 优化补丁
echo "⏳ 等待初始化..."
sleep 10
echo "🎨 消除窗口黑边..."
$DOCKER_CMD exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Decorated' /t REG_SZ /d 'n' /f
$DOCKER_CMD exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Compositing' /t REG_SZ /d 'y' /f

echo "📱 启动企业微信..."
$DOCKER_CMD exec -d wine_container /usr/bin/wxwork
echo "✅ 流程执行完毕！"
