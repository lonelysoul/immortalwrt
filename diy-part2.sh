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

# 删除 golang 语言包
find ./ | grep Makefile | grep v2ray-geodata | xargs rm -f
find ./ | grep Makefile | grep mosdns | xargs rm -f

# 删除 feeds 中的 v2ray-geodata 包（适用于 openwrt-22.03 和 master）
# rm -rf feeds/packages/net/v2ray-geodata

# 克隆 mosdns 和 v2ray-geodata 仓库
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# 克隆 coolsnowwolf/luci 仓库
# git clone https://github.com/coolsnowwolf/luci.git

# 复制 luci-app-airplay2 文件夹到 feeds/luci/applications/
# cp -r luci/applications/luci-app-airplay2/ feeds/luci/applications/luci-app-airplay2/

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate
