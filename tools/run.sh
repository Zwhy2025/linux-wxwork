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
    local version="${3:-}"
    
    log_info "应用未安装，开始自动安装..."
    
    # 确保 Wine 环境已安装
    install_wine_environment || return 1
    
    # 更新 apt 包列表
    log_info "更新软件包列表..."
    docker exec "$CONTAINER_NAME" apt update >/dev/null 2>&1 || log_warning "apt update 失败，继续尝试安装"
    
    # 构建安装命令参数
    local install_args=("bash" "/workspace/tools/lib/app.sh" "install" "$package" "$short_name")
    if [[ -n "$version" ]]; then
        install_args+=("-v" "$version")
    fi
    
    # 直接使用 volume 挂载的脚本
    docker exec "$CONTAINER_NAME" "${install_args[@]}" || {
        log_error "应用安装失败"
        return 1
    }
}

# 在容器内升级已安装应用到源中最新版本（保留用户数据与配置）
upgrade_app_in_container() {
    local package="$1"
    log_info "正在升级应用: ${package}"
    # 普通 apt install 允许同时安装新依赖（如 v5 所需的 wine10/deepin-elf-verify），
    # --only-upgrade 会因拒绝新依赖导致升级失败，故不使用；
    # 镜像中 ubuntu 源路径 403 会阻断依赖安装，先修复源再 update/install
    fix_apt_sources_in_container
    docker exec "$CONTAINER_NAME" bash -c "export DEBIAN_FRONTEND=noninteractive && apt-get update -qq || true; apt-get install -y '$package'" || {
        log_error "应用升级失败"
        return 1
    }
    local installed_version
    installed_version=$(docker exec "$CONTAINER_NAME" dpkg-query -W -f='${Version}' "$package" 2>/dev/null)
    log_success "应用已升级: ${package} (版本: ${installed_version})"
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
    echo "    ./tools/run.sh wxwork -v v4   运行企业微信（如果未安装则安装 v4 版本）"
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
    echo "    ./tools/run.sh install <包名> [简短名称] [-v|--version <版本>] 安装应用"
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
    local version=""
    
    # 解析版本参数（-v 或 --version）
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)
                if [[ -z "${2:-}" ]]; then
                    log_error "-v/--version 参数需要指定版本号"
                    show_help
                    exit 1
                fi
                version="$2"
                shift 2
                ;;
            *)
                # 其他参数忽略（可能是应用运行时的参数）
                shift
                ;;
        esac
    done
    
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
        install_app_in_container "$package" "$app_name" "$version"
    elif [[ -n "$version" ]]; then
        # 已安装时 -v 不生效：升级请直接运行（不带 -v），脚本会检测新版本并提示确认
        log_info "应用已安装，-v 参数仅用于未安装时的初始版本选择；升级请直接运行 ${app_name}，检测到新版本时会提示确认"
    elif [[ -z "$version" ]] && app_has_update_in_container "$package"; then
        # 已安装旧版且未指定版本：询问用户是否升级（例如企业微信 v4 → v5）
        log_info "检测到 ${app_name} 在源中有新版本"
        local installed_version
        installed_version=$(docker exec "$CONTAINER_NAME" dpkg-query -W -f='${Version}' "$package" 2>/dev/null)
        read -rp "是否升级 ${app_name} 到源中的最新版本 (当前 ${installed_version})? [y/N]: " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            upgrade_app_in_container "$package" || log_warning "应用升级失败，继续使用现有版本运行"
        else
            log_info "已跳过升级，继续使用当前版本运行"
        fi
    fi
    
    # 运行应用
    run_app "$app_name"
}

# 执行主函数
main "$@"
