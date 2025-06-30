# Linux-WXWork 项目

一个基于Docker的Wine环境项目，专门用于在Linux系统上运行企业微信等Windows应用程序。

## 📋 项目概述

本项目提供了一个完整的Docker化Wine环境，主要特性包括：

- 🐧 在Linux系统上运行企业微信
- 🐳 完全容器化，环境隔离
- 🎨 支持图形界面应用
- 🔧 自动化安装和配置脚本
- 📁 数据持久化存储

## 🏗️ 项目结构

```
wine-docker/
├── env/                          # 环境安装脚本
│   ├── install_base.sh          # 基础系统包安装
│   ├── install_dev.sh           # 开发工具安装
│   ├── install_graphics.sh      # 图形界面支持
│   ├── install_wine.sh          # Wine环境安装
│   ├── install_wxwork.sh        # 企业微信安装
│   └── setup_env.sh             # 环境设置
├── tools/                        # 工具脚本
│   └── run_wxwork.sh       # 智能运行脚本
├── wxwork-files/                 # 企业微信数据目录
│   ├── [用户ID]/                # 用户数据
│   │   ├── Data/               # 应用数据
│   │   ├── Cache/              # 缓存文件
│   │   ├── Backup/             # 备份数据
│   │   └── WeDrive/            # 企业网盘
│   ├── Global/                  # 全局配置
│   ├── Profiles/                # 用户配置文件
│   └── qtCef/                   # CEF浏览器引擎
├── docker-compose.yml           # Docker Compose配置
├── Dockerfile                   # Docker镜像构建文件
├── .gitignore                   # Git忽略文件
└── README.md                    # 项目说明文档
```

## 🚀 快速开始

### 系统要求

- Linux操作系统（推荐Ubuntu 22.04）
- Docker和Docker Compose
- X11图形服务器
- 至少4GB内存
- 2GB可用磁盘空间

### 安装步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd wine-docker
   ```

2. **运行智能安装脚本**
   ```bash
   sudo bash tools/run_wxwork.sh
   ```
   
   脚本会自动执行以下步骤：
   - 配置Docker环境和镜像源
   - 构建Wine Docker镜像
   - 启动容器并运行企业微信

3. **手动启动（可选）**
   ```bash
   # 构建镜像
   docker-compose build
   
   # 启动容器
   docker-compose up -d
   
   # 进入容器
   docker exec -it wine_container bash
   
   # 运行企业微信
   wxwork
   ```

## 🔧 配置说明

### Docker Compose配置

- **镜像**: `zwhy2025/wine-docker:base`
- **容器名**: `wine_container`
- **特权模式**: 启用（用于设备访问）
- **网络模式**: host（共享主机网络）
- **共享内存**: 16GB
- **卷挂载**:
  - 项目目录 → `/workspace`
  - 企业微信数据 → `/root/.deepinwine/Deepin-WXWork/drive_c/users/root/Documents/WXWork/`
  - X11认证 → `/root/.Xauthority`

### 环境变量

- `DISPLAY`: X11显示服务器
- `QT_X11_NO_MITSHM`: 禁用MIT-SHM扩展
- `ACCEPT_EULA=Y`: 接受最终用户许可协议
- `PRIVACY_CONSENT=Y`: 隐私协议同意

## 📁 数据目录说明

### wxwork-files/ 目录结构

- **用户数据目录** (`[用户ID]/`): 每个用户的独立数据空间
  - `Data/`: 应用程序数据和设置
  - `Cache/`: 缓存文件（图片、视频、文件等）
  - `Backup/`: 数据备份
  - `WeDrive/`: 企业网盘本地同步文件
  - `Emotion/`: 表情包数据

- **全局配置** (`Global/`): 
  - `CDN/`: 内容分发网络缓存
  - `CefCache/`: CEF浏览器缓存
  - `Image/`: 全局图片资源

- **用户配置文件** (`Profiles/`): 用户特定的配置和缓存

- **浏览器引擎** (`qtCef/`): Qt CEF组件的缓存和数据

## 🛠️ 开发和调试

### 进入容器调试

```bash
# 进入运行中的容器
docker exec -it wine_container bash

# 查看Wine配置
winecfg

# 查看企业微信进程
ps aux | grep wxwork

# 查看日志
tail -f /var/log/wine.log
```

### 重建镜像

```bash
# 清理旧镜像
docker rmi zwhy2025/wine-docker:base

# 重新构建
docker-compose build --no-cache
```

## 🔍 故障排除

### 常见问题

1. **图形界面无法显示**
   ```bash
   # 允许X11连接
   xhost +local:docker
   
   # 检查DISPLAY变量
   echo $DISPLAY
   ```

2. **企业微信无法启动**
   ```bash
   # 检查Wine环境
   wine --version
   
   # 重新配置Wine
   winecfg
   ```

3. **数据丢失问题**
   - 确保 `wxwork-files/` 目录已正确挂载
   - 检查文件权限设置

### 日志查看

```bash
# 容器日志
docker logs wine_container

# 企业微信日志
docker exec wine_container tail -f /root/.deepinwine/Deepin-WXWork/drive_c/users/root/Documents/WXWork/*/Data/log/*
```

## 📝 注意事项

1. **数据安全**: `wxwork-files/` 目录包含用户数据，请定期备份
2. **权限问题**: 容器以特权模式运行，注意安全风险
3. **资源占用**: 企业微信可能占用较多内存和CPU资源
4. **网络访问**: 使用host网络模式，注意防火墙设置

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进这个项目。

## 📄 许可证

本项目遵循相应的开源许可证。

## 🆘 支持

如果遇到问题，请：
1. 查看故障排除部分
2. 提交Issue描述问题
3. 提供相关日志信息

---

**注意**: 本项目仅用于学习和研究目的，请遵守相关软件的使用协议。 
