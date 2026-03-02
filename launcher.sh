#!/bin/bash
# Fedora 43 (DNF5) 终极适配版 - 彻底解决权限与依赖

APP_PATH=$(cd "$(dirname "$0")"; pwd)
YML_FILE="$APP_PATH/docker-compose.yml"

# 1. 强制权限判定：只要没权限，就全局启用 sudo
if ! docker ps >/dev/null 2>&1; then
    echo "🔐 检测到 Docker 权限不足，本轮将强制使用 sudo 执行..."
    DOCKER_CMD="sudo docker"
    DOCKER_COMPOSE_CMD="sudo docker compose"
else
    DOCKER_CMD="docker"
    DOCKER_COMPOSE_CMD="docker compose"
fi

echo "🔍 正在进行系统环境检查..."

# 2. 动态定位 xset (不猜包名，按文件找)
if ! command -v xset &> /dev/null; then
    echo "📦 正在通过文件路径安装 xset 依赖..."
    sudo dnf install -y /usr/bin/xset
fi

# 3. 开放 X11 授权
echo "🔓 开放 X11 授权..."
xhost +local:docker > /dev/null

# 4. 启动容器 (拉取 2GB 镜像)
echo "🚀 正在启动环境 (正在拉取镜像，请稍候)..."
$DOCKER_COMPOSE_CMD -f "$YML_FILE" up -d

# 5. 等待并注入补丁
echo "⏳ 等待环境初始化 (10秒)..."
sleep 10
echo "🎨 应用 UI 优化补丁..."
$DOCKER_CMD exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Decorated' /t REG_SZ /d 'n' /f
$DOCKER_CMD exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Compositing' /t REG_SZ /d 'y' /f

# 6. 启动微信
echo "📱 启动企业微信..."
$DOCKER_CMD exec -d wine_container /usr/bin/wxwork

echo "✅ 流程执行完毕！"
