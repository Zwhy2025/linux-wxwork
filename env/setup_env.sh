#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "开始配置 Wine Docker 环境..."

# 安装基础环境
echo "步骤 1/5: 安装基础系统包..."
if bash "$SCRIPT_DIR/install_base.sh"; then
    echo "✅ 基础系统包安装完成"
else
    echo "❌ 基础系统包安装失败" >&2
    exit 1
fi

# 安装开发工具
echo "步骤 2/5: 安装开发工具..."
if bash "$SCRIPT_DIR/install_dev.sh"; then
    echo "✅ 开发工具安装完成"
else
    echo "❌ 开发工具安装失败" >&2
    exit 1
fi

# 安装图形界面支持
echo "步骤 3/5: 安装图形界面支持..."
if bash "$SCRIPT_DIR/install_graphics.sh"; then
    echo "✅ 图形界面支持安装完成"
else
    echo "❌ 图形界面支持安装失败" >&2
    exit 1
fi

# 安装Wine环境
echo "步骤 4/5: 安装Wine环境..."
if bash "$SCRIPT_DIR/install_wine.sh"; then
    echo "✅ Wine环境安装完成"
else
    echo "❌ Wine环境安装失败" >&2
    exit 1
fi

# 安装企业微信
echo "步骤 5/5: 安装企业微信..."
if bash "$SCRIPT_DIR/install_wxwork.sh"; then
    echo "✅ 企业微信安装完成"
else
    echo "❌ 企业微信安装失败" >&2
    exit 1
fi

echo "正在清理临时文件..."
rm -rf /tmp/* 2>/dev/null || true
rm -rf /var/lib/apt/lists/* 2>/dev/null || true
rm -rf /var/cache/apt/* 2>/dev/null || true
rm -rf /var/cache/apt/archives/* 2>/dev/null || true

echo "🎉 Wine Docker 环境配置完成！"