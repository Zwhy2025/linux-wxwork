#!/bin/bash

# Deepin-Wine 公共函数库
# 所有脚本共享的通用函数

# ============================================================================
# 变量定义
# ============================================================================

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 路径变量（如果未设置则初始化）
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -z "${WS_DIR:-}" ]]; then
    # 如果 SCRIPT_DIR 在 lib 目录下，需要向上两级到达项目根目录
    # 如果 SCRIPT_DIR 在 tools 目录下，只需要向上一级
    if [[ "$SCRIPT_DIR" == */lib ]]; then
        WS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
    else
        WS_DIR="$(dirname "$SCRIPT_DIR")"
    fi
fi
if [[ -z "${MAPPING_FILE:-}" ]]; then
    MAPPING_FILE="${WS_DIR}/mapping.json"
fi
if [[ -z "${APP_SCRIPT:-}" ]]; then
    APP_SCRIPT="${SCRIPT_DIR}/lib/app.sh"
fi
if [[ -z "${CONTAINER_NAME:-}" ]]; then
    CONTAINER_NAME="wine_container"
fi

# Docker 相关变量
IMAGE_NAME="${IMAGE_NAME:-zwhy2025/wine-docker}"
TAG="${TAG:-base}"
PLATFORM="${PLATFORM:-linux/amd64}"
DOCKER_CONFIG_DIR="${DOCKER_CONFIG_DIR:-/etc/docker}"
DOCKER_CONFIG_FILE="${DOCKER_CONFIG_FILE:-${DOCKER_CONFIG_DIR}/daemon.json}"
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

# ============================================================================
# 日志函数
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠️  [WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $*" >&2
}

# ============================================================================
# 环境检测函数
# ============================================================================

is_in_container() {
    [ -f /.dockerenv ] || grep -qa docker /proc/1/cgroup 2>/dev/null
}

is_container_running() {
    docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$" 2>/dev/null
}

# ============================================================================
# 命令检查函数
# ============================================================================

ensure_commands() {
    local missing_cmds=()
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [ ${#missing_cmds[@]} -gt 0 ]; then
        log_error "缺少以下命令：${missing_cmds[*]}，请先安装它们。"
        exit 1
    fi
}

ensure_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "缺少命令: $1，请先安装"
        exit 1
    fi
}

# ============================================================================
# 应用映射表函数
# ============================================================================

read_mapping() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        log_error "映射表文件不存在: $MAPPING_FILE"
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "需要 jq 命令来解析 JSON，请先安装: apt install jq"
        exit 1
    fi
    
    # 支持新旧两种格式
    # 新格式: {"key": {"package": "...", "description": "..."}}
    # 旧格式: {"key": "package"}
    jq -r 'to_entries[] | 
        if .value | type == "object" then
            "\(.key)|\(.value.package)|\(.value.description // "")"
        else
            "\(.key)|\(.value)|"
        end' "$MAPPING_FILE" 2>/dev/null || {
        log_error "无法读取映射表文件"
        exit 1
    }
}

find_package_by_short_name() {
    local short_name="$1"
    read_mapping | grep "^${short_name}|" | cut -d'|' -f2 | head -n1
}

find_description_by_short_name() {
    local short_name="$1"
    read_mapping | grep "^${short_name}|" | cut -d'|' -f3 | head -n1
}

find_short_name_by_package() {
    local package="$1"
    read_mapping | grep "|${package}|" | cut -d'|' -f1 | head -n1
}

add_mapping() {
    local short_name="$1"
    local package="$2"
    local description="${3:-}"
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "需要 jq 命令来更新映射表"
        return 1
    fi
    
    # 备份原文件
    cp "$MAPPING_FILE" "${MAPPING_FILE}.bak" 2>/dev/null || true
    
    # 使用 jq 添加映射（新格式：包含描述）
    if [[ -n "$description" ]]; then
        jq ". + {\"${short_name}\": {\"package\": \"${package}\", \"description\": \"${description}\"}}" "$MAPPING_FILE" > "${MAPPING_FILE}.tmp" && \
        mv "${MAPPING_FILE}.tmp" "$MAPPING_FILE" && \
        log_success "已添加映射: ${short_name} -> ${package} (${description})"
    else
        jq ". + {\"${short_name}\": {\"package\": \"${package}\", \"description\": \"\"}}" "$MAPPING_FILE" > "${MAPPING_FILE}.tmp" && \
        mv "${MAPPING_FILE}.tmp" "$MAPPING_FILE" && \
        log_success "已添加映射: ${short_name} -> ${package}"
    fi
}

