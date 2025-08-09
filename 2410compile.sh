#!/bin/bash

# 设置工作目录变量
WORK_DIR=~/2410

# 判断是否传入了 -c 参数
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

# 进入工作目录
cd "$WORK_DIR" || { echo "无法切换到目录 $WORK_DIR"; exit 1; }

# 拉取最新代码
git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/openwrt-24.10)

# 检查本地和远程代码是否一致或是否强制编译
if [ "$LOCAL" != "$REMOTE" ] || [ "$FORCE_COMPILE" = true ]; then
    if [ "$FORCE_COMPILE" = true ]; then
        echo "检测到强制编译选项，即使代码是最新的也会重新编译。"
    else
        echo "源码已更新，开始重新编译。"
    fi
    # 开始计时
    start=$(date +%s)
    # 拉取最新代码并重新编译
    if ! git pull origin openwrt-24.10; then
        echo "从 origin/openwrt-24.10 拉取最新代码失败。"
        exit 1
    fi
    if ! ./scripts/feeds update -a; then
        echo "更新 feeds 失败。"
        exit 1
    fi
    if ! ./scripts/feeds install -a; then
        echo "安装 feeds 失败。"
        exit 1
    fi
    if ! make -j${NPROC:-$(nproc)} download; then
        echo "下载软件包失败。"
        exit 1
    fi
        # 新增：运行 make defconfig
    if ! make defconfig; then
        echo "执行 make defconfig 失败。"
        exit 1
    fi
    if ! make -j${NPROC:-$(nproc --ignore=1)}; then
        echo "编译失败。"
        exit 1
    fi
    # 结束计时
    end=$(date +%s)
    # 输出编译总耗时
    echo "总编译时间：$(((end - start) / 60)) 分 $(((end - start) % 60)) 秒"
    # 记录完成时间
    echo "$(date '+%Y-%m-%d %H:%M:%S'): 编译完成"
else
    # 本地代码是最新的，无需重新编译
    echo "源码已是最新，无需重新编译。"
fi
