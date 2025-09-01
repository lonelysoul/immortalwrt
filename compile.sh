#!/usr/bin/env bash
#
# build_immortalwrt.sh
#
# 功能概述：
# 1) 首次运行：安装依赖 -> 克隆源码 -> 更新/安装 feeds -> 下载指定 .config -> 编译 -> 产物转换为 qcow2
# 2) 日常运行：检测上游是否有更新；若有 -> 拉取 -> 同上编译与转换；若无 -> 直接退出（除非 -f/-c/-r）
# 3) 提供三种模式：
#    -f  强制更新、编译、转换（不 clean）
#    -c  先 make clean 再强制更新、编译、转换
#    -r  移除工作目录后，重新克隆、下载配置、编译、转换
#
# 退出码：
#  0 正常结束；非 0 表示发生错误。
#
# 注意：脚本假设在 Debian/Ubuntu 系（使用 apt），并以当前用户身份运行；需要安装依赖时将调用 sudo。

set -euo pipefail

########################################
# 用户配置（按你的给定值）
########################################
REPO_URL="https://github.com/immortalwrt/immortalwrt"
BRANCH="master"
CONFIG_URL="https://raw.githubusercontent.com/lonelysoul/immortalwrt/main/.config"
WORK_DIR="${HOME}/immortalwrt"

# 依赖包（Debian/Ubuntu）
DEPENDENCIES=(
  ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential
  bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib
  g++-multilib git libgnutls28-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev
  libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev
  libreadline-dev libssl-dev libtool libyaml-dev zlib1g-dev lld llvm lrzsz genisoimage msmtp nano
  ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils
  python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs
  unzip vim wget xmlto xxd zstd
)

########################################
# 全局变量/工具
########################################
SCRIPT_NAME="$(basename "$0")"
NPROC="$(command -v nproc >/dev/null 2>&1 && nproc || sysctl -n hw.ncpu 2>/dev/null || echo 1)"
TARGET_SUBDIR="bin/targets/x86/64"

# 彩色输出（若终端支持）
if [ -t 1 ]; then
  C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_RED='\033[0;31m'; C_BLUE='\033[0;34m'; C_RESET='\033[0m'
else
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_BLUE=''; C_RESET=''
fi

