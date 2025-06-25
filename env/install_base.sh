#!/bin/bash
set -e

# 设置非交互式环境变量，避免时区配置提示
export DEBIAN_FRONTEND=noninteractive
export TZ=Asia/Shanghai

# 换源
sed -i 's|http://.*.ubuntu.com|http://mirrors.ustc.edu.cn/ubuntu|g' /etc/apt/sources.list
apt-get update

# 基础工具
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    locales \
    sudo \
    vim \
    git \
    zsh \
    wget \
    rsync \
    lsb-release

# 配置时区
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 配置语言环境
locale-gen en_US.UTF-8 zh_CN.UTF-8
update-locale LC_ALL=zh_CN.UTF-8 LANG=zh_CN.UTF-8 