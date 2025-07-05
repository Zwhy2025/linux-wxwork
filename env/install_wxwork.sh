#!/bin/bash
set -e

# 设置非交互式环境变量，避免交互式配置提示
export DEBIAN_FRONTEND=noninteractive

# 安装企业微信
echo "正在安装企业微信..."
if sudo apt-get install com.qq.weixin.work.deepin -y; then
    echo "企业微信安装成功"
else
    echo "企业微信安装失败" >&2
    exit 1
fi

# 设置wxwork的启动脚本为可执行程序到环境变量
echo "正在配置企业微信启动脚本..."
if sudo tee /usr/bin/wxwork > /dev/null << 'EOF'
#!/bin/bash
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
/opt/apps/com.qq.weixin.work.deepin/files/run.sh
EOF
then
    echo "启动脚本创建成功"
else
    echo "启动脚本创建失败" >&2
    exit 1
fi

# 设置执行权限
if chmod +x /usr/bin/wxwork; then
    echo "启动脚本权限设置成功"
else
    echo "启动脚本权限设置失败" >&2
    exit 1
fi

# 验证安装
if command -v wxwork >/dev/null 2>&1; then
    echo "企业微信环境配置完成"
else
    echo "企业微信环境配置验证失败" >&2
    exit 1
fi

