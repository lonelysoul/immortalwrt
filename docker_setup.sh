#!/bin/bash
set -e  # 遇到错误时停止执行

# 设置时区为 Asia/Shanghai
export TZ="Asia/Shanghai"

echo 'apparmor apparmor/enable boolean false' | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive

# 更新软件包索引并安装 openssh-server 和 sudo
apt update && apt install -y openssh-server sudo

# 创建 SSH 守护进程所需的目录
mkdir -p /run/sshd

# 设置 root 用户密码
echo 'root:root' | chpasswd

# 安装开发和编译相关的工具
apt install -y curl wget

# 下载并安装 Alist
curl -fsSL "https://alist.nn.ci/v3.sh" | bash -s install

# 启动 Alist 并设置管理员密码
cd /opt/alist/ && ./alist start && ./alist admin set admin

# 创建用户 wrt，设置密码并添加到 sudo 组
useradd -m wrt && echo 'wrt:wrt' | chpasswd
usermod -aG sudo wrt

# 启动 SSH 守护进程
/usr/sbin/sshd -D &

# 输出文件执行完毕的提示
echo "文件执行完毕"
