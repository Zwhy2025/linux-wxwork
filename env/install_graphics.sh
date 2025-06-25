#!/bin/bash
set -e

# 设置非交互式环境变量，避免交互式配置提示
export DEBIAN_FRONTEND=noninteractive

apt-get install -y --no-install-recommends \
    libglu1-mesa \
    libglu1-mesa-dev \
    libopengl0 \
    libglvnd-dev \
    libgl1-mesa-dev \
    libgl1-mesa-glx \
    libegl1-mesa-dev \
    libx11-6 \
    libx11-dev \
    libx11-xcb1 \
    libxrandr-dev \
    libxrandr2 \
    libxinerama-dev \
    libxcursor-dev \
    libxcursor1 \
    libxi-dev \
    libxi6 \
    libxxf86vm-dev \
    libsm6 \
    libxext6 \
    libxrender1 \
    libxt6 \
    libxtst6 \
    libxss1 \
    libxcomposite1 \
    libxcb1 \
    libxcb-xinerama0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-shape0 \
    libxcb-render-util0 \
    libfreetype6 \
    libfontconfig1 \
    libxkbcommon-x11-0 