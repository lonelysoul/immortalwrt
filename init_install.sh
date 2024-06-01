#!/bin/bash

# 设置变量
REPO_URL="https://github.com/immortalwrt/immortalwrt"
BRANCH="master"
CONFIG_URL="https://raw.githubusercontent.com/lonelysoul/immortalwrt/main/.config"
SRC_DIR="immortalwrt"

# 保存当前目录
ORIGINAL_DIR=$(pwd)

# 更新包列表并安装依赖
sudo apt update
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5 \
libncursesw5-dev libpython3-dev libreadline-dev libssl-dev libtool lld llvm lrzsz mkisofs msmtp \
nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pip python3-ply \
python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig \
texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev

# 检查源码目录是否存在
if [ -d "$SRC_DIR" ]; then
  echo "目录 $SRC_DIR 已存在，跳过克隆步骤。"
else
  # 克隆源码
  git clone -b $BRANCH --single-branch --filter=blob:none $REPO_URL $SRC_DIR
fi

# 进入源码目录
cd $SRC_DIR

# 更新 feeds
./scripts/feeds update -a

# 安装 feeds
./scripts/feeds install -a

# 下载配置文件并覆盖
if [ -f ".config" ]; then
  echo ".config 文件已存在，将被覆盖。"
fi
wget -O .config $CONFIG_URL

# 补全配置
make defconfig

# 返回原目录
cd $ORIGINAL_DIR

# 提示完成
echo "初始化安装完成。"
