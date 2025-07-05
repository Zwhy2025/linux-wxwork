#!/bin/bash

# Wine Docker 智能运行脚本
# 功能：智能检测并执行 配置环境 → 构建镜像 → 启动容器
# 特点：已完成的步骤自动跳过

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"

# ============================================================================
# 通用函数库
# ============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'  

log_info() {
    echo -e "${BLUE}ℹ️  [INFO] $(date +'%Y-%m-%d %H:%M:%S')${NC} - $*"
}

log_success() {
    echo -e "${GREEN}✅ [SUCCESS] $(date +'%Y-%m-%d %H:%M:%S')${NC} - $*"
}

log_warning() {
    echo -e "${YELLOW}⚠️ [WARNING] $(date +'%Y-%m-%d %H:%M:%S')${NC} - $*"
}

log_error() {
    echo -e "${RED}❌ [ERROR] $(date +'%Y-%m-%d %H:%M:%S')${NC} - $*" >&2
    exit 1
}

set_error_handling() {
    set -euo pipefail
}

ensure_commands() {
    local missing_cmds=()
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [ ${#missing_cmds[@]} -gt 0 ]; then
        log_error "缺少以下命令：${missing_cmds[*]}，请先安装它们。"
    fi
}

install_apt_packages() {
    local packages_to_install=()
    
    sudo apt update

    if [ $# -eq 0 ]; then
        log_error "未提供任何要安装的包。"
        return 1
    fi

    for pkg_version in "$@"; do
        local pkg="${pkg_version%%=*}"
        local version_prefix="${pkg_version#*=}"

        # 如果没有指定版本，只检查是否已安装
        if [[ "$pkg" == "$version_prefix" ]]; then
            # 没有指定版本，只检查是否已安装
            if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                log_info "已安装 ${pkg}"
            else
                log_info "包 ${pkg} 未安装，将添加到安装列表"
                packages_to_install+=("$pkg")
            fi
        else
            # 指定了版本，检查版本是否匹配
            local installed_version=""
            if installed_version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null); then
                if [[ "$installed_version" == "$version_prefix"* ]]; then
                    log_info "已安装 ${pkg} 版本 ${installed_version}"
                else
                    log_info "已安装 ${pkg} 版本 ${installed_version}，但需要版本 ${version_prefix}"
                    packages_to_install+=("$pkg_version")
                fi
            else
                log_info "包 ${pkg} 未安装，将添加到安装列表"
                packages_to_install+=("$pkg_version")
            fi
        fi
    done

    if [ ${#packages_to_install[@]} -eq 0 ]; then
        log_success "所有包已安装，无需更新。"
        return 0
    fi

    log_info "需要安装: ${packages_to_install[*]}"
    sudo apt install -y --no-install-recommends "${packages_to_install[@]}" || {
        log_error "包安装失败"
        return 1
    }

    log_success "包安装完成。"
}

backup_config() {
    local config_file="$1"
    local backup_dir="$2"
    
    if [[ -f "$config_file" ]]; then
        mkdir -p "$backup_dir"
        local backup_file="${backup_dir}/daemon.json.$(date +%Y%m%d_%H%M%S).bak"
        cp "$config_file" "$backup_file"
        log_info "已备份现有配置到: $backup_file"
    else
        log_info "配置文件不存在，跳过备份"
    fi
}

# ============================================================================
# 智能检测函数
# ============================================================================

# 检测Docker环境是否已配置
is_docker_configured() {
    local config_file="/etc/docker/daemon.json"
    
    if [[ -f "$config_file" ]]; then
        if grep -q "registry-mirrors" "$config_file" 2>/dev/null; then
            return 0  # 已配置
        fi
    fi
    return 1  # 未配置
}

# 检测Docker镜像是否已存在
is_image_built() {
    local image_name="zwhy2025/wine-docker:base"
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "^${image_name}$"; then
        # 进一步检查镜像是否完整
        if docker inspect "$image_name" >/dev/null 2>&1; then
            return 0  # 镜像已存在且完整
        else
            log_warning "镜像存在但可能损坏，将重新构建"
            return 1  # 镜像损坏
        fi
    fi
    return 1  # 镜像不存在
}

# 检测容器状态
check_container_status() {
    local container_name="wine_container"
    if docker ps -a --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "not_exists"
    fi
}

# ============================================================================
# Docker 环境配置
# ============================================================================

DOCKER_CONFIG_DIR="/etc/docker"
DOCKER_CONFIG_FILE="${DOCKER_CONFIG_DIR}/daemon.json"
BACKUP_DIR="${DOCKER_CONFIG_DIR}/backups"
REGISTRY_MIRRORS=(
    "https://docker.1panel.live"
    "https://docker.1ms.run"
    "https://docker.mybacc.com"
    "https://dytt.online"
    "https://lispy.org"
    "https://docker.xiaogenban1993.com"
    "https://docker.yomansunter.com"
    "https://aicarbon.xyz"
    "https://666860.xyz"
    "https://a.ussh.net"
    "https://hub.littlediary.cn"
    "https://hub.rat.dev"
    "https://docker.m.daocloud.io"
)

setup_docker_environment() {
    log_info "开始配置Docker环境..."

    # 检查root权限
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "Docker配置需要 root 权限，请使用 sudo 运行此脚本"
    fi

    # 安装必要工具
    install_apt_packages jq

    # 检查必要工具
    ensure_commands docker jq

    # 备份现有配置
    backup_config "${DOCKER_CONFIG_FILE}" "${BACKUP_DIR}"

    # 生成新配置
    generate_docker_config

    # 重启Docker服务
    restart_docker_service

    log_success "Docker环境配置完成"
}

generate_docker_config() {
    log_info "生成新的Docker配置..."

    # 创建配置目录
    mkdir -p "${DOCKER_CONFIG_DIR}" || {
        log_error "无法创建Docker配置目录"
        exit 1
    }

    # 生成JSON配置
    local temp_file=$(mktemp)
    cat > "${temp_file}" <<EOF
{
  "registry-mirrors": $(printf '%s\n' "${REGISTRY_MIRRORS[@]}" | jq -R . | jq -s .),
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "args": [],
      "path": "nvidia-container-runtime"
    }
  }
}
EOF

    # 验证并应用配置
    if jq empty "${temp_file}" &> /dev/null; then
        mv "${temp_file}" "${DOCKER_CONFIG_FILE}" || {
            log_error "无法写入Docker配置文件"
            exit 1
        }
        chmod 705 "${DOCKER_CONFIG_FILE}"
        log_info "Docker配置已更新"
    else
        log_error "生成的JSON配置无效"
        rm -f "${temp_file}"
        exit 1
    fi
}

restart_docker_service() {
    log_info "重新加载并重启Docker服务..."
    systemctl daemon-reload || {
        log_warning "systemctl daemon-reload失败"
    }
    
    systemctl restart docker || {
        log_error "无法重启Docker服务"
        exit 1
    }
    
    log_info "Docker服务已重启"
}

# ============================================================================
# Docker 镜像构建
# ============================================================================

IMAGE_NAME="zwhy2025/wine-docker"
TAG="base"
PLATFORM="linux/amd64"
check_docker() {
    log_info "检查 Docker 环境"
    
    ensure_commands "curl"

    # 检查 docker 是否已安装
    if ! command -v docker >/dev/null 2>&1; then
        log_warning "Docker 未安装，尝试通过镜像源安装"

        # 第一步：尝试使用阿里云镜像安装
        if curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh --mirror=Aliyun; then
            log_info "通过阿里云镜像安装 Docker 成功"
        else
            log_warning "镜像源安装失败，尝试使用官方源安装"
            
            # 第二步：尝试使用官方安装脚本
            if curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh; then
                log_info "通过官方脚本安装 Docker 成功"
            else
                log_error "Docker 安装失败，请手动安装"
                exit 1
            fi
        fi
    fi

    # 确保 Docker 服务正常
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 安装后仍无法使用，请检查服务是否已启动"
        exit 1
    fi

    log_success "Docker 环境检查通过"
}


setup_buildx() {
    log_info "配置 Docker Buildx 环境"
    
    if ! docker buildx ls | grep -q "default"; then
        log_info "创建默认 Buildx 环境"
        docker buildx create --use --name default
        log_success "Buildx 环境创建完成"
    else
        log_info "使用现有的 Buildx 环境"
    fi
}

build_docker_image() {
    local docker_dir="${WS_DIR}"
    
    log_info "开始构建 Docker 镜像"
    log_info "镜像名称: ${IMAGE_NAME}:${TAG}"
    log_info "构建平台: ${PLATFORM}"
    log_info "构建目录: ${docker_dir}"
    
    # 切换到 docker 目录
    cd "$docker_dir" || log_error "无法切换到 docker 目录: $docker_dir"
    
    # 构建镜像
    if docker buildx build --platform "$PLATFORM" -t "${IMAGE_NAME}:${TAG}" --load .; then
        log_success "Docker 镜像构建成功: ${IMAGE_NAME}:${TAG}"
    else
        log_error "Docker 镜像构建失败"
    fi
}

# ============================================================================
# 容器管理
# ============================================================================

CONTAINER_NAME="wine_container"

setup_x11_forwarding() {
    log_info "配置 X11 转发"

    # 检查DISPLAY环境变量
    if [[ -z "${DISPLAY}" ]]; then
        log_error "DISPLAY环境变量未设置，无法使用图形界面"
        return 1
    fi
    
    log_info "当前DISPLAY环境变量值为: ${DISPLAY}"
    
    # 检查X11服务是否运行
    if ! command -v xhost >/dev/null 2>&1; then
        log_warning "xhost命令不存在，可能无法设置X11权限"
        return 1
    fi
    
    # 检查X11服务器是否可访问
    if ! xset q >/dev/null 2>&1; then
        log_warning "X11服务器不可访问，图形界面可能无法使用"
        return 1
    fi
    
    # 设置X11权限
    if xhost +local:root >/dev/null 2>&1; then
        log_success "X11 转发配置完成"
        return 0
    else
        log_warning "X11 转发配置失败，图形界面可能无法使用"
        return 1
    fi
}

create_and_start_container() {
    log_info "创建并启动容器"
    
    # 切换到工作目录
    cd "$WS_DIR" || log_error "无法切换到工作目录: $WS_DIR"
    
    # 检查docker-compose.yml文件是否存在
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml 文件不存在，请检查项目结构"
    fi
    
    # 兼容 docker compose 和 docker-compose 
    local compose_cmd=""
    if command -v "docker" >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
        log_info "使用 docker compose 命令"
    elif command -v "docker-compose" >/dev/null 2>&1; then
        compose_cmd="docker-compose"
        log_info "使用 docker-compose 命令"
    else
        log_error "未找到 docker compose 或 docker-compose 命令"
    fi

    # 启动容器
    if $compose_cmd -f docker-compose.yml up -d; then
        log_success "容器创建并启动成功"
        
        # 等待容器完全启动
        log_info "等待容器完全启动"
        sleep 3
        
        # 检查容器状态
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            log_success "容器运行状态正常"
        else
            log_error "容器启动失败"
        fi
    else
        log_error "容器创建失败"
    fi
}

enter_container() {
    log_info "进入容器: $CONTAINER_NAME"
    
    # 检查容器是否运行
    if ! docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_error "容器未运行，无法进入"
    fi
    
    # 检查容器是否健康
    local container_health
    container_health=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
    if [[ "$container_health" == "unhealthy" ]]; then
        log_warning "容器状态不健康，但仍尝试进入"
    fi
    
    log_success "正在进入容器，使用 'exit' 命令退出"
    echo "----------------------------------------"
    
    # 进入容器
    xhost +local:docker >/dev/null 2>&1 || log_warning "X11权限设置失败"
    
    # 尝试进入容器并执行wxwork
    if ! docker exec -it "$CONTAINER_NAME" wxwork; then
        log_warning "wxwork启动失败，尝试进入容器shell"
        docker exec -it "$CONTAINER_NAME" bash
    fi
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    # 设置错误处理
    set_error_handling
    
    log_info "Wine Docker 智能启动脚本开始执行..."
    
    # 检查基础依赖
    log_info "检查基础依赖..."
    ensure_commands "docker" "xhost" "xset"
    
    # 步骤1：检查Docker环境配置
    if is_docker_configured; then
        log_success "Docker环境已配置，跳过配置步骤"
    else
        log_info "Docker环境未配置，开始配置..."
        if [[ "${EUID}" -ne 0 ]]; then
            log_error "Docker配置需要root权限，请使用: sudo $0"
        fi
        setup_docker_environment
        log_success "Docker环境配置完成，继续执行后续步骤"
    fi
    
    # 步骤2：检查Docker镜像
    if is_image_built; then
        log_success "Docker镜像已存在，跳过构建步骤"
    else
        log_info "Docker镜像不存在，开始构建..."
        check_docker
        setup_buildx
        build_docker_image
        log_success "Docker镜像构建完成"
    fi
    
    # 步骤3：检查容器状态
    local container_status
    container_status=$(check_container_status)
    
    case "$container_status" in
        "running")
            log_success "容器已在运行，直接进入"
            enter_container
            ;;
        "stopped")
            log_info "容器已停止，重新启动..."
            if ! setup_x11_forwarding; then
                log_warning "X11配置失败，但继续启动容器（可能无法使用图形界面）"
            fi
            create_and_start_container
            enter_container
            ;;
        "not_exists")
            log_info "容器不存在，创建新容器..."
            if ! setup_x11_forwarding; then
                log_warning "X11配置失败，但继续创建容器（可能无法使用图形界面）"
            fi
            create_and_start_container
            enter_container
            ;;
        *)
            log_error "未知的容器状态: $container_status"
            ;;
    esac
    
    log_success "Wine Docker 运行完成！"
}

# 执行主函数
main "$@" 