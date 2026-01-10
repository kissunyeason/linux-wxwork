#!/bin/bash

# 环境依赖安装脚本
# 功能：检查并安装必要的系统依赖

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/functions.bash"

# 需要安装的依赖列表
REQUIRED_PACKAGES=(
    "curl"
    "jq"
)

# 可选依赖（用于 Docker 环境管理）
OPTIONAL_PACKAGES=(
    "docker"
    "xhost"
    "xset"
)

# 安装单个包
install_package() {
    local pkg="$1"
    
    command -v "$pkg" >/dev/null 2>&1 && return 0
    
    log_info "正在安装: $pkg"
    [[ "${UPDATE_APT:-false}" == "true" ]] && sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends "$pkg" || {
        log_error "安装失败: $pkg"
        return 1
    }
    log_success "安装成功: $pkg"
}

# 检查 Docker
check_docker_installed() {
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        log_info "Docker 已安装并运行"
        return 0
    fi
    
    # Docker 安装比较复杂，这里只检查，不自动安装
    log_warning "Docker 未安装或未运行"
    return 1
}

# 主函数
main() {
    local check_only="${1:-}"
    
    log_info "检查环境依赖..."
    
    # 安装必需依赖
    local missing_required=()
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            missing_required+=("$pkg")
        fi
    done
    
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        if [[ "$check_only" == "--check" ]]; then
            log_error "缺少必需依赖: ${missing_required[*]}"
            exit 1
        fi
        
        log_info "安装必需依赖: ${missing_required[*]}"
        UPDATE_APT=true
        for pkg in "${missing_required[@]}"; do
            install_package "$pkg" || {
                log_error "必需依赖安装失败: $pkg"
                exit 1
            }
        done
    else
        log_success "所有必需依赖已安装"
    fi
    
    # 检查可选依赖（仅检查，不强制安装）
    for pkg in "${OPTIONAL_PACKAGES[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            if [[ "$pkg" == "docker" ]]; then
                check_docker_installed || log_warning "Docker 未安装，某些功能可能无法使用"
            else
                log_warning "可选依赖未安装: $pkg（某些功能可能无法使用）"
            fi
        fi
    done
    
    log_success "环境依赖检查完成"
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
