#!/bin/bash
set -e

# 设置非交互式环境变量，避免交互式配置提示
export DEBIAN_FRONTEND=noninteractive


sudo apt-get install com.qq.weixin.work.deepin -y


sudo tee /usr/bin/wxwork > /dev/null << 'EOF'
#!/bin/bash
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
/opt/apps/com.qq.weixin.work.deepin/files/run.sh
EOF


chmod +x /usr/bin/wxwork

