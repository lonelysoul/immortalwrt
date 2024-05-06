#!/bin/bash

# 进入工作目录
cd ~/immortalwrt || { echo "Failed to change directory to immortalwrt"; exit 1; }

# 拉取最新代码
git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/master)

# 检查本地和远程代码是否一致
if [ "$LOCAL" != "$REMOTE" ]; then
    echo "Source code has been updated. Recompilation starts."
    # 开始计时
    start=$(date +%s)
    # 拉取最新代码并重新编译
    git pull origin master && \
    ./scripts/feeds update -a && \
    ./scripts/feeds install -a && \
    make -j8 download && make -j3 && \
    # 结束计时
    end=$(date +%s)
    # 输出编译总耗时
    echo "Total compilation time: $((end-start)) seconds"
    # 移除旧的记录文件，更新为最新的
    echo "$(date): Compilation completed"
else
    # 本地代码是最新的，无需重新编译
    echo "Source code is up to date. No need to recompile."
fi
