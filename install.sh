#!/bin/bash

# 检查是否有参数传入
if [ "$1" == "-6" ]; then
    echo "选择了 IPv6 模式"
    IP_FLAG="-6"
else
    echo "选择了 IPv4 模式"
    IP_FLAG="-4"
fi

echo "安装docker"
curl $IP_FLAG -fsSL https://test.docker.com -o test-docker.sh \
&& sudo sh test-docker.sh \
&& sudo curl $IP_FLAG -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
&& sudo chmod +x /usr/local/bin/docker-compose

#echo "安装portainer"
#docker run -d -p 19001:9000 -p 19002:9001 --restart=always -v /var/run/docker.sock:/var/run/docker.sock --name portainer portainer/portainer-ce

echo "下载文件"
wget $IP_FLAG https://github.com/NiuStar/vps_docker/raw/main/docker.zip
apt install -y unzip
unzip docker.zip

cd docker/x-ui && docker-compose up -d
