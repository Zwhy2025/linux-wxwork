# Changelog

本文档遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范。

## [v2.0.3] - 2026-08-13

### Added
- **企业微信 v5 支持**：`mapping.json` 中新增企业微信 v5 版本（5.0.7.6005deepin11）
- **已安装应用升级提醒**：`run.sh` 运行应用时，若源中存在新版本（如企业微信 v4 → v5）提示用户，确认后升级
  - 升级使用 `apt-get install`，自动补齐新依赖（如 wine10）并保留用户数据与配置
  - 交互式确认，默认跳过（非交互环境下也不会自动升级）
  - 已安装时指定版本（`-v`）提示仅用于初始安装，升级请直接运行（不带 `-v`）

### Fixed
- **版本验证逻辑**：`app.sh` 指定版本安装时按请求版本验证，修复之前 v4/v5 判断写反的问题
- **容器重建后检测不到更新**：镜像中 apt 列表为构建时缓存，重建容器后 candidate 仍是旧版导致误判无更新；升级检测前先 `apt-get update` 刷新
- **镜像 ubuntu 源 403**：镜像内 `sources.list` 路径多一层 `/ubuntu/` 导致依赖无法安装（如 x11-utils），安装/升级前自动修复（幂等）

## [v2.0.2] - 2026-01-10

### Added
- **版本安装功能**：支持通过版本参数安装特定版本的应用
  - `./tools/run.sh install wxwork -v v4` - 安装指定版本的应用
  - `./tools/run.sh wxwork -v v4` - 运行应用时如果未安装则安装指定版本
  - 版本映射存储在 `mapping.json` 中，支持为每个应用配置多个版本
- **Docker 安装脚本**：新增 `tools/lib/install_docker.sh` 脚本
  - 自动检测系统架构（amd64/arm64）
  - 使用阿里云镜像源加速下载
  - 自动将用户添加到 docker 组
- **Docker 自动安装**：检测到系统未安装 Docker 时自动安装
  - 在 `setup.sh` 和 `functions.bash` 中集成自动安装逻辑
  - 使用项目提供的 `install_docker.sh` 脚本进行安装
  - 需要 root 权限时会提示用户使用 sudo

### Changed
- **安装逻辑优化**：支持从指定 URL 下载并安装 deb 包
  - 当指定版本时，从映射表获取对应的 deb 包 URL
  - 使用 wget 下载并安装，支持自定义 User-Agent
  - 自动处理依赖关系
- **Docker 检查逻辑**：优化 Docker 环境检查流程
  - 在 `ensure_docker_environment()` 中先检查并安装 Docker
  - 移除回退到官方安装脚本的逻辑，只使用项目提供的安装脚本

### Fixed
- 修复 `install_docker.sh` 脚本的路径引用问题
- 修复版本参数解析逻辑，支持 `-v` 和 `--version` 参数

### Technical Improvements
- 在 `functions.bash` 中添加 `get_version_url()` 函数，统一管理版本映射读取
- 优化参数解析逻辑，支持在运行应用时指定安装版本
- 改进 Docker 安装脚本的路径查找逻辑

---

## [v2.0.1] - 2026-01-10

### Changed
- **目录结构重构**：将内部实现文件移动到 `tools/lib/` 目录
  - `tools/app.sh` → `tools/lib/app.sh`
  - `tools/functions.bash` → `tools/lib/functions.bash`
  - `tools/setup.sh` → `tools/lib/setup.sh`
- **统一入口**：对外只暴露 `tools/run.sh` 和 `tools/run_wxwork.sh`
  - 所有应用管理命令通过 `./tools/run.sh` 统一调用
  - 不再暴露 `lib` 目录，简化用户使用

### Added
- **容器管理功能**：在 `run.sh` 中添加容器管理命令
  - `./tools/run.sh stop` - 停止容器
  - `./tools/run.sh stop --clear/-c` - 停止并删除容器和镜像
- **命令转发**：`run.sh` 现在支持转发所有应用管理命令
  - `list` - 查看所有可用应用
  - `search` - 搜索应用
  - `install` - 安装应用
  - `uninstall` - 卸载应用

### Fixed
- 修复 `mapping.json` 路径计算错误（lib 目录下的脚本现在能正确找到项目根目录）
- 修复所有帮助信息和提示信息中的路径暴露问题
- 统一所有用户提示使用 `./tools/run.sh` 而不是 `./tools/lib/app.sh`

### Technical Improvements
- 改进路径计算逻辑，支持从不同目录层级正确计算项目根目录
- 优化代码结构，内部实现与对外接口分离
- 提升用户体验，简化命令使用方式

---

## [v2.0.0] - 2026-01-10

### Added
- 多应用支持：从单一应用（企业微信）升级为支持数百款 Windows 应用
- 应用管理功能：`./tools/app.sh` 支持安装、卸载、搜索、列出应用
- 统一运行接口：`./tools/run.sh <应用名>` 统一运行所有应用
- 应用映射表：`mapping.json` 配置文件管理应用信息
- 运行时 Wine 安装：Wine 环境在首次运行时自动安装
- 公共函数库：`tools/functions.bash` 统一管理公共函数
- 环境依赖检查：`tools/setup.sh` 自动检查和安装系统依赖

### Changed
- **架构重构**：从单体脚本（523 行）重构为模块化设计
  - `tools/run_wxwork.sh`: 523 行 → 8 行（兼容性脚本）
  - 新增 `tools/app.sh`、`tools/run.sh`、`tools/functions.bash`、`tools/setup.sh`
- **Wine 安装策略**：从构建时安装改为运行时安装
  - 镜像构建时间：~400秒 → ~100秒（减少 75%）
  - 镜像体积：~2.5GB → ~2.0GB（减少 500MB）

### Removed
- `env/install_wine.sh` → 重命名为 `env/install_spark_store.sh`
- `env/install_wxwork.sh` → 功能迁移到运行时安装
- `env/setup_env.sh` → 功能整合到 `tools/setup.sh`
- Dockerfile 中的 Wine 安装步骤

### Fixed
- 修复构建时 Wine 安装可能失败的问题（改为运行时安装）
- 简化错误处理逻辑，移除冗余的异常检查
- 修复代码重复问题，提取公共函数到 `functions.bash`
- 修复 `create_wrapper` 函数中重复的 `chmod` 调用

### Technical Improvements
- 代码优化：移除重复的软件源配置检查和文件复制逻辑
- 错误处理：利用 `set -e` 简化错误处理，统一日志函数
- 模块化设计：功能职责清晰，易于维护和扩展
- 配置管理：从硬编码改为 JSON 配置文件

---

## [v1.0.0] - 2025

### Added
- 基于 Docker 的企业微信运行环境
- 自动配置 Docker 环境和镜像源
- 自动构建 Wine Docker 镜像
- 一键运行企业微信

---
