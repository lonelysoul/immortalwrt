#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#


# 克隆 coolsnowwolf/luci 仓库
git clone https://github.com/coolsnowwolf/luci.git

# 复制 luci-app-airplay2 文件夹到 feeds/luci/applications/
cp -r luci/applications/luci-app-airplay2/ feeds/luci/applications/

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate
