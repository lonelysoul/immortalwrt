#!/bin/bash

# 声明关联数组
declare -A CONFIG=(
  ["REPO_URL"]="https://github.com/immortalwrt/immortalwrt"  # 仓库地址
  ["BRANCH"]="master"                                        # 分支名称
  ["CONFIG_URL"]="https://raw.githubusercontent.com/lonelysoul/immortalwrt/main/.config"  # 配置文件地址
  ["SRC_DIR"]="$HOME/immortalwrt"                            # 源码目录
  ["FORCE_COMPILE"]="false"                                  # 是否强制编译
  ["INIT_DONE_FLAG"]="${HOME}/immortalwrt/.init_done"        # 初始化完成标志文件
)

# 依赖包列表
DEPENDENCIES=(
  ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential
  bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib
  g++-multilib git libgnutls28-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev
  libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev
  libreadline-dev libssl-dev libtool libyaml-dev zlib1g-dev lld llvm lrzsz genisoimage msmtp nano
  ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils
  python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs
  unzip vim wget xmlto xxd zlib1g-dev zstd
)

# 检查命令执行是否成功
check_command_success() {
  if [ $? -ne 0 ]; then
    echo "错误：$1 失败，退出脚本。"
    exit 1
  fi
}

# 安装依赖包
install_dependencies() {
  echo "正在更新包列表并安装依赖..."
  sudo DEBIAN_FRONTEND=noninteractive apt update
  check_command_success "更新包列表"
  sudo DEBIAN_FRONTEND=noninteractive apt install -y "${DEPENDENCIES[@]}"
  check_command_success "安装依赖"
}

# 克隆源码
clone_repo() {
  if [ -d "${CONFIG[SRC_DIR]}" ]; then
    echo "源码目录 ${CONFIG[SRC_DIR]} 已存在，跳过克隆。"
  else
    echo "正在克隆 ImmortalWrt 源码..."
    git clone -b "${CONFIG[BRANCH]}" --single-branch --filter=blob:none "${CONFIG[REPO_URL]}" "${CONFIG[SRC_DIR]}"
    check_command_success "克隆源码"
  fi
}

# 更新并安装 feeds
update_and_install_feeds() {
  echo "正在更新并安装 feeds..."
  ./scripts/feeds update -a
  check_command_success "更新 feeds"
  ./scripts/feeds install -a
  check_command_success "安装 feeds"
}

# 下载配置文件
download_config() {
  echo "正在下载配置文件..."
  if [ -f ".config" ]; then
    echo "警告：.config 文件已存在，将被覆盖。"
  fi
  wget -O .config "${CONFIG[CONFIG_URL]}"
  check_command_success "下载配置文件"
}

# 初始化环境
initialize() {
  echo "开始初始化编译环境..."
  install_dependencies
  clone_repo
  cd "${CONFIG[SRC_DIR]}" || { echo "无法切换到目录 ${CONFIG[SRC_DIR]}"; exit 1; }
  update_and_install_feeds
  download_config
  # 创建初始化完成标志
  touch "${CONFIG[INIT_DONE_FLAG]}"
  check_command_success "创建初始化完成标志"
  echo "初始化完成。"
}

# 编译固件
compile_firmware() {
  echo "检查源码更新..."
  git fetch origin
  check_command_success "获取远程仓库信息"
  LOCAL=$(git rev-parse HEAD)
  REMOTE=$(git rev-parse "origin/${CONFIG[BRANCH]}")

  if [ "$LOCAL" != "$REMOTE" ] || [ "${CONFIG[FORCE_COMPILE]}" = true ]; then
    if [ "${CONFIG[FORCE_COMPILE]}" = true ]; then
      echo "检测到强制编译选项，将重新编译。"
    else
      echo "检测到源码更新，将重新编译。"
    fi

    # 开始计时
    start=$(date +%s)

    echo "正在拉取最新源码..."
    git pull origin "${CONFIG[BRANCH]}"
    check_command_success "拉取源码"

    update_and_install_feeds

    echo "正在下载软件包..."
    make -j"${NPROC:-$(nproc)}" download
    check_command_success "下载软件包"

    echo "正在执行 make defconfig..."
    make defconfig
    check_command_success "make defconfig"

    echo "开始编译固件..."
    make -j"${NPROC:-$(nproc --ignore=1)}"
    check_command_success "编译固件"

    # 计算并输出编译耗时
    end=$(date +%s)
    duration=$((end - start))
    echo "编译完成，总耗时：$((duration / 60)) 分 $((duration % 60)) 秒"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): 编译完成"
  else
    echo "源码已是最新，无需重新编译。"
  fi
}

# 主函数
main() {
  # 保存当前目录
  ORIGINAL_DIR=$(pwd)

  # 处理命令行参数
  while getopts ":c" opt; do
    case ${opt} in
      c)
        CONFIG[FORCE_COMPILE]=true
        ;;
      \?)
        echo "错误：无效的选项 -$OPTARG" >&2
        exit 1
        ;;
    esac
  done

  # 检查是否已完成初始化
  if [ ! -f "${CONFIG[INIT_DONE_FLAG]}" ]; then
    initialize
  else
    echo "检测到已完成初始化，跳过依赖安装和初始配置步骤。"
    cd "${CONFIG[SRC_DIR]}" || { echo "无法切换到目录 ${CONFIG[SRC_DIR]}"; exit 1; }
  fi

  # 执行编译
  compile_firmware

  # 返回原目录
  cd "$ORIGINAL_DIR" || { echo "无法返回原目录 $ORIGINAL_DIR"; exit 1; }
  echo "脚本执行完成。"
}

# 执行主函数
main
