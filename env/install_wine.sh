#!/bin/bash
set -e

# 设置非交互式环境变量，避免交互式配置提示
export DEBIAN_FRONTEND=noninteractive

# 安装wine
echo "正在安装 Deepin Wine 环境..."
if wget -O- https://deepin-wine.i-m.dev/setup.sh | sh; then
    echo "Deepin Wine 安装成功"
else
    echo "Deepin Wine 安装失败" >&2
    exit 1
fi

# 下载并安装spark-store补丁包
echo "正在下载 Spark Store 补丁包..."
if wget https://gitcode.com/spark-store-project/spark-store/releases/download/4.7.0/spark-store_4.7.0_amd64.deb -O /tmp/spark-store_4.7.0_amd64.deb; then
    echo "Spark Store 补丁包下载成功"
    
    echo "正在安装 Spark Store 补丁包..."
    if apt-get install -y /tmp/spark-store_4.7.0_amd64.deb; then
        echo "Spark Store 补丁包安装成功"
        # 清理下载的文件
        rm -f /tmp/spark-store_4.7.0_amd64.deb
    else
        echo "Spark Store 补丁包安装失败" >&2
        exit 1
    fi
else
    echo "Spark Store 补丁包下载失败" >&2
    exit 1
fi

echo "Wine 环境安装完成"







