#!/usr/bin/env bash
#
# build_immortalwrt.sh
#
# 功能：
#   - 根据用户指定的模式执行 immortalwrt 的编译流程（首次安装、常规编译、强制编译、清理重编译、重新拉取编译）
#   - 首次 clone 时安装 apt 依赖（仅当工作目录中没有目标 repo 时才安装）
#   - 支持参数化：工作目录、分支、jobs、config URL、是否跳过依赖安装、强制编译(-f)、清理(-c)、重新拉取(-r)、保留/覆盖 .config 等
#   - 在每次 make 前执行 make download -j${JOBS}
#   - 自动查找并解压/转换生成的 gz 镜像为 qcow2（如果存在）
#   - 输出丰富的过程信息，便于调试和日志采集
#
# 使用：
#   ./build_immortalwrt.sh [--work-dir DIR] [--branch BRANCH] [--config-url URL] [--jobs N]
#                           [-f|--force] [-c|--clean] [-r|--reclone] [--no-deps] [--force-config]
#                           [--menuconfig]
#
# 默认值已在脚本开头设置，按需覆盖命令行参数。
#
# 注意：脚本设置了 set -euo pipefail；关键步骤失败会退出并打印原因。
#

set -euo pipefail
IFS=$'\n\t'

# -------------------- 默认参数（可被命令行覆盖） --------------------
WORK_DIR="${HOME}"                                    # 默认工作目录（非 root 用户的家目录）
REPO_URL="https://github.com/immortalwrt/immortalwrt"
BRANCH="master"
REPO_DIR_NAME="immortalwrt"
REPO_PATH="${WORK_DIR}/${REPO_DIR_NAME}"
CONFIG_URL="https://raw.githubusercontent.com/lonelysoul/immortalwrt/main/.config"
JOBS="$(nproc)"                                       # 并行编译线程
SKIP_DEPS=0                                           # 是否跳过 apt 依赖安装（0/1）
FORCE_BUILD=0                                         # -f 强制构建（即使无更新也编译）
CLEAN_BUILD=0                                         # -c make clean 后构建
RECLONE=0                                             # -r 重新 clone 并构建
FORCE_CONFIG=0                                        # 是否覆盖本地 .config（默认否；仅在 reclone 或首次 clone 时拉取）
MENUCONFIG=0                                          # 是否在构建前触发 make menuconfig
VERBOSE=1                                             # 是否输出更详细日志
# 目标子目录（根据你给的示例）
TARGET_SUBPATH="bin/targets/x86/64"
IMG_GLOB="*squashfs-combined-efi.img.gz"              # 镜像匹配模式（可按需修改）
# apt 依赖（与你给的列表尽量一致）
APT_PKGS=(ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
  bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
  g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
  libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
  libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano \
  ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
  python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
  upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd)

LOG_PREFIX="[build_immortalwrt]"

# -------------------- 帮助信息 --------------------
usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --work-dir DIR         工作目录（默认: ${WORK_DIR})
  --branch BR            Git 分支（默认: ${BRANCH})
  --config-url URL       .config 下载地址（默认: ${CONFIG_URL})
  --jobs N               make 并行作业数（默认: ${JOBS})
  --no-deps              跳过首次依赖安装（默认: false）
  -f, --force            强制编译（即使无更新也继续）
  -c, --clean            在构建前执行 make clean（相当于 -c）
  -r, --reclone          删除并重新 clone（相当于 -r）
  --force-config         覆盖本地 .config（仅在 clone 或 reclone 时候有效）
  --menuconfig           在构建前交互运行 make menuconfig（若需要手动调整）
  -h, --help             显示此帮助
EOF
  exit 1
}

# -------------------- 日志打印 --------------------
log() { echo "${LOG_PREFIX} $*"; }
die() { echo "${LOG_PREFIX} ERROR: $*" >&2; exit 1; }
debug() { if [ "${VERBOSE}" -ne 0 ]; then echo "${LOG_PREFIX} DEBUG: $*"; fi }

# -------------------- 参数解析 --------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --work-dir) WORK_DIR="$(realpath "$2")"; REPO_PATH="${WORK_DIR}/${REPO_DIR_NAME}"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    --config-url) CONFIG_URL="$2"; shift 2;;
    --jobs) JOBS="$2"; shift 2;;
    --no-deps) SKIP_DEPS=1; shift;;
    -f|--force) FORCE_BUILD=1; shift;;
    -c|--clean) CLEAN_BUILD=1; shift;;
    -r|--reclone) RECLONE=1; shift;;
    --force-config) FORCE_CONFIG=1; shift;;
    --menuconfig) MENUCONFIG=1; shift;;
    -h|--help) usage; shift;;
    *) echo "Unknown option: $1"; usage; shift;;
  esac