get_version_url() {
    local short_name="$1"
    local version="$2"
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "需要 jq 命令来读取版本映射"
        return 1
    fi
    
    if [[ ! -f "$MAPPING_FILE" ]]; then
        log_error "映射表文件不存在: $MAPPING_FILE"
        return 1
    fi
    
    # 从 mapping.json 中读取版本 URL
    local url
    url=$(jq -r ".[\"${short_name}\"].versions[\"${version}\"] // empty" "$MAPPING_FILE" 2>/dev/null)
    
    if [[ -z "$url" ]] || [[ "$url" == "null" ]]; then
        return 1
    fi
    
    echo "$url"
}

# ============================================================================
# 应用安装检查函数
# ============================================================================

check_app_installed_in_container() {
    local package="$1"
    docker exec "$CONTAINER_NAME" dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"
}

# 修复容器内 ubuntu 源路径（镜像构建时多写了一层 /ubuntu/，导致 403 无法安装依赖；幂等）
fix_apt_sources_in_container() {
    docker exec "$CONTAINER_NAME" bash -c "sed -i 's|http://mirrors.ustc.edu.cn/ubuntu/ubuntu/|http://mirrors.ustc.edu.cn/ubuntu/|g' /etc/apt/sources.list"
}

# 检查容器内已安装应用是否有可用更新（已安装版本 < 源中最新版本）
# 依赖 apt 源（deepin-wine.i-m.dev），未配置源时返回 1（视为无更新）
# 注意：镜像/旧容器缓存的 apt 列表可能过期（重建容器后 candidate 仍为旧版），需先 update 刷新
app_has_update_in_container() {
    local package="$1"
    docker exec "$CONTAINER_NAME" bash -c "
        # 刷新 apt 列表后再比较，否则重建容器后 lists 过期会误判无更新；
        # ubuntu 源 403 时 update 会非零退出，但 i-m.dev 源仍可刷新，故忽略错误
        apt-get update -qq >/dev/null 2>&1 || true
        installed=\$(dpkg-query -W -f='\${Version}' '$package' 2>/dev/null)
        candidate=\$(apt-cache policy '$package' 2>/dev/null | awk '/Candidate:/{print \$2}')
        [[ -n \"\$installed\" && -n \"\$candidate\" && \"\$installed\" != \"\$candidate\" ]] && echo update || echo no-update
    " | grep -qx update
}

check_app_installed_local() {
    local package="$1"
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"
}

check_wrapper_exists() {
    local short_name="$1"
    if is_in_container; then
        [ -f "/usr/bin/${short_name}" ]
    else
        docker exec "$CONTAINER_NAME" test -f "/usr/bin/${short_name}" 2>/dev/null
    fi
}

# ============================================================================
# Wrapper 创建函数
# ============================================================================

create_wrapper() {
    local short_name="$1"
    local package="$2"
    
    # 查找应用的 run.sh 路径
    local app_dir="/opt/apps/${package}"
    local run_script="${app_dir}/files/run.sh"
    
    if [[ ! -f "$run_script" ]]; then
        log_warning "未找到应用的 run.sh: $run_script"
        return 1
    fi
    
    # 创建必要的用户目录（如果不存在）
    if is_in_container; then
        mkdir -p /root/Desktop /root/Downloads /root/Documents 2>/dev/null || true
    fi
    
    # 创建 wrapper 脚本
    local wrapper="/usr/bin/${short_name}"
    sudo tee "$wrapper" > /dev/null <<EOF
#!/bin/bash
# #region agent log
LOG_FILE="/workspace/.cursor/debug.log"
log_debug() {
    local hypothesis_id="\$1"
    local location="\$2"
    local message="\$3"
    local data="\$4"
    echo "{\"sessionId\":\"debug-session\",\"runId\":\"run1\",\"hypothesisId\":\"\$hypothesis_id\",\"location\":\"\$location\",\"message\":\"\$message\",\"data\":\$data,\"timestamp\":\$(date +%s%3N)}" >> "\$LOG_FILE" 2>/dev/null || true
}
# #endregion

# 设置输入法环境变量
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# 设置 XDG 运行时目录
export XDG_RUNTIME_DIR=\${XDG_RUNTIME_DIR:-/tmp/runtime-root}
mkdir -p "\$XDG_RUNTIME_DIR" 2>/dev/null || true

# 创建必要的用户目录
mkdir -p /root/Desktop /root/Downloads /root/Documents 2>/dev/null || true

# #region agent log
log_debug "A" "wrapper:start" "Wrapper script started" "{\"package\":\"\${DEB_PACKAGE_NAME:-unknown}\",\"display\":\"\$DISPLAY\",\"xdg_runtime_dir\":\"\$XDG_RUNTIME_DIR\"}"
# #endregion

# #region agent log
log_debug "B" "wrapper:before_run" "Before running app script" "{\"run_script\":\"${run_script}\"}"
# #endregion

# 运行应用
RUN_EXIT_CODE=0
${run_script} || RUN_EXIT_CODE=\$?

# #region agent log
log_debug "C" "wrapper:after_run" "After running app script" "{\"exit_code\":\$RUN_EXIT_CODE,\"pid\":\$\$}"
# #endregion

# #region agent log
log_debug "D" "wrapper:check_processes" "Checking running processes" "{\"wxwork_pids\":\"\$(ps aux | grep -E 'WXWork|deepin-wine-banner' | grep -v grep | awk '{print \$2}' | tr '\\n' ',')\"}"
# #endregion

exit \$RUN_EXIT_CODE
EOF
    
    sudo chmod +x "$wrapper"
    log_success "已创建启动脚本: ${wrapper}"
}

# ============================================================================
# Docker 环境管理函数
# ============================================================================

is_docker_configured() {
    [[ -f "$DOCKER_CONFIG_FILE" ]] && grep -q "registry-mirrors" "$DOCKER_CONFIG_FILE" 2>/dev/null
}

is_image_built() {
    docker inspect "${IMAGE_NAME}:${TAG}" >/dev/null 2>&1
}

check_container_status() {
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        echo "running"
    elif docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        echo "stopped"
    else
        echo "not_exists"
    fi
}

setup_docker_environment() {
    log_info "开始配置Docker环境..."
    
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "Docker配置需要 root 权限，请使用 sudo 运行此脚本"
        exit 1
    fi
    
    ensure_commands docker jq
    mkdir -p "${DOCKER_CONFIG_DIR}" || log_error "无法创建Docker配置目录"
    
    local temp_file=$(mktemp)
    cat > "${temp_file}" <<EOF
{
  "registry-mirrors": $(printf '%s\n' "${REGISTRY_MIRRORS[@]}" | jq -R . | jq -s .)
}
EOF
    
    jq empty "${temp_file}" &>/dev/null || {
        rm -f "${temp_file}"
        log_error "生成的JSON配置无效"
        exit 1
    }
    
    mv "${temp_file}" "${DOCKER_CONFIG_FILE}" || log_error "无法写入Docker配置文件"
    chmod 705 "${DOCKER_CONFIG_FILE}"
    systemctl restart docker || log_error "无法重启Docker服务"
    log_success "Docker环境配置完成"
}

check_docker() {
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        return 0
    fi
    
    log_warning "Docker 未安装或未运行，尝试自动安装..."
    
    # 检查是否有 root 权限
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "Docker 安装需要 root 权限，请使用 sudo 运行"
        log_info "或者手动运行: sudo bash ${SCRIPT_DIR}/install_docker.sh"
        exit 1
    fi
    
    # 使用项目提供的安装脚本
    # install_docker.sh 在 tools/lib/ 目录下
    local install_script="${SCRIPT_DIR}/install_docker.sh"
    # 如果 SCRIPT_DIR 不是 lib 目录，尝试查找 lib 目录
    if [[ ! -f "$install_script" ]] && [[ "$SCRIPT_DIR" != */lib ]]; then
        install_script="$(dirname "$SCRIPT_DIR")/lib/install_docker.sh"
    fi
    
    if [[ ! -f "$install_script" ]]; then
        log_error "未找到 Docker 安装脚本: $install_script"
        log_info "请确保 install_docker.sh 脚本存在于 tools/lib/ 目录"
        exit 1
    fi
    
    log_info "使用项目提供的 Docker 安装脚本: $install_script"
    if bash "$install_script"; then
        # 等待 Docker 服务启动
        sleep 2
        if docker info >/dev/null 2>&1; then
            log_success "Docker 安装完成"
            return 0
        else
            log_error "Docker 安装后仍无法使用，请检查 Docker 服务状态"
            log_info "尝试运行: sudo systemctl start docker"
            exit 1
        fi
    else
        log_error "Docker 安装失败"
        exit 1
    fi
}

setup_buildx() {
    docker buildx ls | grep -q "default" || docker buildx create --use --name default >/dev/null 2>&1
}

build_docker_image() {
    log_info "开始构建 Docker 镜像: ${IMAGE_NAME}:${TAG}"
    cd "$WS_DIR" || log_error "无法切换到工作目录: $WS_DIR"
    docker buildx build --platform "$PLATFORM" -t "${IMAGE_NAME}:${TAG}" --load . || log_error "Docker 镜像构建失败"
    log_success "Docker 镜像构建成功"
}

setup_x11_forwarding() {
    [[ -z "${DISPLAY}" ]] && log_error "DISPLAY环境变量未设置，无法使用图形界面"
    command -v xhost >/dev/null 2>&1 || {
        log_warning "xhost命令不存在，可能无法设置X11权限"
        return 1
    }
    xhost +local:root >/dev/null 2>&1 && log_success "X11 转发配置完成" || {
        log_warning "X11 转发配置失败"
        return 1
    }
}

create_and_start_container() {
    log_info "创建并启动容器"
    cd "$WS_DIR" || log_error "无法切换到工作目录: $WS_DIR"
    [[ -f "docker-compose.yml" ]] || log_error "docker-compose.yml 文件不存在"
    
    local compose_cmd
    if docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        log_error "未找到 docker compose 或 docker-compose 命令"
        exit 1
    fi
    
    $compose_cmd -f docker-compose.yml up -d || log_error "容器创建失败"
    sleep 3
    docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$" || log_error "容器启动失败"
    log_success "容器创建并启动成功"
}

ensure_docker_environment() {
    # 只在容器外执行
    if is_in_container; then
        return 0
    fi
    
    log_info "检查 Docker 环境..."
    
    # 步骤0：检查并安装 Docker（如果需要）
    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
        check_docker
    fi
    
    ensure_commands docker xhost xset
    
    # 步骤1：检查Docker环境配置
    if ! is_docker_configured; then
        log_info "Docker环境未配置，开始配置..."
        if [[ "${EUID}" -ne 0 ]]; then
            log_error "Docker配置需要root权限，请使用: sudo $0 $*"
            exit 1
        fi
        setup_docker_environment
    fi
    
    # 步骤2：检查Docker镜像
    if ! is_image_built; then
        log_info "Docker镜像不存在，开始构建..."
        check_docker
        setup_buildx
        build_docker_image
    fi
    
    # 步骤3：检查容器状态并处理
    local container_status=$(check_container_status)
    
    case "$container_status" in
        "running")
            log_success "容器已在运行"
            ;;
        "stopped"|"not_exists")
            [[ "$container_status" == "stopped" ]] && log_info "容器已停止，重新启动..." || log_info "容器不存在，创建新容器..."
            setup_x11_forwarding || log_warning "X11配置失败，但继续启动容器"
            create_and_start_container
            ;;
    esac
}
