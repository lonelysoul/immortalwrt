#!/bin/bash
#
# 版权所有（c）2019-2020 P3TERX <https://p3terx.com>
#
# 本软件是自由软件，遵循 MIT 许可证。
# 更多信息请参见 /LICENSE。
#
# https://github.com/P3TERX/Actions-OpenWrt
# 文件名: diy-part1.sh
# 描述: OpenWrt DIY 脚本第一部分（更新 feeds 之前）
#

# 删除 golang 语言包
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 20.x feeds/packages/lang/golang

# 删除 feeds 中的 v2ray-geodata 包（适用于 openwrt-22.03 和 master）
rm -rf feeds/packages/net/v2ray-geodata

# 克隆 mosdns 和 v2ray-geodata 仓库
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# 克隆 coolsnowwolf/luci 仓库
git clone https://github.com/coolsnowwolf/luci.git

# 复制 luci-app-airplay2 文件夹到 feeds/luci/applications/
cp -r luci/applications/luci-app-airplay2/ feeds/luci/applications/

# 取消注释一个 feed 源
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# 添加一个 feed 源
# echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
# echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
