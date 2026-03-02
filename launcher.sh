#!/bin/bash
APP_PATH=$(cd "$(dirname "$0")"; pwd)
DESKTOP_FILE="$HOME/.local/share/applications/wechat-work.desktop"
YML_FILE="$APP_PATH/docker-compose.yml"

# 1. 生成系统图标
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "🖼️  正在安装 Fedora 桌面图标..."
    cat <<D_EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=企业微信 (Docker)
Name[zh_CN]=企业微信 (Docker)
Comment=WXWork on Fedora 43
Exec=${APP_PATH}/launcher.sh
Icon=system-run
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
D_EOF
    chmod +x "$DESKTOP_FILE"
fi

# 2. 启动逻辑
xhost +local:docker > /dev/null
if [ "$(docker inspect -f '{{.State.Running}}' wine_container 2>/dev/null)" != "true" ]; then
    echo "🚀 正在首次启动容器..."
    docker compose -f "$YML_FILE" up -d
else
    echo "⚡ 正在唤醒企业微信..."
    docker exec -d wine_container /usr/bin/wxwork
fi
