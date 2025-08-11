#!/bin/bash

# 设置工作目录变量（immortalwrt源码路径）
WORK_DIR=~/immortalwrt

# 解析命令行参数，判断是否传入 -c（强制编译）选项
FORCE_COMPILE=false
while getopts ":c" opt; do
  case ${opt} in
    c )
      FORCE_COMPILE=true
      ;;
    \? )
      echo "无效的选项" 1>&2
      exit 1
      ;;
  esac
done

# 进入工作目录，若失败则退出脚本
cd "$WORK_DIR" || { echo "无法切换到目录 $WORK_DIR"; exit 1; }

# 拉取远程仓库最新代码的提交信息
git fetch origin
LOCAL=$(git rev-parse HEAD)          # 本地当前提交哈希
REMOTE=$(git rev-parse origin/master) # 远程 master 分支最新提交哈希

# 判断是否需要编译（代码有更新或强制编译）
if [ "$LOCAL" != "$REMOTE" ] || [ "$FORCE_COMPILE" = true ]; then
    if [ "$FORCE_COMPILE" = true ]; then
        echo "检测到强制编译选项，即使代码是最新的也会重新编译。"
    else
        echo "源码已更新，开始重新编译。"
    fi

    # 记录编译开始时间
    start=$(date +%s)

    # 拉取远程最新代码，如果失败则退出
    if ! git pull origin master; then
        echo "从 origin/master 拉取最新代码失败。"
        exit 1
    fi

    # 更新并安装 feeds，失败则退出
    if ! ./scripts/feeds update -a; then
        echo "更新 feeds 失败。"
        exit 1
    fi
    if ! ./scripts/feeds install -a; then
        echo "安装 feeds 失败。"
        exit 1
    fi

    # 下载所有需要的软件包，失败则退出
    if ! make -j${NPROC:-$(nproc)} download; then
        echo "下载软件包失败。"
        exit 1
    fi

    # 运行 make defconfig 生成默认配置，失败则退出
    if ! make defconfig; then
        echo "执行 make defconfig 失败。"
        exit 1
    fi

    # 开始编译，失败则退出
    if ! make -j${NPROC:-$(nproc --ignore=1)}; then
        echo "编译失败。"
        exit 1
    fi

    # 记录编译结束时间并计算耗时
    end=$(date +%s)
    echo "总编译时间：$(((end - start) / 60)) 分 $(((end - start) % 60)) 秒"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): 编译完成"

    # 进入生成的固件目录
    cd bin/targets/x86/64/ || { echo "进入固件目录失败"; exit 1; }

    # 解压 .img.gz 固件，并转换成 qcow2 格式
    gunzip -c immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz > /tmp/disk.img && \
    sudo qemu-img convert -f raw -O qcow2 /tmp/disk.img immortalwrt-x86-64-generic-squashfs-combined-efi.qcow2 && \
    rm /tmp/disk.img

    echo "固件转换完成：immortalwrt-x86-64-generic-squashfs-combined-efi.qcow2"

else
    # 代码是最新，无需编译
    echo "源码已是最新，无需重新编译。"
fi
