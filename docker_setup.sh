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
apt install -y  ack antlr3 asciidoc autoconf automake autopoint binutils bison \
build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj \
fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf \
haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev \
libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs \
msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip \
python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons \
squashfs-tools subversion swig texinfo uglifyjs unzip vim wget xmlto \
xxd zlib1g-dev zstd cron


# 下载并安装 Alist
curl -fsSL "https://alist.nn.ci/v3.sh" | bash -s install

# 启动 Alist 并设置管理员密码
cd /opt/alist/ && ./alist start && ./alist admin set admin

# 创建用户 wrt，设置密码并添加到 sudo 组
useradd -m wrt && echo 'wrt:wrt' | chpasswd
usermod -aG sudo wrt

# 启动 SSH 守护进程
/usr/sbin/sshd -D
