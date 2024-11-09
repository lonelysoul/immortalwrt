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

# 添加 cron 任务，每天早上 8 点执行 compile.sh
(crontab -l 2>/dev/null; echo "* 8 * * * /bin/bash /home/wrt/compile.sh > /dev/null 2>&1") | crontab -
