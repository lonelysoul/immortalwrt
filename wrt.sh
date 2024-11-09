#!/bin/sh

# 切换到主目录
cd ~

# 下载并设置 init_install.sh 可执行权限
wget -O init_install.sh https://raw.githubusercontent.com/lonelysoul/immortalwrt/refs/heads/main/init_install.sh
chmod +x init_install.sh

# 执行 init_install.sh
./init_install.sh

# 下载并设置 compile.sh 可执行权限
wget -O compile.sh https://raw.githubusercontent.com/lonelysoul/immortalwrt/refs/heads/main/compile.sh
chmod +x compile.sh
