#!/bin/bash

# Define the working directory for compilation, e.g., where the OpenWrt directory will be
WORK_DIR=~/openwrt_build
CONFIG_URL="https://raw.githubusercontent.com/lonelysoul/immortalwrt/main/.config"
REPO_URL="https://github.com/immortalwrt/immortalwrt"
BRANCH="master"

# Create the working directory if it doesn't exist
mkdir -p $WORK_DIR

# Navigate to the working directory
cd $WORK_DIR

# Update system package lists
sudo apt-get update

# Install or update dependencies
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5 libncursesw5-dev libpython3-dev libreadline-dev libssl-dev libtool lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev

# Clone source code if it doesn't exist
if [ ! -d "immortalwrt" ]; then
    git clone -b $BRANCH --single-branch $REPO_URL immortalwrt
fi

# Enter the source directory
cd immortalwrt

# Update and install feeds
./scripts/feeds update -a && ./scripts/feeds install -a

# Download and overwrite configs
wget -O .config $CONFIG_URL
echo "The .config file has been downloaded and overwritten with the configuration from the URL."

# Modify the downloaded .config file to ensure it doesn't prompt for any options
make defconfig

# Begin compilation
make -j$(($(nproc) + 1)) download  V=s
make -j$(($(nproc) + 1)) V=s

# Note: The 'V=s' flag above increases verbosity of the build process, providing more information on the console.
# You can remove it if you prefer a less verbose output.

echo "OpenWrt build process completed."
