#!/bin/sh

# 设置时区为 Asia/Shanghai
export TZ="Asia/Shanghai"

# ==============================
# ImmortalWRT 自动化编译脚本
# ==============================

# 设置全局变量
REPO_URL="https://github.com/immortalwrt/immortalwrt"
BRANCH="master"
CONFIG_URL="https://raw.githubusercontent.com/lonelysoul/immortalwrt/main/.config"
SRC_DIR=~/immortalwrt
DEPENDENCIES=(ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
  bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
  g++-multilib git libgnutls28-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
  libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
  libreadline-dev libssl-dev libtool libyaml-dev zlib1g-dev lld llvm lrzsz genisoimage msmtp nano \
  ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
  python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
  unzip vim wget xmlto xxd zlib1g-dev zstd)

# 函数：检查命令是否成功执行
check_command_success() {
  if [ $? -ne 0 ]; then
    echo "Error: $1 failed. Exiting."
    exit 1
  fi
}

# 函数：初始化环境
initialize_environment() {
  echo "开始初始化环境..."
  sudo DEBIAN_FRONTEND=noninteractive apt update && sudo apt install -y "${DEPENDENCIES[@]}"
  check_command_success "安装依赖包"
  echo "环境初始化完成。"
}

# 函数：克隆源码
clone_repo() {
  if [ -d "$SRC_DIR" ]; then
    echo "目录 $SRC_DIR 已存在，跳过克隆步骤。"
  else
    git clone -b $BRANCH --single-branch --filter=blob:none $REPO_URL $SRC_DIR
    check_command_success "克隆源码"
  fi
}

# 函数：更新和安装 feeds
update_and_install_feeds() {
  cd $SRC_DIR || exit
  ./scripts/feeds update -a
  check_command_success "更新 feeds"
  ./scripts/feeds install -a
  check_command_success "安装 feeds"
}

# 函数：下载并覆盖配置文件
download_config() {
  cd $SRC_DIR || exit
  if [ -f ".config" ]; then
    echo ".config 文件已存在，将被覆盖。"
  fi
  wget -O .config $CONFIG_URL
  make defconfig
  check_command_success "下载配置文件"
}

# 函数：编译源码
compile_source() {
  cd $SRC_DIR || exit
  echo "开始编译源码..."
  start=$(date +%s)
  make -j$(nproc) download
  check_command_success "下载软件包"
  make -j$(nproc)
  check_command_success "编译源码"
  end=$(date +%s)
  echo "编译完成，总耗时：$(((end - start) / 60)) 分 $(((end - start) % 60)) 秒"
}

# 主流程
main() {
  echo "==== 初始化环境 ===="
  initialize_environment
  echo "==== 克隆源码 ===="
  clone_repo
  echo "==== 更新 feeds 并安装 ===="
  update_and_install_feeds
  echo "==== 下载配置文件 ===="
  download_config
  echo "==== 开始编译 ===="
  compile_source
}

# 执行主流程
main
