#!/bin/bash

# ZeroTier自动安装和配置脚本
# 适用于Debian/Ubuntu和CentOS系统的自动安装脚本
# 适用于各个服务器上的通用脚本，便于自动化安装和加入网络

# 获取ZeroTier网络ID
if [ -z "$1" ]; then
    read -p "请输入ZeroTier网络ID: " ZEROTIER_NETWORK_ID
else
    ZEROTIER_NETWORK_ID="$1"
fi

# 检查当前操作系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法确定操作系统类型。"
    exit 1
fi

# 安装ZeroTier
install_zerotier() {
    case "$OS" in
        ubuntu|debian)
            echo "正在安装ZeroTier for Debian/Ubuntu..."
            curl -s https://install.zerotier.com | sudo bash
            ;;
        centos|rhel)
            echo "正在安装ZeroTier for CentOS/RHEL..."
            yum install -y epel-release
            curl -s https://install.zerotier.com | sudo bash
            ;;
        *)
            echo "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 加入ZeroTier网络
join_zerotier_network() {
    echo "加入ZeroTier网络: $ZEROTIER_NETWORK_ID"
    sudo zerotier-cli join $ZEROTIER_NETWORK_ID
}

# 验证ZeroTier安装状态
verify_installation() {
    if ! command -v zerotier-cli &> /dev/null
    then
        echo "ZeroTier未成功安装，请检查安装过程。"
        exit 1
    fi
}

# 验证节点加入状态
verify_network_join() {
    echo "正在检查ZeroTier网络状态..."
    sleep 5
    zerotier-cli listnetworks | grep $ZEROTIER_NETWORK_ID &> /dev/null
    if [ $? -eq 0 ]; then
        echo "成功加入ZeroTier网络: $ZEROTIER_NETWORK_ID"
    else
        echo "未能成功加入网络，请检查网络ID和网络连接。"
        exit 1
    fi
}

# 设置系统启动后自动加入ZeroTier网络
configure_startup() {
    echo "配置系统重启后自动加入ZeroTier网络..."
    crontab -l > mycron
    echo "@reboot /usr/sbin/zerotier-one & sleep 10 && sudo zerotier-cli join $ZEROTIER_NETWORK_ID" >> mycron
    crontab mycron
    rm mycron
}

# 执行安装和配置步骤
install_zerotier
verify_installation
join_zerotier_network
verify_network_join
configure_startup

systemctl start zerotier-one
systemctl enable zerotier-one

# 输出分配的IP地址
zerotier-cli listnetworks

# 脚本结束
echo "ZeroTier安装和配置完成。"
