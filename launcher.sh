#!/bin/bash

# 1. 获取当前脚本所在绝对路径
APP_PATH=$(cd "$(dirname "$0")"; pwd)
YML_FILE="$APP_PATH/docker-compose.yml"
DOCKER_CMD="sudo docker"
DOCKER_COMPOSE_CMD="sudo docker compose"

echo "🔍 正在检查 Fedora 43 环境依赖..."
# 针对 DNF5 的 X11 授权补丁
if ! command -v xset &> /dev/null; then
    sudo dnf install -y /usr/bin/xset
fi
xhost +local:docker &> /dev/null

# 2. 权限预修复 (防止 root 锁死注册表)
if [ -d "$APP_PATH/wine-home" ]; then
    echo "🛡️  正在修复文件权限..."
    sudo chown -R $USER:$USER "$APP_PATH/wine-home"
fi

# 3. 启动容器
echo "🚀 正在启动容器..."
$DOCKER_COMPOSE_CMD -f "$YML_FILE" up -d

# 4. 注入 UI 优化补丁 (去黑边核心)
echo "🎨 正在注入 UI 优化补丁 (去黑边)..."
# 必须带 LC_ALL=C 并在启动微信前执行
$DOCKER_CMD exec -e LC_ALL=C wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Decorated' /t REG_SZ /d 'n' /f
$DOCKER_CMD exec -e LC_ALL=C wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Compositing' /t REG_SZ /d 'y' /f

# 5. 启动企业微信并强制注入 IBus 变量
echo "📱 正在启动企业微信..."
sleep 2
$DOCKER_CMD exec -d \
    -e XMODIFIERS="@im=ibus" \
    -e GTK_IM_MODULE="ibus" \
    -e QT_IM_MODULE="ibus" \
    wine_container /usr/bin/wxwork

echo "✨ 启动完成！"
echo "💡 提示：如果无法输入中文，请在微信窗口按 Super(Win)+Space 切换输入法。"
