#!/bin/bash

# 切换到用户目录
cd

# 函数：更新Git仓库
# update_repo() {
    # 切换到目标目录，执行git pull，输出更新信息，然后返回上一级目录；如果出错，则退出脚本
    # cd "$1" && git pull && echo "$2 更新完毕" && cd - || exit 1
# }

# 更新 Go (golang) 包
# update_repo "openwrt/feeds/packages/lang/golang" "golang"

# 更新 mosdns 包
# update_repo "openwrt/package/mosdns" "mosdns"

# 更新 v2ray-geodata 包
# update_repo "openwrt/package/v2ray-geodata" "geodata"

# 进入 OpenWrt 目录，更新源码并更新 feeds；如果出错，则退出脚本
cd "immortalwrt" && git pull && ./scripts/feeds update -a && ./scripts/feeds install -a && cd - || exit 1

# 更新 OpenWrt 源码并下载组件
cd "immortalwrt" && git pull && make -j8 download && make -j$(( $(nproc) + 1 )) || exit 1

# 打印固件完成时间
echo $(date)

# 打印固件编译完成的消息
echo "固件编译完成"


======
#!/bin/bash
cd
cd immortalwrt
echo $(git rev-parse HEAD) > ./ot.txt
file1=./ot.txt file2=./otold.txt
sort $file1
sort $file2
diff $file1 $file2 > /dev/null
if [ $? == 0 ]; then
echo "same"
else
echo "diferent"
cd
cd "immortalwrt" && git pull && ./scripts/feeds update -a && ./scripts/feeds install -a && cd - || exit 1
cd "immortalwrt" && git pull && make -j8 download && make -j3 || exit 1
echo $(date)
echo "固件编译完成"
fi
mv ./ot.txt otold.txt

