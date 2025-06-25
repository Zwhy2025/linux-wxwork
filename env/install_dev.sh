#!/bin/bash
set -e

# 设置非交互式环境变量，避免交互式配置提示
export DEBIAN_FRONTEND=noninteractive

apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    zip \
    unzip \
    ccache \
    python3 \
    python3-dev \
    python3-pip \
    htop \
    gdb \
    strace \
    debhelper \
    devscripts \
    fakeroot \
    net-tools \
    iputils-ping \
    psmisc \
    fuse \
    libharfbuzz0b \
    jq \