done

# -------------------- 预检 --------------------
if [ "$(id -u)" -eq 0 ]; then
  log "Warning: 你正在以 root 用户运行脚本。建议以普通用户运行（脚本会在需要 sudo 的地方调用）。"
fi

log "工作目录: ${WORK_DIR}"
log "目标仓库: ${REPO_URL}  分支: ${BRANCH}"
log "并行作业数: ${JOBS}"
log "REPO_PATH: ${REPO_PATH}"
debug "CONFIG_URL: ${CONFIG_URL}"

# 确保工作目录存在
mkdir -p "${WORK_DIR}"

# -------------------- 子函数: 安装依赖 --------------------
install_deps() {
  if [ "${SKIP_DEPS}" -ne 0 ]; then
    log "跳过依赖安装（--no-deps 指定）"
    return 0
  fi

  log "检测并安装系统依赖（sudo apt update && apt install ...） —— 仅在首次 clone 时执行"
  echo "将要安装如下 apt 包（若某些包名在你的系统上不存在，apt 会提示错误）："
  echo "${APT_PKGS[*]}"
  log "开始 apt update..."
  sudo apt update -y || die "apt update 失败，请检查网络或 apt 源"
  log "开始 apt full-upgrade..."
  sudo apt full-upgrade -y || die "apt full-upgrade 失败"
  log "开始安装 apt 包..."
  sudo apt install -y "${APT_PKGS[@]}" || {
    die "apt install 失败。注意：不同 Debian/Ubuntu 版本个别包名会不同。请手动检查并安装缺失的包。"
  }
  log "依赖安装完成。"
}

# -------------------- 子函数: clone 仓库 --------------------
clone_repo() {
  log "开始 clone 仓库到 ${REPO_PATH} （分支 ${BRANCH}）"
  rm -rf "${REPO_PATH}"
  git clone -b "${BRANCH}" --single-branch --filter=blob:none "${REPO_URL}" "${REPO_PATH}" || die "git clone 失败"
  log "clone 完成"
  if [ "${FORCE_CONFIG}" -ne 0 ]; then
    log "拉取 .config（--force-config 指定）: ${CONFIG_URL}"
    wget -O "${REPO_PATH}/.config" "${CONFIG_URL}" || die ".config 下载失败"
  fi
}

# -------------------- 子函数: fetch & 判断是否有更新 --------------------
fetch_and_check_updates() {
  cd "${REPO_PATH}"
  log "git fetch origin ${BRANCH} ..."
  git fetch origin "${BRANCH}" || die "git fetch 失败"
  # 计算本地与远端差异：若远端有更新则返回 0
  LOCAL="$(git rev-parse @)"
  REMOTE="$(git rev-parse "origin/${BRANCH}")"
  BASE="$(git merge-base @ "origin/${BRANCH}")"
  debug "LOCAL=${LOCAL}"
  debug "REMOTE=${REMOTE}"
  debug "BASE=${BASE}"
  if [ "${LOCAL}" = "${REMOTE}" ]; then
    log "仓库已是最新（local == origin/${BRANCH}）"
    return 1    # 无更新
  elif [ "${LOCAL}" = "${BASE}" ]; then
    log "远端有更新（local 在远端之后）"
    git pull --ff-only || die "git pull 失败"
    return 0    # 有更新并已 pull
  elif [ "${REMOTE}" = "${BASE}" ]; then
    log "本地有 commit 在远端之前（本地 ahead）；请手动处理或强制覆盖"
    return 0
  else
    log "本地与远端分支存在分叉，需要手动处理"
    return 0
  fi
}

# -------------------- 子函数: 更新 feeds --------------------
update_feeds() {
  cd "${REPO_PATH}"
  log "更新并安装 feeds..."
  ./scripts/feeds update -a || die "feeds update 失败"
  ./scripts/feeds install -a || die "feeds install 失败"
  log "feeds 更新完成"
}

# -------------------- 子函数: 下载依赖并构建 --------------------
do_build() {
  cd "${REPO_PATH}"
  # 如果存在 .config 并且用户要交互，先给提示
  if [ "${MENUCONFIG}" -ne 0 ]; then
    log "进入 make menuconfig （交互），完成后保存并退出以继续构建"
    make menuconfig || die "make menuconfig 失败或被中断"
  fi

  log "运行 make download -j${JOBS} V=s"
  make download -j"${JOBS}" V=s || die "make download 失败"

  if [ "${CLEAN_BUILD}" -ne 0 ]; then
    log "执行 make clean（-c）"
    make clean || die "make clean 失败"
  fi

  log "开始编译： make V=s -j${JOBS}"
  # 这里保留 V=s 以输出详细构建日志
  make V=s -j"${JOBS}" || die "make 编译失败，请查看上面的日志定位失败包/步骤"
  log "make 完成"
}