log()  { echo -e "${C_BLUE}[$(date '+%F %T')]${C_RESET} $*"; }
ok()   { echo -e "${C_GREEN}[OK]${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
err()  { echo -e "${C_RED}[ERR]${C_RESET} $*" >&2; }

usage() {
  cat <<EOF
用法：$SCRIPT_NAME [-f | -c | -r | -h]

无参数：自动模式（仅当上游有更新时才拉取并编译）
  -f    强制更新、编译、转换（不 clean）
  -c    make clean 后强制更新、编译、转换
  -r    删除工作目录，重新克隆后编译、转换
  -h    显示本帮助
EOF
}

########################################
# 前置检查 & 依赖安装
########################################
install_deps() {
  log "检查并安装依赖（需要 sudo）..."
  if ! command -v sudo >/dev/null 2>&1; then
    warn "未找到 sudo，尝试直接使用 apt-get。"
    APT="apt-get"
  else
    APT="sudo apt-get"
  fi

  set +e
  $APT update -y
  $APT install -y "${DEPENDENCIES[@]}"
  if [ $? -ne 0 ]; then
    warn "安装依赖出错，尝试 ack-grep 替换 ack..."
    local deps2=()
    for pkg in "${DEPENDENCIES[@]}"; do
      if [ "$pkg" = "ack" ]; then deps2+=("ack-grep"); else deps2+=("$pkg"); fi
    done
    $APT install -y "${deps2[@]}" || { err "依赖安装失败。"; exit 1; }
  fi
  set -e
  ok "依赖就绪。"
}

########################################
# Git 相关
########################################
clone_repo() {
  log "克隆仓库 ${REPO_URL} (branch: ${BRANCH}) 到 ${WORK_DIR} ..."
  git clone -b "${BRANCH}" --single-branch --filter=blob:none "${REPO_URL}" "${WORK_DIR}"
  ok "克隆完成。"
}

ensure_repo() {
  if [ ! -d "${WORK_DIR}/.git" ]; then
    mkdir -p "${WORK_DIR%/*}"
    clone_repo
    return
  fi
}

git_fetch_remote() {
  ( cd "${WORK_DIR}" && git remote set-url origin "${REPO_URL}" && git fetch --prune origin "${BRANCH}" )
}

has_upstream_update() {
  ( cd "${WORK_DIR}" && git_fetch_remote >/dev/null 2>&1 && \
    ! git merge-base --is-ancestor "origin/${BRANCH}" HEAD )
}

pull_fast_forward() {
  ( cd "${WORK_DIR}" && git pull --ff-only origin "${BRANCH}" )
}

hard_reset_to_remote() {
  ( cd "${WORK_DIR}" && git fetch origin "${BRANCH}" && git reset --hard "origin/${BRANCH}" && git clean -fdx )
}

########################################
# 编译流程
########################################
prepare_feeds() {
  log "更新并安装 feeds ..."
  ( cd "${WORK_DIR}" && ./scripts/feeds update -a && ./scripts/feeds install -a )
  ok "feeds 就绪。"
}

download_config() {
  log "下载 .config -> ${WORK_DIR}/.config"
  ( cd "${WORK_DIR}" && rm -f .config && wget -O .config "${CONFIG_URL}" )
  ( cd "${WORK_DIR}" && make defconfig )
  ok ".config 已应用。"
}

maybe_clean() {
  log "执行 make clean ..."
  ( cd "${WORK_DIR}" && make clean )
  ok "clean 完成。"
}

do_build() {
  log "执行 make download（下载依赖包）..."
  ( cd "${WORK_DIR}" && make download -j"${NPROC}" ) || { err "make download 失败"; exit 1; }
  ok "download 完成。"

  log "开始编译（并行：${NPROC}）..."
  set +e
  ( cd "${WORK_DIR}" && make -j"${NPROC}" )
  local rc=$?
  if [ $rc -ne 0 ]; then
    warn "并行编译失败，切换单线程详细模式..."
    ( cd "${WORK_DIR}" && make -j1 V=s )
    rc=$?
  fi
  set -e
  [ $rc -eq 0 ] || { err "编译失败"; exit 1; }
  ok "编译成功。"
}

convert_artifacts() {
  log "转换镜像为 qcow2 ..."
  local target="${WORK_DIR}/${TARGET_SUBDIR}"
  local img_gz
  img_gz="$(ls -t "${target}"/*combined-efi*.img.gz 2>/dev/null | head -n1 || true)"
  if [ -z "${img_gz}" ]; then
    err "未找到 *combined-efi*.img.gz"
    exit 1
  fi
  local work_img="${target}/disk.img"
  local qcow2="${img_gz%.img.gz}.qcow2"
  gunzip -c "${img_gz}" > "${work_img}"
  qemu-img convert -f raw -O qcow2 "${work_img}" "${qcow2}"
  rm -f "${work_img}"
  ln -sf "$(basename "${qcow2}")" "${target}/immortalwrt-latest.qcow2"
  ok "转换完成：${qcow2}"
}

########################################
# 主流程
########################################
MODE="auto"
while getopts ":fcrh" opt; do
  case "$opt" in
    f) MODE="force" ;;
    c) MODE="clean_force" ;;
    r) MODE="reset" ;;
    h) usage; exit 0 ;;
    \?) err "非法参数 -$OPTARG"; usage; exit 2 ;;
  esac
done

main() {
  install_deps

  case "${MODE}" in
    reset)
      rm -rf "${WORK_DIR}"
      clone_repo
      prepare_feeds
      download_config
      do_build
      convert_artifacts
      ;;
    clean_force)
      ensure_repo
      hard_reset_to_remote
      prepare_feeds
      download_config
      maybe_clean
      do_build
      convert_artifacts
      ;;
    force)
      ensure_repo
      hard_reset_to_remote
      prepare_feeds
      download_config
      do_build
      convert_artifacts
      ;;
    auto)
      if [ ! -d "${WORK_DIR}/.git" ]; then
        clone_repo
        prepare_feeds
        download_config
        do_build
        convert_artifacts
      elif has_upstream_update; then
        pull_fast_forward
        prepare_feeds
        download_config
        do_build
        convert_artifacts
      else
        ok "无更新，跳过编译"
      fi
      ;;
  esac
}

main "$@"
