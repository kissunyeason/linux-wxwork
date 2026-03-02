#!/bin/bash
# Fedora 43 适配增强版 - 由 kissunyeason 开发

APP_PATH=$(cd "$(dirname "$0")"; pwd)
YML_FILE="$APP_PATH/docker-compose.yml"

echo "🔍 正在进行系统环境检查..."

# 1. 检查关键依赖 xset (用于 X11 屏幕共享和窗口管理)
if ! command -v xset &> /dev/null; then
    echo "📦 正在安装缺失的 x11-utils (xset)..."
    sudo dnf install -y x11-utils
fi

# 2. 检查 Docker 引擎
if ! command -v docker &> /dev/null; then
    echo "🐳 未检测到 Docker，请先按照项目 README 手动安装 Docker 或配置代理。"
    exit 1
fi

# 3. 开放 X11 访问权限 (核心：解决窗口弹不出的问题)
echo "🔓 开放 X11 授权..."
xhost +local:docker > /dev/null

# 4. 启动或唤醒容器
if [ "$(docker inspect -f '{{.State.Running}}' wine_container 2>/dev/null)" != "true" ]; then
    echo "🚀 正在启动容器环境..."
    docker compose -f "$YML_FILE" up -d
    
    echo "⏳ 等待环境初始化 (5秒)..."
    sleep 5
    
    # 5. 注入 Fedora 43 专属 UI 补丁 (消除黑边 & 修复右键菜单)
    echo "🎨 正在应用 Wine UI 优化补丁..."
    docker exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Decorated' /t REG_SZ /d 'n' /f
    docker exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Compositing' /t REG_SZ /d 'y' /f
    docker exec wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'UseTakeFocus' /t REG_SZ /d 'n' /f
fi

# 6. 拉起企业微信进程
echo "📱 启动企业微信..."
docker exec -d wine_container /usr/bin/wxwork

echo "✅ 完成！如果窗口未弹出，请检查是否在 Wayland 下正确开启了 XWayland。"
