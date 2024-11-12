#!/bin/bash

# 检查是否有参数传入
if [ "$1" == "-6" ]; then
    echo "选择了 IPv6 模式"
    IP_FLAG="-6"
else
    echo "选择了 IPv4 模式"
    IP_FLAG="-4"
fi

echo "安装 Docker"
curl $IP_FLAG -fsSL https://get.docker.com -o get-docker.sh \
&& sudo sh get-docker.sh

if [ $? -ne 0 ]; then
    echo "Docker 安装失败"
    exit 1
fi

echo "安装 Docker Compose"
sudo curl $IP_FLAG -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
&& sudo chmod +x /usr/local/bin/docker-compose

if [ ! -f /usr/local/bin/docker-compose ]; then
    echo "Docker Compose 安装失败"
    exit 1
fi

echo "下载文件"
wget $IP_FLAG https://github.com/NiuStar/vps_docker/raw/main/docker.zip
if [ $? -ne 0 ]; then
    echo "文件下载失败"
    exit 1
fi

apt install -y unzip
unzip docker.zip

if [ ! -d "docker/x-ui" ]; then
    echo "x-ui 目录不存在"
    exit 1
fi

cd docker/x-ui && docker-compose up -d

if [ $? -ne 0 ]; then
    echo "Docker Compose 启动失败"
    exit 1
fi

chmod +x sshport.sh && sshport.sh

wget $IP_FLAG -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
