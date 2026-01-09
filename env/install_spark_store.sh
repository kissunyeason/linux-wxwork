#!/bin/bash
set -e

# 设置非交互式环境变量，避免交互式配置提示
export DEBIAN_FRONTEND=noninteractive


# 下载并安装 Spark Store 补丁包
echo "正在下载并安装 Spark Store 补丁包..."
wget https://gitcode.com/spark-store-project/spark-store/releases/download/4.8.3/spark-store_4.8.3_amd64.deb -O /tmp/spark-store_4.8.3_amd64.deb
apt-get install -y /tmp/spark-store_4.8.3_amd64.deb
rm -f /tmp/spark-store_4.8.3_amd64.deb

echo "Spark Store 补丁包安装完成"







