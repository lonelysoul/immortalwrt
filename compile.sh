#!/bin/bash

# 进入工作目录
cd ~/immortalwrt || { echo "Failed to change directory to immortalwrt"; exit 1; }

# 拉取最新代码
git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/master)

# 如果本地代码不是最新的，则更新并重新编译
if [ $LOCAL != $REMOTE ]; then
    echo "Source code has been updated. Recompilation starts."
    git pull origin master && \
    ./scripts/feeds update -a && \
    ./scripts/feeds install -a && \
    make -j8 download && make -j3 && \
    echo "$(date): Compilation completed"
else
    echo "Source code is up to date. No need to recompile."
fi
