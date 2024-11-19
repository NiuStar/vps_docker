#!/bin/bash

# 确保以 root 用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行此脚本。"
  exit 1
fi

# 定义需要强制使用 IPv4 的网站
WEBSITES=("chatgpt.com" "chat.openai.com")

# 配置 IPv4 优先的 hosts 文件
HOSTS_FILE="/etc/hosts"

# 备份原始 hosts 文件
if [ ! -f "$HOSTS_FILE.bak" ]; then
  cp "$HOSTS_FILE" "$HOSTS_FILE.bak"
  echo "已备份 /etc/hosts 为 /etc/hosts.bak。"
fi

# 遍历网站，获取其 IPv4 地址并更新 hosts 文件
for SITE in "${WEBSITES[@]}"; do
  echo "正在解析 $SITE 的 IPv4 地址..."
  IPV4_ADDR=$(dig +short A "$SITE" | head -n 1)

  if [ -z "$IPV4_ADDR" ]; then
    echo "无法解析 $SITE 的 IPv4 地址，跳过..."
    continue
  fi

  # 检查是否已存在旧记录并替换
  grep -q "$SITE" "$HOSTS_FILE" && sed -i "/$SITE/d" "$HOSTS_FILE"

  # 添加新的 IPv4 地址到 hosts 文件
  echo "$IPV4_ADDR $SITE" >> "$HOSTS_FILE"
  echo "$SITE 已绑定到 IPv4 地址 $IPV4_ADDR。"
done

# 显示更新后的 hosts 文件内容
echo "更新后的 /etc/hosts 内容："
cat "$HOSTS_FILE"

# 提示用户刷新 DNS 缓存
if command -v systemctl &>/dev/null && systemctl is-active systemd-resolved &>/dev/null; then
  echo "正在刷新 DNS 缓存..."
  systemctl restart systemd-resolved
  echo "DNS 缓存已刷新。"
else
  echo "请手动刷新 DNS 缓存，或重启网络服务以应用更改。"
fi

echo "强制 IPv4 设置完成。"
