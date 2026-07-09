#!/bin/bash

# =========================================================
# OpenWrt 编译环境初始化脚本
# 功能：
#   1. 更新软件源
#   2. 安装 OpenWrt 常用编译依赖
#   3. 创建普通用户
#   4. 设置用户密码（非交互）
#   5. 加入 sudo 管理组
#   6. 验证 sudo 权限是否生效
#
# 适用系统：
#   Debian / Ubuntu
#
# 使用方法：
#   sudo bash init_openwrt_env.sh
#
# =========================================================

# 出现错误立即退出
set -e

# -------------------------
# 用户配置区域
# -------------------------

# 要创建的用户名
USERNAME="wrt"

# 用户密码
PASSWORD="wrt"

# -------------------------
# 检查是否 root 执行
# -------------------------

if [ "$EUID" -ne 0 ]; then
    echo "错误：请使用 root 运行此脚本"
    exit 1
fi


# -------------------------

# 设置系统时区

# -------------------------

echo "=============================="

echo "设置系统时区为 Asia/Shanghai..."

echo "=============================="

timedatectl set-timezone Asia/Shanghai

echo "当前系统时间："

timedatectl

# -------------------------
# 更新软件源
# -------------------------

echo "=============================="
echo "更新 apt 软件源..."
echo "=============================="

apt-get update

# -------------------------
# 安装 OpenWrt 编译依赖
# -------------------------

echo "=============================="
echo "安装编译依赖..."
echo "=============================="

apt-get install -y \
    ssh \
    build-essential \
    clang \
    flex \
    bison \
    g++ \
    gawk \
    gcc-multilib \
    g++-multilib \
    gettext \
    git \
    libncurses5-dev \
    libssl-dev \
    python3-setuptools \
    rsync \
    swig \
    unzip \
    zlib1g-dev \
    file \
    wget \
    sudo \
    llvm

# -------------------------
# 检查用户是否已存在
# -------------------------

if id "$USERNAME" &>/dev/null; then
    echo "用户 $USERNAME 已存在，跳过创建"
else

    echo "=============================="
    echo "创建用户：$USERNAME"
    echo "=============================="

    # 创建用户：
    # -m 自动创建 home 目录
    # -s 指定 shell
    useradd -m -s /bin/bash "$USERNAME"

    # 非交互设置密码
    echo "${USERNAME}:${PASSWORD}" | chpasswd

    # 加入 sudo 组
    usermod -aG sudo "$USERNAME"

    echo "用户创建完成"

fi

# -------------------------
# 显示用户信息
# -------------------------

echo "=============================="
echo "用户信息"
echo "=============================="

id "$USERNAME"

# -------------------------
# 验证 sudo 权限
# -------------------------

echo "=============================="
echo "验证 sudo 权限"
echo "=============================="

# 使用 su 切换用户后执行 sudo whoami
# -S 表示从标准输入读取密码
# 成功后应输出 root

VERIFY_RESULT=$(su - "$USERNAME" -c "echo '$PASSWORD' | sudo -S whoami")

if [ "$VERIFY_RESULT" = "root" ]; then
    echo "sudo 权限验证成功"
else
    echo "sudo 权限验证失败"
    exit 1
fi

# -------------------------
# 完成
# -------------------------

echo "=============================="
echo "环境初始化完成"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
echo "=============================="