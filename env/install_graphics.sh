#!/bin/bash
set -e

# 设置非交互式环境变量，避免交互式配置提示
export DEBIAN_FRONTEND=noninteractive

apt-get install -y --no-install-recommends \
    dbus-x11 winbind x11-utils \
    libfreetype6 libfontconfig1 libvulkan1 \
    libx11-6 libx11-dev libx11-xcb1 \
    libxrandr2 libxrandr-dev libxinerama-dev \
    libxcursor1 libxcursor-dev \
    libxi6 libxi-dev \
    libxss1 libsm6 libxt6 libxtst6 \
    libxext6 libxrender1 libxcomposite1 \
    libxkbcommon-x11-0 \
    libxcb1 libxcb-xinerama0 \
    libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
    libxcb-randr0 libxcb-shape0 libxcb-render-util0 \
    libglu1-mesa libglu1-mesa-dev \
    libgl1-mesa-glx libgl1-mesa-dev \
    libegl1-mesa-dev libglvnd-dev libopengl0 \
    libxxf86vm-dev
