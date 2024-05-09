#!/bin/bash

# 判断是否传入了 -c 参数
FORCE_COMPILE=false
while getopts ":c" opt; do
  case ${opt} in
    c )
      FORCE_COMPILE=true
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
  esac
done

# 进入工作目录
cd ~/immortalwrt || { echo "Failed to change directory to immortalwrt"; exit 1; }

# 拉取最新代码
git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u})

# 检查本地和远程代码是否一致或是否强制编译
if [ "$LOCAL" != "$REMOTE" ] || [ "$FORCE_COMPILE" = true ]; then
    if [ "$FORCE_COMPILE" = true ]; then
        echo "Force compilation option detected. Recompilation starts even if the source code is up-to-date."
    else
        echo "Source code has been updated. Recompilation starts."
    fi
    # 开始计时
    start=$(date +%s)
    # 拉取最新代码并重新编译
    if ! git pull origin master; then
        echo "Failed to pull the latest code from origin/master."
        exit 1
    fi
    if ! ./scripts/feeds update -a; then
        echo "Failed to update feeds."
        exit 1
    fi
    if ! ./scripts/feeds install -a; then
        echo "Failed to install feeds."
        exit 1
    fi
    if ! make -j$(nproc) download; then
        echo "Failed to download packages."
        exit 1
    fi
    if ! make -j$(nproc --ignore=1); then
        echo "Failed to make."
        exit 1
    fi
    # 结束计时
    end=$(date +%s)
    # 输出编译总耗时
    echo "Total compilation time: $((end-start)) seconds"
    # 记录完成时间
    echo "$(date): Compilation completed"
else
    # 本地代码是最新的，无需重新编译
    echo "Source code is up-to-date. No need to recompile."
fi
