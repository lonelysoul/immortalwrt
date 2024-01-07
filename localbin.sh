#/bin/bash/
cd
cd openwrt
cd feeds/packages/lang/golang
git pull
echo "golang更新完毕"
cd
cd openwrt
cd package/mosdns
git pull 
echo "mosdns更新完毕"
cd 
cd openwrt
cd package/v2ray-geodata
git pull
echo "geodata更新完毕"
cd 
echo "进入用户目录"
cd openwrt
echo "更新源码"
git pull
echo "更新feed"
./scripts/feeds update -a && ./scripts/feeds install -a
echo "检查完毕" 
cd
echo "进入用户目录"
cd openwrt
echo "更新源码"
git pull
echo "下载组件"
make -j8 download
echo "多线程编译"
make -j$(($(nproc) + 1))
echo "固件编译完成" 
