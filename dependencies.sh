#!/bin/bash

# 定义依赖项列表
dependencies=(
    ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache 
    clang cmake cpio curl device-tree-compiler ecj fakeroot fastjar flex gawk gettext genisoimage 
    git gnutls-dev gperf haveged help2man intltool jq libc6-dev-i386 libelf-dev libfuse-dev 
    libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5 
    libncursesw5-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lrzsz 
    lld llvm mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 
    python3-docutils python3-pip python3-ply python3-pyelftools python3-setuptools qemu-utils 
    quilt re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs unzip upx-ucl vim wget 
    xmlto xxd zlib1g-dev zstd lib32gcc-s1
)

# 更新软件包列表并安装依赖项
sudo apt update -y
sudo apt install -y "${dependencies[@]}"
