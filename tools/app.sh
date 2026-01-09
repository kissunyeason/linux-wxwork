#!/bin/bash

# Deepin-Wine 应用管理脚本
# 功能：安装、卸载、搜索、列出应用

set -euo pipefail

# 获取脚本目录并加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"
MAPPING_FILE="${WS_DIR}/mapping.json"
SEARCH_URL="https://deepin-wine.i-m.dev/"

# 加载公共函数
source "${SCRIPT_DIR}/functions.bash"

# 确保依赖已安装
bash "${SCRIPT_DIR}/setup.sh" --check 2>/dev/null || bash "${SCRIPT_DIR}/setup.sh"

# ============================================================================
# 应用管理函数
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

}

# 在容器内安装应用
install_app_in_container() {
    local package="$1"
    local short_name="$2"
    
    log_info "在容器内安装应用: ${package}"
    
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

# 安装应用
install_app() {
    local package="$1"
    local short_name="$2"
    
    # 如果不在容器内，且容器正在运行，则在容器内安装
    if ! is_in_container && is_container_running; then
        install_app_in_container "$package" "$short_name"
        return $?
    fi
    
    log_info "开始安装应用: ${package}"
    
    # 检查是否已安装
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        log_warning "应用已安装: ${package}"
        return 0
    fi
    
    # 更新 apt 源
    log_info "更新软件包列表..."
    sudo apt update || {
        log_error "apt update 失败"
        return 1
    }
    
    # 安装应用
    log_info "正在安装 ${package}..."
    if sudo apt install -y "$package"; then
        log_success "应用安装成功: ${package}"
        
        # 创建 wrapper
        create_wrapper "$short_name" "$package" || log_warning "创建 wrapper 失败，但应用已安装"
        
        # 提示用户
        echo ""
        log_success "${package} 已安装，可通过以下命令启动:"
        echo -e "  ${GREEN}./tools/run.sh ${short_name}${NC}"
        if is_in_container; then
            echo -e "  或直接运行: ${GREEN}${short_name}${NC}"
        else
            echo -e "  或在容器内运行: ${GREEN}docker exec -it wine_container ${short_name}${NC}"
        fi
    else
        log_error "应用安装失败: ${package}"
        return 1
    fi
}

# 卸载应用
uninstall_app() {
    local package="$1"
    local short_name="$2"
    
    log_info "开始卸载应用: ${package}"
    
    # 检查是否已安装
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        log_warning "应用未安装: ${package}"
        return 0
    fi
    
    # 卸载应用
    if sudo apt remove -y "$package"; then
        log_success "应用卸载成功: ${package}"
        
        # 删除 wrapper（如果存在）
        if [[ -f "/usr/bin/${short_name}" ]]; then
            sudo rm -f "/usr/bin/${short_name}"
            log_success "已删除启动脚本: /usr/bin/${short_name}"
        fi
    else
        log_error "应用卸载失败: ${package}"
        return 1
    fi
}

# 搜索应用
search_app() {
    local keyword="$1"
    
    log_info "正在搜索包含 '${keyword}' 的应用..."
    
    ensure_command curl
    
    # 下载网页并解析
    local html_content=$(curl -s "$SEARCH_URL" || {
        log_error "无法访问搜索网站: $SEARCH_URL"
        return 1
    })
    
    # 解析 HTML 表格，提取包名、版本和描述
    echo -e "${BLUE}找到以下匹配的应用:${NC}"
    echo ""
    printf "%-45s %-20s %s\n" "包名" "版本" "描述"
    echo "--------------------------------------------------------------------------------------------------------"
    
    # 使用更简单的方法解析 HTML 表格
    # 表格格式: <tr>...<td><a>包名</a></td><td>版本</td><td>描述</td>...</tr>
    local count=0
    local temp_file=$(mktemp)
    
    # 提取所有包含关键词的包名（从链接中）
    echo "$html_content" | grep -i "$keyword" | grep -oP '<a[^>]*href="[^"]*">([^<]+)</a>' | \
    sed 's/<a[^>]*>\([^<]*\)<\/a>/\1/' | sort -u | head -30 > "$temp_file"
    
    # 对每个包名，提取版本和描述
    while IFS= read -r pkg; do
        if [[ -z "$pkg" ]]; then
            continue
        fi
        
        # 找到包含这个包名的行
        local pkg_line=$(echo "$html_content" | grep -i "$pkg" | grep -oP '<td><a[^>]*>([^<]+)</a></td>' | head -1)
        if [[ -z "$pkg_line" ]]; then
            continue
        fi
        
        # 提取包名所在的行号范围
        local line_num=$(echo "$html_content" | grep -n "$pkg" | grep '<td><a' | head -1 | cut -d: -f1)
        if [[ -z "$line_num" ]]; then
            continue
        fi
        
        # 提取版本（下一行的 <td>）
        local version=$(echo "$html_content" | sed -n "${line_num},+2p" | grep '<td>' | sed -n '2p' | sed 's/<td[^>]*>\([^<]*\)<\/td>/\1/' | sed 's/^[ \t]*//;s/[ \t]*$//')
        
        # 提取描述（再下一行的 <td>）
        local desc=$(echo "$html_content" | sed -n "${line_num},+3p" | grep '<td>' | sed -n '3p' | sed 's/<td[^>]*>\([^<]*\)<\/td>/\1/' | sed 's/^[ \t]*//;s/[ \t]*$//')
        
        # 清理 HTML 实体和多余空格
        version=$(echo "$version" | sed 's/&nbsp;/ /g' | sed 's/[ \t]\+/ /g' | sed 's/^[ \t]*//;s/[ \t]*$//')
        desc=$(echo "$desc" | sed 's/&nbsp;/ /g' | sed 's/[ \t]\+/ /g' | sed 's/^[ \t]*//;s/[ \t]*$//')
        
        # 限制描述长度，避免过长
        local desc_short="${desc:0:60}"
        [[ ${#desc} -gt 60 ]] && desc_short="${desc_short}..."
        
        printf "%-45s %-20s %s\n" "$pkg" "${version:-N/A}" "$desc_short"
        count=$((count + 1))
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    echo ""
    if [[ $count -gt 0 ]]; then
        log_info "找到 $count 个匹配的应用"
        log_info "使用以下命令安装: ./tools/app.sh install <包名>"
    else
        log_warning "未找到匹配的应用，请尝试其他关键词"
    fi
}

# 列出 Top 100 应用
list_apps() {
    log_info "Deepin-Wine 热门应用 Top 100:"
    echo ""
    printf "%-20s %-45s %s\n" "简短名称" "完整包名" "描述"
    echo "--------------------------------------------------------------------------------------------------------"
    
    read_mapping | while IFS='|' read -r short_name package description; do
        # 限制描述长度
        local desc_short="${description:0:50}"
        [[ ${#description} -gt 50 ]] && desc_short="${desc_short}..."
        printf "%-20s %-45s %s\n" "$short_name" "$package" "${desc_short:-N/A}"
    done
    
    echo ""
    log_info "使用以下命令安装: ./tools/app.sh install <包名>"
    log_info "或使用简短名称: ./tools/run.sh <简短名称> (会自动安装)"
}

# 显示帮助信息
show_help() {
    log_info "Deepin-Wine 应用管理工具"
    echo ""
    echo "用法:"
    echo "    ./tools/app.sh <command> [arguments]"
    echo ""
    echo "命令:"
    echo "    install <package> [short_name]  安装应用包"
    echo "        - package: 完整包名（如 com.qq.weixin.work.deepin）"
    echo "        - short_name: 可选，简短名称（如 wxwork），如果不提供会提示输入"
    echo ""
    echo "    uninstall <package|short_name>  卸载应用"
    echo "        - 可以使用完整包名或简短名称"
    echo ""
    echo "    search <keyword>                搜索应用"
    echo "        - 从 https://deepin-wine.i-m.dev/ 搜索匹配的应用"
    echo ""
    echo "    list                             列出 Top 100 热门应用"
    echo ""
    echo "    help                             显示此帮助信息"
    echo ""
    echo "示例:"
    echo "    ./tools/app.sh install com.qq.weixin.work.deepin wxwork"
    echo "    ./tools/app.sh install com.qq.weixin.work.deepin"
    echo "    ./tools/app.sh uninstall wxwork"
    echo "    ./tools/app.sh search wechat"
    echo "    ./tools/app.sh list"
}

# 主函数
main() {
    local command="${1:-help}"
    
    case "$command" in
        install)
            if [[ $# -lt 2 ]]; then
                log_error "请提供要安装的包名"
                show_help
                exit 1
            fi
            
            local package="$2"
            local short_name="${3:-}"
            
            # 如果没有提供简短名称，尝试从映射表查找
            if [[ -z "$short_name" ]]; then
                short_name=$(find_short_name_by_package "$package")
            fi
            
            # 如果映射表中没有，提示用户输入
            if [[ -z "$short_name" ]]; then
                log_info "映射表中未找到该应用的简短名称"
                read -p "请输入简短名称（用于启动命令，如 wxwork）: " short_name
                if [[ -z "$short_name" ]]; then
                    log_error "简短名称不能为空"
                    exit 1
                fi
                
                # 可选：提示输入描述
                read -p "请输入应用描述（可选，直接回车跳过）: " description
                
                # 添加到映射表
                add_mapping "$short_name" "$package" "$description"
            fi
            
            install_app "$package" "$short_name"
            ;;
            
        uninstall)
            if [[ $# -lt 2 ]]; then
                log_error "请提供要卸载的包名或简短名称"
                show_help
                exit 1
            fi
            
            local input="$2"
            local package
            local short_name
            
            # 判断是简短名称还是完整包名
            if [[ "$input" == *.* ]]; then
                # 看起来是完整包名
                package="$input"
                short_name=$(find_short_name_by_package "$package")
            else
                # 简短名称
                short_name="$input"
                package=$(find_package_by_short_name "$short_name")
            fi
            
            if [[ -z "$package" ]]; then
                log_error "未找到对应的应用包: $input"
                exit 1
            fi
            
            uninstall_app "$package" "$short_name"
            ;;
            
        search)
            if [[ $# -lt 2 ]]; then
                log_error "请提供搜索关键词"
                show_help
                exit 1
            fi
            search_app "$2"
            ;;
            
        list)
            list_apps
            ;;
            
        help|--help|-h)
            show_help
            ;;
            
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
