#!/bin/bash

# 配置
REPO_URL="https://github.com/immortalwrt/immortalwrt"
BRANCH="master"
CONFIG_URL="https://raw.githubusercontent.com/lonelysoul/immortalwrt/main/.config"
WORK_DIR="$HOME/immortalwrt"
NPROC=$(nproc --ignore=1 2>/dev/null || nproc)

DEPENDENCIES=(
  ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
  bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
  g++-multilib git libgnutls28-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
  libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
  libreadline-dev libssl-dev libtool libyaml-dev zlib1g-dev lld llvm lrzsz genisoimage msmtp nano \
  ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
  python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
  unzip vim wget xmlto xxd zstd
)

# 参数处理
FORCE_COMPILE=false
DO_CLEAN=false
DO_RESET=false
while getopts ":fcr" opt; do
  case ${opt} in
    f ) FORCE_COMPILE=true ;;
    c ) DO_CLEAN=true ;;
    r ) DO_RESET=true ;;
    \? )
      echo "无效参数: -$OPTARG"
      echo "用法: $0 [-f] [-c] [-r]"
      echo "  -f 即使源码无更新也强制编译"
      echo "  -c 编译前执行 make clean"
      echo "  -r 删除源码并重新拉取编译"
      exit 1
      ;;
  esac
done

# 检查命令是否成功
check_command_success() {
  if [ $? -ne 0 ]; then
    echo "Error: $1 failed. Exiting."
    exit 1
  fi
}

# 检查是否是 Git 仓库
check_git_repo() {
  echo ">>> 检查 Git 仓库，当前目录: $(pwd)"
  if [ ! -d ".git" ]; then
    echo "Error: $WORK_DIR is not a Git repository."
    echo "Possible causes: git clone failed, or directory was manually created."
    echo "Try running with -r to reset and re-clone: ./$(basename "$0") -r"
    exit 1
  fi
}

# 安装依赖
install_dependencies() {
  echo ">>> 安装依赖包..."
  sudo DEBIAN_FRONTEND=noninteractive apt update
  check_command_success "apt update"
  sudo DEBIAN_FRONTEND=noninteractive apt install -y "${DEPENDENCIES[@]}"
  check_command_success "apt install"
}

# 克隆源码
clone_repo() {
  echo ">>> 克隆源码到 $WORK_DIR..."
  git clone -b "$BRANCH" --single-branch --filter=blob:none "$REPO_URL" "$WORK_DIR"
  check_command_success "git clone"
}

# 更新和安装 feeds
update_and_install_feeds() {
  echo ">>> 更新并安装 feeds..."
  ./scripts/feeds update -a
  check_command_success "feeds update"
  ./scripts/feeds install -a
  check_command_success "feeds install"
}

# 下载配置文件
download_config() {
  echo ">>> 下载配置文件到 $WORK_DIR/.config..."
  wget -O .config "$CONFIG_URL"
  check_command_success "wget .config"
}

# 初始化
initialize() {
  local is_new=false

  # 检查 HOME 目录权限
  if [ ! -w "$HOME" ]; then
    echo "Error: $HOME is not writable. Check permissions."
    exit 1
  fi

  if [ "$DO_RESET" = true ] && [ -d "$WORK_DIR" ]; then
    echo ">>> 重置: 删除 $WORK_DIR..."
    rm -rf "$WORK_DIR"
    check_command_success "rm WORK_DIR"
  fi

  if [ ! -d "$WORK_DIR" ]; then
    is_new=true
    install_dependencies
    clone_repo
    cd "$WORK_DIR" || { echo "Error: Cannot access $WORK_DIR. Check permissions."; exit 1; }
    update_and_install_feeds
    download_config
  else
    cd "$WORK_DIR" || { echo "Error: Cannot access $WORK_DIR. Check permissions."; exit 1; }
    if [ ! -f ".config" ]; then
      download_config
    fi
  fi

  echo "$is_new"
}

# 主逻辑
main() {
  echo ">>> 脚本运行，当前目录: $(pwd)"
  echo ">>> Git 仓库目录: $WORK_DIR"

  local is_new=$(initialize)

  # 确保在 WORK_DIR 中执行 Git 操作
  cd "$WORK_DIR" || { echo "Error: Cannot access $WORK_DIR. Check permissions."; exit 1; }

  # 检查是否是 Git 仓库
  check_git_repo

  echo ">>> 检查源码更新..."
  git fetch origin
  check_command_success "git fetch"
  LOCAL=$(git rev-parse HEAD)
  REMOTE=$(git rev-parse origin/$BRANCH)

  if [ "$is_new" = true ] || [ "$LOCAL" != "$REMOTE" ] || [ "$FORCE_COMPILE" = true ]; then
    if [ "$is_new" = true ]; then
      echo ">>> 首次初始化，强制编译。"
    elif [ "$FORCE_COMPILE" = true ]; then
      echo ">>> 强制编译模式已开启。"
    else
      echo ">>> 源码已更新。"
    fi

    start=$(date +%s)

    git pull origin "$BRANCH"
    check_command_success "git pull"

    update_and_install_feeds

    if [ "$DO_CLEAN" = true ]; then
      echo ">>> 执行 make clean..."
      make clean
      check_command_success "make clean"
    fi

    make -j"$NPROC" download
    check_command_success "make download"

    make defconfig
    check_command_success "make defconfig"

    make -j"$NPROC" V=s
    check_command_success "make compile"

    end=$(date +%s)
    echo ">>> 编译完成，总耗时：$(((end - start) / 60)) 分 $(((end - start) % 60)) 秒"
    echo ">>> $(date '+%Y-%m-%d %H:%M:%S'): 完成"

    cd bin/targets/x86/64 
    gunzip -c immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz > ./disk.img && \
    qemu-img convert -f raw -O qcow2 ./disk.img immortalwrt-x86-64-generic-squashfs-combined-efi.qcow2 && \
    rm ./disk.img 
    echo ">>> 固件转换完毕" 

else
    echo ">>> 源码已是最新，无需编译。"
  fi
}

main
echo ">>> 脚本执行完成。"
