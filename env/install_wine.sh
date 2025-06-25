#!/bin/bash
set -e

# 设置非交互式环境变量，避免交互式配置提示
export DEBIAN_FRONTEND=noninteractive


wget -O- https://deepin-wine.i-m.dev/setup.sh | sh

wget https://gitcode.com/spark-store-project/spark-store/releases/download/4.7.0/spark-store_4.7.0_amd64.deb -O /tmp/spark-store_4.7.0_amd64.deb

apt-get install -y /tmp/spark-store_4.7.0_amd64.deb

echo -e "\nGTK_IM_MODULE=fcitx\nQT_IM_MODULE=fcitx\nXMODIFIERS=@im=fcitx" | sudo tee -a /etc/environment > /dev/null








