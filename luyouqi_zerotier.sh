#!/bin/bash

# ZeroTier自动安装和配置脚本
# 适用于ImmortalWrt系统

# 获取ZeroTier网络ID
if [ -z "$1" ]; then
    read -p "请输入ZeroTier网络ID: " ZEROTIER_NETWORK_ID
else
    ZEROTIER_NETWORK_ID="$1"
fi

# 更新opkg并安装ZeroTier
install_zerotier() {
    echo "正在更新软件包列表..."
    opkg update

    echo "尝试安装ZeroTier..."
    opkg install zerotier
    if [ $? -ne 0 ]; then
        echo "ZeroTier安装失败，请检查opkg配置或网络连接。"
        exit 1
    fi
}

# 检查是否支持IPv6
check_ipv6_support() {
    if ping6 -c 1 -W 1 ipv6.google.com &>/dev/null; then
        echo "IPv6支持正常。"
        CONTROLLER_ADDRESS="[240e:0974:eb00:0908:0000:0000:5064:007d]:19993"
    else
        echo "IPv6不可用。使用IPv4地址。"
        CONTROLLER_ADDRESS="110.40.75.160:19993"
    fi

    # 写入配置文件
    CONFIG_FILE="/etc/zerotier/config.json"
    mkdir -p $(dirname "$CONFIG_FILE")
    echo "{
    \"settings\": {
        \"controllerAddress\": \"$CONTROLLER_ADDRESS\"
    }
}" > "$CONFIG_FILE"
}

# 加入ZeroTier网络
join_zerotier_network() {
    echo "加入ZeroTier网络: $ZEROTIER_NETWORK_ID"
    zerotier-cli join $ZEROTIER_NETWORK_ID
    if [ $? -ne 0 ]; then
        echo "加入网络失败，请检查网络ID或安装状态。"
        exit 1
    fi
}

# 验证安装和网络状态
verify_installation() {
    echo "正在验证ZeroTier安装..."
    if ! command -v zerotier-cli &> /dev/null; then
        echo "ZeroTier未成功安装，请检查安装过程。"
        exit 1
    fi
}

# 设置开机启动
configure_startup() {
    echo "配置ZeroTier为开机启动..."
    /etc/init.d/zerotier enable
}

# 执行安装和配置步骤
install_zerotier
verify_installation
check_ipv6_support
configure_startup
/etc/init.d/zerotier start
join_zerotier_network

# 输出分配的IP地址
echo "以下是分配的网络信息："
zerotier-cli listnetworks

# 脚本结束
echo "ZeroTier安装和配置完成。"