# -------------------- 子函数: 查找镜像并转换为 qcow2 --------------------
convert_images() {
  local target_dir="${REPO_PATH}/${TARGET_SUBPATH}"
  log "尝试在 ${target_dir} 查找镜像（模式: ${IMG_GLOB}）"
  if [ ! -d "${target_dir}" ]; then
    die "目标目录不存在：${target_dir}。构建可能失败或目标不是 x86/64，请检查 bin/targets 下的内容：$(ls -1 "${REPO_PATH}/bin/targets" || true)"
  fi

  # 查找匹配的 gz 或 img 文件（取最新）
  local found
  # prefer exact name pattern if exists, else fallback to find
  found="$(ls -1 "${target_dir}"/${IMG_GLOB} 2>/dev/null | sort -r | head -n1 || true)"
  if [ -z "${found}" ]; then
    # 尝试查找 *.img.gz 或 *.img
    found="$(find "${target_dir}" -maxdepth 1 -type f \( -name '*img.gz' -o -name '*img' \) -print0 | xargs -0 ls -1t 2>/dev/null | head -n1 || true)"
  fi

  if [ -z "${found}" ]; then
    log "未找到匹配的镜像文件。bin/targets/x86/64 内容如下："
    ls -lh "${target_dir}" || true
    return 0
  fi

  log "发现镜像: ${found}"

  # 如果是 .gz，则先 gunzip 到 disk.img
  if [[ "${found}" == *.gz ]]; then
    local disk_img="${target_dir}/disk.img"
    log "解压 ${found} -> ${disk_img}"
    gunzip -c "${found}" > "${disk_img}" || die "gunzip 解压失败"
    local qcow2_name="${found%.img.gz}.qcow2"
    qcow2_name="$(basename "${qcow2_name%.gz}").qcow2"
    qcow2_path="${target_dir}/${qcow2_name}"
    log "转换 raw -> qcow2: ${disk_img} -> ${qcow2_path}"
    qemu-img convert -f raw -O qcow2 "${disk_img}" "${qcow2_path}" || die "qemu-img 转换失败"
    rm -f "${disk_img}" || true
    log "转换完成：${qcow2_path}"
  else
    # 若已经是 .img
    local src="${found}"
    local qcow2_name="$(basename "${src%.img}").qcow2"
    local qcow2_path="${target_dir}/${qcow2_name}"
    log "转换 raw -> qcow2: ${src} -> ${qcow2_path}"
    qemu-img convert -f raw -O qcow2 "${src}" "${qcow2_path}" || die "qemu-img 转换失败"
    log "转换完成：${qcow2_path}"
  fi
}

# -------------------- 主流程 --------------------
main() {
  # 如果指定 reclone，则先删除并 clone
  if [ "${RECLONE}" -ne 0 ]; then
    log "--reclone 指定：将删除 ${REPO_PATH} 并重新 clone"
    rm -rf "${REPO_PATH}"
    install_deps
    clone_repo
    update_feeds
    do_build
    convert_images
    log "reclone 模式构建完成"
    exit 0
  fi

  # 若 repo 不存在 -> 首次安装流程
  if [ ! -d "${REPO_PATH}" ]; then
    log "检测到 ${REPO_PATH} 不存在 —— 执行首次安装流程"
    install_deps
    clone_repo
    update_feeds
    do_build
    convert_images
    log "首次构建完成"
    exit 0
  fi

  # 若到这里 repo 已存在 —— 常规 / 强制 / 清理 构建
  cd "${REPO_PATH}"

  log "仓库已存在：${REPO_PATH}。检查并拉取远端变更（fetch & compare）..."
  # fetch_and_check_updates 会返回 1 表示无更新
  if fetch_and_check_updates; then
    # fetch_and_check_updates 返回 0 表示有更新或有本地变更：继续构建
    log "检测到更新或本地变更，将继续后续构建步骤（或根据命令行选项执行 clean 等）"
    update_feeds
    do_build
    convert_images
    log "更新后构建完成"
    exit 0
  else
    # 无更新
    if [ "${FORCE_BUILD}" -ne 0 ]; then
      log "仓库无更新，但因 --force 指定，将强制重新构建"
      update_feeds
      do_build
      convert_images
      log "强制构建完成"
      exit 0
    else
      log "仓库无更新，未指定 --force，脚本退出（如要强制编译请使用 -f/--force）"
      exit 0
    fi
  fi
}

# 运行 main
main "$@"
