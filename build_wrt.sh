#!/bin/bash
set -Eeuo pipefail

# ============== 配置 ==============
REPO_URL="https://github.com/immortalwrt/immortalwrt"
BRANCH="master"
CONFIG_URL="https://raw.githubusercontent.com/lonelysoul/immortalwrt/main/.config"
WORK_DIR="$HOME/immortalwrt"

# 至少留 1 核空闲；若只有 1 核则用 1
if command -v nproc >/dev/null 2>&1; then
  NPROC=$(nproc --ignore=1 2>/dev/null || nproc)
else
  NPROC=1
fi
[ -z "${NPROC:-}" ] || [ "$NPROC" -lt 1 ] && NPROC=1

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

# ============== 参数 ==============
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
      echo "  -r 删除源码并重新拉取后编译"
      exit 1
      ;;
  esac
done

# ============== 公共函数 ==============
trap 'echo "Error: 执行失败（行号 $LINENO）。"; exit 1' ERR

check_git_repo() {
  echo ">>> 检查 Git 仓库，当前目录: $(pwd)"
  if [ ! -d ".git" ]; then
    echo "Error: $WORK_DIR 不是 Git 仓库。可能 clone 失败或目录被手工创建。"
    echo "可用 -r 重置后重试：./$(basename "$0") -r"
    exit 1
  fi
}

install_dependencies() {
  echo ">>> 安装依赖包..."
  sudo DEBIAN_FRONTEND=noninteractive apt update
  sudo DEBIAN_FRONTEND=noninteractive apt install -y "${DEPENDENCIES[@]}"
}

clone_repo() {
  echo ">>> 克隆源码到 $WORK_DIR..."
  git clone -b "$BRANCH" --single-branch --filter=blob:none "$REPO_URL" "$WORK_DIR"
}

update_and_install_feeds() {
  echo ">>> 更新并安装 feeds..."
  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

download_config() {
  echo ">>> 下载配置文件到 $WORK_DIR/.config..."
  wget -O .config "$CONFIG_URL"
}

# ============== 初始化 ==============
# return 0 表示新仓库（需要编译），1 表示已存在
initialize() {
  local is_new=false

  if [ ! -w "$HOME" ]; then
    echo "Error: $HOME 不可写，请检查权限。"
    exit 1
  fi

  if [ "$DO_RESET" = true ] && [ -d "$WORK_DIR" ]; then
    echo ">>> 重置: 删除 $WORK_DIR..."
    rm -rf "$WORK_DIR"
  fi

  if [ ! -d "$WORK_DIR" ]; then
    is_new=true
    install_dependencies
    clone_repo
    cd "$WORK_DIR"
    update_and_install_feeds
    download_config
  else
    cd "$WORK_DIR"
    if [ ! -f ".config" ]; then
      download_config
    fi
  fi

  if [ "$is_new" = true ]; then
    return 0
  else
    return 1
  fi
}

# ============== 主流程 ==============
main() {
  echo ">>> 脚本运行，当前目录: $(pwd)"
  echo ">>> Git 仓库目录: $WORK_DIR"

  initialize
  if [ $? -eq 0 ]; then
    is_new=true
  else
    is_new=false
  fi

  cd "$WORK_DIR"
  check_git_repo

  echo ">>> 获取远端状态..."
  git remote set-url origin "$REPO_URL"  # 防止 URL 变更导致后续失败
  git fetch --prune --tags --force origin "$BRANCH"

  LOCAL=$(git rev-parse HEAD)
  REMOTE=$(git rev-parse "origin/$BRANCH")

  needs_build=false

  if [ "$is_new" = true ]; then
    needs_build=true
    echo ">>> 首次初始化，将进行编译。"
  fi

  if [ "$DO_RESET" = true ]; then
    needs_build=true
    echo ">>> 因使用 -r 重置源码，执行强制编译。"
  fi

  if [ "$LOCAL" != "$REMOTE" ]; then
    needs_build=true
    echo ">>> 检测到上游有更新。"
  fi

  if [ "$FORCE_COMPILE" = true ]; then
    needs_build=true
    echo ">>> 已开启 -f 强制编译。"
  fi

  if [ ! -d "bin/targets" ]; then
    needs_build=true
    echo ">>> 未发现历史构建产物，将进行编译。"
  fi

  if [ "$needs_build" = true ]; then
    start=$(date +%s)

    # 保持工作区与远端完全一致，避免 pull 产生 merge
    echo ">>> 同步到远端最新（强制硬重置）..."
    git reset --hard "origin/$BRANCH"

    update_and_install_feeds

    if [ "$DO_CLEAN" = true ]; then
      echo ">>> 执行 make clean..."
      make clean
    fi

    # 生成 .config 后再下载源码包
    echo ">>> make defconfig..."
    make defconfig

    echo ">>> 预下载依赖包..."
    make -j"$NPROC" download

    echo ">>> 开始编译..."
    make -j"$NPROC" V=s

    end=$(date +%s)
    echo ">>> 编译完成，总耗时：$(((end - start) / 60)) 分 $(((end - start) % 60)) 秒"
    echo ">>> $(date '+%Y-%m-%d %H:%M:%S'): 完成"

    # ====== 固件转换（自动探测 x86_64 efi 镜像）======
    echo ">>> 尝试转换 x86_64 EFI 镜像为 qcow2..."
    IMG_GZ="$(find bin/targets -type f -name '*x86-64*combined-efi*.img.gz' -print -quit || true)"
    if [ -n "${IMG_GZ:-}" ] && [ -f "$IMG_GZ" ]; then
      IMG_DIR="$(dirname "$IMG_GZ")"
      BASENAME="$(basename "$IMG_GZ" .gz)"
      (
        cd "$IMG_DIR"
        gunzip -c "$IMG_GZ" > disk.img
        qemu-img convert -f raw -O qcow2 disk.img "${BASENAME%.img}.qcow2"
        rm -f disk.img
      )
      echo ">>> 固件转换完毕：$(dirname "$IMG_GZ")/${BASENAME%.img}.qcow2"
    else
      echo ">>> 未找到 x86_64 EFI 压缩镜像，跳过转换（这是正常的，若目标非 x86_64 或未生成 EFI 固件）。"
    fi
  else
    echo ">>> 源码已是最新，且无强制条件，跳过编译。"
  fi
}

main
echo ">>> 脚本执行完成。"
