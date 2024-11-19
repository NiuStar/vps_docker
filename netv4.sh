#!/bin/bash

# 检查是否有 root 权限
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本。"
  exit 1
fi

# 设置 IPv4 优先的内核参数
echo "开始设置系统以优先使用 IPv4..."

# 修改 sysctl 配置文件以永久生效
grep -q "^precedence ::ffff:0:0/96" /etc/gai.conf
if [ $? -ne 0 ]; then
  echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
  echo "已更新 /etc/gai.conf 以优先使用 IPv4。"
else
  echo "/etc/gai.conf 已配置为优先使用 IPv4，无需更改。"
fi

# 立即生效（确保现有连接也使用 IPv4 优先）
sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.default.disable_ipv6=0

# 提示用户重启网络服务
read -p "是否重启网络服务以确保设置生效？[y/N] " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  systemctl restart networking || service network-manager restart
  echo "网络服务已重启。"
else
  echo "请手动重启网络服务以应用更改。"
fi

# 显示当前优先级和配置
if [ -f /etc/gai.conf ]; then
  echo "当前 gai.conf 配置如下："
  grep "precedence" /etc/gai.conf
fi

echo "IPv4 优先设置已完成。"
