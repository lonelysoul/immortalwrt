#!/bin/bash

# 切换到用户目录
cd

# 函数：更新Git仓库
update_repo() {
    # 切换到目标目录，执行git pull，输出更新信息，然后返回上一级目录；如果出错，则退出脚本
    cd "$1" && git pull && echo "$2 更新完毕" && cd - || exit 1
}

# 更新 Go (golang) 包
update_repo "openwrt/feeds/packages/lang/golang" "golang"

# 更新 mosdns 包
update_repo "openwrt/package/mosdns" "mosdns"

# 更新 v2ray-geodata 包
update_repo "openwrt/package/v2ray-geodata" "geodata"

# 进入 OpenWrt 目录，更新源码并更新 feeds；如果出错，则退出脚本
cd "openwrt" && git pull && ./scripts/feeds update -a && ./scripts/feeds install -a && cd - || exit 1

# 更新 OpenWrt 源码并下载组件
cd "openwrt" && git pull && make -j8 download && make -j$(( $(nproc) + 1 )) || exit 1

# 打印固件编译完成的消息
echo "固件编译完成"
