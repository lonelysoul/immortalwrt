#!/bin/bash
apt-get update
apt-get install -y ssh build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget

USERNAME="wrt"
PASSWORD="wrt"

# 创建用户
useradd -m -s /bin/bash "$USERNAME"

# 设置密码（非交互）
echo "${USERNAME}:${PASSWORD}" | chpasswd

# 加入 sudo 组
usermod -aG sudo "$USERNAME"

echo "用户创建完成"