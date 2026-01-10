#!/bin/bash

# Deepin-Wine 应用统一运行脚本
# 功能：运行指定应用，如果未安装则自动安装

set -euo pipefail

# 获取脚本目录并加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"
MAPPING_FILE="${WS_DIR}/mapping.json"
APP_SCRIPT="${SCRIPT_DIR}/lib/app.sh"
CONTAINER_NAME="wine_container"

# 加载公共函数
source "${SCRIPT_DIR}/lib/functions.bash"

# 确保依赖已安装
bash "${SCRIPT_DIR}/lib/setup.sh" --check 2>/dev/null || bash "${SCRIPT_DIR}/lib/setup.sh"

# ============================================================================
# 容器管理函数
# ============================================================================

# 停止容器
stop_container() {
    log_info "正在停止容器: ${CONTAINER_NAME}"
    
    if ! is_container_running; then
        log_warning "容器未运行: ${CONTAINER_NAME}"
        return 0
    fi
    
    if docker stop "$CONTAINER_NAME" >/dev/null 2>&1; then
        log_success "容器已停止: ${CONTAINER_NAME}"
        return 0
    else
        log_error "停止容器失败: ${CONTAINER_NAME}"
        return 1
    fi
}

# 删除容器和镜像
remove_container_and_image() {
    log_info "正在删除容器和镜像..."
    
    # 获取镜像名称和标签
    local image_name="${IMAGE_NAME:-zwhy2025/wine-docker}"
    local tag="${TAG:-base}"
    local full_image="${image_name}:${tag}"
    
    # 停止并删除容器
    if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        log_info "删除容器: ${CONTAINER_NAME}"
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || {
            log_error "删除容器失败: ${CONTAINER_NAME}"
            return 1
        }
        log_success "容器已删除: ${CONTAINER_NAME}"
    else
        log_warning "容器不存在: ${CONTAINER_NAME}"
    fi
    
    # 删除镜像
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${full_image}$" 2>/dev/null; then
        log_info "删除镜像: ${full_image}"
        docker rmi -f "$full_image" >/dev/null 2>&1 || {
            log_error "删除镜像失败: ${full_image}"
            return 1
        }
        log_success "镜像已删除: ${full_image}"
    else
        log_warning "镜像不存在: ${full_image}"
    fi
    
    log_success "容器和镜像清理完成"
}

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
    docker exec "$CONTAINER_NAME" bash /workspace/tools/lib/app.sh install "$package" "$short_name" || {
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
    echo "    ./tools/run.sh <command> [options]"
    echo ""
    echo "命令:"
    echo "    <app_name>           运行指定应用（如果未安装则自动安装）"
    echo "    stop                 停止容器"
    echo "    stop --clear|-c       停止并删除容器和镜像"
    echo ""
    echo "运行应用示例:"
    echo "    ./tools/run.sh wxwork         运行企业微信"
    echo "    ./tools/run.sh wechat         运行微信"
    echo "    ./tools/run.sh netease        运行网易云音乐"
    echo ""
    echo "容器管理示例:"
    echo "    ./tools/run.sh stop           停止容器"
    echo "    ./tools/run.sh stop --clear/-c 停止并删除容器和镜像"
    echo ""
    echo "应用管理命令:"
    echo "    ./tools/run.sh list           查看所有可用应用"
    echo "    ./tools/run.sh search <关键词> 搜索应用"
    echo "    ./tools/run.sh install <包名> [简短名称] 安装应用"
    echo "    ./tools/run.sh uninstall <包名|简短名称> 卸载应用"
    echo ""
    log_info "如果应用未安装，运行时会自动安装"
}

# 主函数
main() {
    local command="${1:-}"
    
    # 如果没有提供命令，显示帮助
    if [[ -z "$command" ]]; then
        show_help
        exit 0
    fi
    
    # 处理 stop 命令
    if [[ "$command" == "stop" ]]; then
        local option="${2:-}"
        
        # 检查是否在容器内运行（不支持）
        if is_in_container; then
            log_error "此脚本不支持在容器内运行"
            exit 1
        fi
        
        if [[ "$option" == "--clear" ]] || [[ "$option" == "-c" ]]; then
            remove_container_and_image
        else
            stop_container
        fi
        exit $?
    fi
    
    # 处理 help 命令
    if [[ "$command" == "help" ]] || [[ "$command" == "--help" ]] || [[ "$command" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # 转发应用管理命令到 app.sh
    if [[ "$command" == "list" ]] || [[ "$command" == "search" ]] || [[ "$command" == "install" ]] || [[ "$command" == "uninstall" ]]; then
        # 检查是否在容器内运行（不支持）
        if is_in_container; then
            log_error "此脚本不支持在容器内运行"
            exit 1
        fi
        
        # 设置环境变量标记，允许 app.sh 运行
        export RUN_SH_CALLED=1
        # 转发命令和参数到 app.sh
        bash "${APP_SCRIPT}" "$@"
        exit $?
    fi
    
    # 否则，将命令视为应用名称
    local app_name="$command"
    
    # 查找完整包名
    local package=$(find_package_by_short_name "$app_name")
    
    if [[ -z "$package" ]]; then
        log_error "未找到应用: $app_name"
        log_info "使用 './tools/run.sh list' 查看可用应用列表"
        log_info "使用 './tools/run.sh search <关键词>' 搜索应用"
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
