#!/bin/bash
APP_PATH=$(cd "$(dirname "$0")"; pwd)
DESKTOP_FILE="$HOME/.local/share/applications/wechat-work.desktop"
YML_FILE="$APP_PATH/docker-compose.yml"

# 1. 检查并自动安装 Docker (针对 Fedora)
if ! command -v docker &> /dev/null; then
    echo "🔍 检测到未安装 Docker，正在为您安装..."
    sudo dnf -y install dnf-plugins-core
    sudo dnf-config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    echo "✅ Docker 安装完成！"
    echo "⚠️ 请注意：由于用户组变更，您可能需要【注销并重新登录】系统，才能免 sudo 运行 Docker。"
    echo "您可以尝试先执行 'newgrp docker' 来立即生效当前终端。"
fi

# 2. 生成系统图标
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

# 3. 启动逻辑
xhost +local:docker > /dev/null
if [ "$(docker inspect -f '{{.State.Running}}' wine_container 2>/dev/null)" != "true" ]; then
    echo "🚀 正在拉取环境并启动容器（首次运行需下载 2GB+ 数据，请耐心等待）..."
    docker compose -f "$YML_FILE" up -d
else
    echo "⚡ 正在唤醒企业微信..."
    docker exec -d wine_container /usr/bin/wxwork
fi
