#!/usr/bin/env bash

set -euo pipefail

########################################
# 基础参数
########################################
REPO_URL="https://github.com/immortalwrt/immortalwrt.git"
REPO_BRANCH="master"
REPO_PATH="${PWD}/immortalwrt"
CONFIG_URL="https://raw.githubusercontent.com/lonelysoul/immortalwrt/main/.config"

APT_PKGS=(
ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential
bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib
g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev
libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev
libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano
ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils
python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs
upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd
)

########################################
# 全局变量
########################################
FORCE=0
CLEAN=0
RECLONE=0
RECONFIG=0
LOG_FILE="${PWD}/build.log"
THREADS=$(nproc)

########################################
# 日志函数
########################################
log() {
    echo -e "\033[1;32m[$(date '+%F %T')] $*\033[0m" | tee -a "$LOG_FILE"
}

err() {
    echo -e "\033[1;31m[$(date '+%F %T')] ERROR: $*\033[0m" | tee -a "$LOG_FILE"
}

########################################
# 参数解析
########################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f) FORCE=1 ;;
        -c) CLEAN=1; FORCE=1 ;;
        -r) RECLONE=1; FORCE=1 ;;
        -config) RECONFIG=1; FORCE=1 ;;
        *) err "未知参数: $1"; exit 1 ;;
    esac
    shift
done

########################################
# 安装依赖（仅首次）
########################################
install_deps() {
    log "安装依赖..."
    sudo apt update
    sudo apt install -y "${APT_PKGS[@]}"
}

########################################
# 克隆仓库
########################################
clone_repo() {
    log "克隆仓库..."
    git clone -b "$REPO_BRANCH" "$REPO_URL" "$REPO_PATH"
}

########################################
# 更新仓库
########################################
update_repo() {
    cd "$REPO_PATH"

    log "检查远程更新..."
    git remote update

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/${REPO_BRANCH})

    if [[ "$LOCAL" != "$REMOTE" ]]; then
        log "发现更新，拉取代码..."
        git pull
        return 0
    else
        log "代码已是最新"
        return 1
    fi
}

########################################
# feeds
########################################
update_feeds() {
    cd "$REPO_PATH"
    log "更新 feeds..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a
}

########################################
# config
########################################
update_config() {
    cd "$REPO_PATH"

    if [[ ! -f .config ]] || [[ $RECONFIG -eq 1 ]]; then
        log "下载 .config ..."
        rm -f .config
        wget -O .config "$CONFIG_URL"
    else
        log ".config 已存在，跳过下载"
    fi

    log "同步默认配置..."
    make defconfig
}

########################################
# 编译
########################################
build_fw() {
    cd "$REPO_PATH"

    if [[ $CLEAN -eq 1 ]]; then
        log "执行 make clean..."
        make clean
    fi

    log "开始多线程编译 (线程: $THREADS)..."
    if make -j"$THREADS"; then
        log "编译成功"
    else
        err "多线程编译失败，切换单线程..."
        make -j1 V=s
    fi
}

########################################
# 主流程
########################################
main() {

    log "========== ImmortalWrt 自动编译开始 =========="

    # 首次
    if [[ ! -d "$REPO_PATH" ]]; then
        install_deps
        clone_repo
        update_feeds
        update_config
        build_fw
        exit 0
    fi

    # -r 重建
    if [[ $RECLONE -eq 1 ]]; then
        log "删除旧目录..."
        rm -rf "$REPO_PATH"
        clone_repo
        update_feeds
        update_config
        build_fw
        exit 0
    fi

    # 更新仓库
    UPDATED=1
    if [[ $FORCE -eq 0 ]]; then
        if update_repo; then
            UPDATED=1
        else
            UPDATED=0
        fi
    else
        log "强制模式，跳过更新检测"
        cd "$REPO_PATH"
        git pull || true
    fi

    # 是否需要编译
    if [[ $UPDATED -eq 1 || $FORCE -eq 1 ]]; then
        update_feeds
        update_config
        build_fw
    else
        log "没有更新，跳过编译"
    fi

    log "========== 完成 =========="
}

main "$@"