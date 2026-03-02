#!/bin/bash
APP_PATH=$(cd "$(dirname "$0")"; pwd)
YML_FILE="$APP_PATH/docker-compose.yml"

# 权限预修复
if [ -d "./wine-home" ]; then
    sudo chown -R $USER:$USER ./wine-home
fi

# 启动容器
docker compose -f "$YML_FILE" up -d

echo "🎨 注入 UI 优化补丁..."
# 核心：必须在启动微信前注入，且指定编码
docker exec -e LC_ALL=C wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Decorated' /t REG_SZ /d 'n' /f
docker exec -e LC_ALL=C wine_container /usr/bin/deepin-wine8-stable reg add 'HKEY_CURRENT_USER\Software\Wine\X11 Driver' /v 'Compositing' /t REG_SZ /d 'y' /f

sleep 2
echo "📱 启动企业微信..."
docker exec -d wine_container /usr/bin/wxwork
