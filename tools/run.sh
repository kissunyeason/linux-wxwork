#!/bin/bash

# Deepin-Wine 应用统一运行脚本
# 功能：运行指定应用，如果未安装则自动安装

set -euo pipefail

# 获取脚本目录并加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"
MAPPING_FILE="${WS_DIR}/mapping.json"
APP_SCRIPT="${SCRIPT_DIR}/app.sh"
CONTAINER_NAME="wine_container"

# 加载公共函数
source "${SCRIPT_DIR}/functions.bash"

# 确保依赖已安装
bash "${SCRIPT_DIR}/setup.sh" --check 2>/dev/null || bash "${SCRIPT_DIR}/setup.sh"

# ============================================================================
# 应用安装和运行函数
# ============================================================================

# 在容器内安装 Wine 环境
install_wine_environment() {
    # 检查并配置 Deepin-Wine 软件源（如果未配置）
    if ! docker exec "$CONTAINER_NAME" test -f /etc/apt/sources.list.d/deepin-wine.i-m.dev.list 2>/dev/null; then
        log_info "配置 Deepin-Wine 软件源..."
        docker exec "$CONTAINER_NAME" bash -c "wget -O- https://deepin-wine.i-m.dev/setup.sh | sh" || {
            log_error "Deepin-Wine 软件源配置失败"
            return 1
        }
    fi
    
    # 检查 Wine 是否已安装
    if docker exec "$CONTAINER_NAME" command -v wine >/dev/null 2>&1; then
        return 0
    fi
    
    log_info "安装 Wine 环境..."
    docker exec "$CONTAINER_NAME" bash -c "export DEBIAN_FRONTEND=noninteractive && apt update && apt install -y deepin-wine10-stable deepin-wine-helper" || {
        log_error "Wine 环境安装失败"
        return 1
    }
    
    # 安装 Spark Store 补丁包
    log_info "安装 Spark Store 补丁包..."
    docker exec "$CONTAINER_NAME" bash -c "wget -q https://gitcode.com/spark-store-project/spark-store/releases/download/4.8.3/spark-store_4.8.3_amd64.deb -O /tmp/spark-store.deb && apt install -y /tmp/spark-store.deb && rm -f /tmp/spark-store.deb" || {
        log_warning "Spark Store 补丁包安装失败，继续..."
    }
}

# 在容器内安装应用
install_app_in_container() {
    local package="$1"
    local short_name="$2"
    
    log_info "应用未安装，开始自动安装..."
    
    # 确保 Wine 环境已安装
    install_wine_environment || return 1
    
    # 更新 apt 包列表
    log_info "更新软件包列表..."
    docker exec "$CONTAINER_NAME" apt update >/dev/null 2>&1 || log_warning "apt update 失败，继续尝试安装"
    
    # 直接使用 volume 挂载的脚本
    docker exec "$CONTAINER_NAME" bash /workspace/tools/app.sh install "$package" "$short_name" || {
        log_error "应用安装失败"
        return 1
    }
}

# 在容器内运行应用
run_app() {
    local short_name="$1"
    
    log_info "在容器内运行应用: ${short_name}"
    
    # 直接运行 wrapper，如果不存在则报错（不应该发生，因为安装时会创建）
    if check_wrapper_exists "$short_name"; then
        docker exec "$CONTAINER_NAME" bash -c "nohup $short_name > /dev/null 2>&1 &" || \
        docker exec -it "$CONTAINER_NAME" "$short_name"
    else
        log_error "启动脚本不存在，请先安装应用"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    log_info "Deepin-Wine 应用运行工具"
    echo ""
    echo "用法:"
    echo "    ./tools/run.sh <app_name>"
    echo ""
    echo "参数:"
    echo "    app_name    应用的简短名称（如 wxwork, wechat）"
    echo ""
    echo "示例:"
    echo "    ./tools/run.sh wxwork         运行企业微信"
    echo "    ./tools/run.sh wechat         运行微信"
    echo "    ./tools/run.sh netease        运行网易云音乐"
    echo ""
    echo "可用应用列表:"
    
    # 显示映射表中的应用
    if [[ -f "$MAPPING_FILE" ]] && command -v jq >/dev/null 2>&1; then
        echo ""
        printf "%-20s %-45s %s\n" "简短名称" "完整包名" "描述"
        echo "--------------------------------------------------------------------------------------------------------"
        read_mapping | while IFS='|' read -r short_name package description; do
            local desc_short="${description:0:50}"
            [[ ${#description} -gt 50 ]] && desc_short="${desc_short}..."
            printf "%-20s %-45s %s\n" "$short_name" "$package" "${desc_short:-N/A}"
        done
    else
        echo "  （无法读取应用列表）"
    fi
    
    echo ""
    log_info "如果应用未安装，会自动调用 ./tools/app.sh install 进行安装"
    log_info "查看所有应用: ./tools/app.sh list"
    log_info "搜索应用: ./tools/app.sh search <关键词>"
}

# 主函数
main() {
    local app_name="${1:-}"
    
    # 如果没有提供应用名称，显示帮助
    if [[ -z "$app_name" ]]; then
        show_help
        exit 0
    fi
    
    # 查找完整包名
    local package=$(find_package_by_short_name "$app_name")
    
    if [[ -z "$package" ]]; then
        log_error "未找到应用: $app_name"
        log_info "使用 './tools/app.sh list' 查看可用应用列表"
        log_info "使用 './tools/app.sh search <关键词>' 搜索应用"
        exit 1
    fi
    
    log_info "找到应用: ${app_name} -> ${package}"
    
    # 检查是否在容器内运行（不支持）
    if is_in_container; then
        log_error "此脚本不支持在容器内运行"
        log_info "请在主机上运行此脚本，它会自动在容器内执行应用"
        log_info "如果需要在容器内运行应用，请直接使用: ${app_name}"
        exit 1
    fi
    
    # 确保容器运行
    if ! is_container_running; then
        # 容器未运行 - 自动初始化 Docker 环境
        log_info "容器未运行，自动初始化 Docker 环境..."
        ensure_docker_environment
        
        # 设置 X11 权限
        xhost +local:docker >/dev/null 2>&1 || log_warning "X11权限设置失败"
    else
        log_info "容器正在运行，将在容器内执行应用"
    fi
    
    # 检查容器内是否已安装
    if ! check_app_installed_in_container "$package"; then
        install_app_in_container "$package" "$app_name"
    fi
    
    # 运行应用
    run_app "$app_name"
}

# 执行主函数
main "$@"
