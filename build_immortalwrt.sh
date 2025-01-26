#!/bin/bash

set -e  # 启用错误检查，任何命令失败时停止执行

# 可配置的环境变量
BUILD_DIR="${BUILD_DIR:-immortalwrt}"  # 编译目录，默认为 immortalwrt
REPO_URL="${REPO_URL:-https://github.com/immortalwrt/immortalwrt}"  # 仓库地址，默认为官方仓库
BRANCH="${BRANCH:-master}"  # 分支，默认为 master
CONFIG_URL="${CONFIG_URL:-https://raw.githubusercontent.com/lonelysoul/immortalwrt/refs/heads/main/.config}"  # 默认 .config 文件 URL
MAX_JOBS="${MAX_JOBS:-$(($(nproc) + 1))}"  # 并行编译任务数，默认为 CPU 核心数 + 1

# 初始化环境
init_environment() {
  echo "🛠️  正在初始化环境..."

  # 安装编译所需的依赖
  echo "📦  安装依赖包..."
  sudo apt-get update
  sudo apt-get install -y build-essential ccache flex g++ gawk gcc-multilib \
    gettext git libncurses5-dev libssl-dev libxml-parser-perl \
    python3 python3-distutils rsync unzip zlib1g-dev

  # 检查并设置 ccache（用于加速编译）
  if ! command -v ccache &> /dev/null; then
    echo "🔧  ccache 未安装，正在安装..."
    sudo apt-get install -y ccache
  fi
  export PATH="/usr/lib/ccache:$PATH"
  echo "✅  环境初始化完成！"
}

# 克隆仓库
clone_repo() {
  echo "📥  正在克隆仓库..."
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$BUILD_DIR"
  echo "✅  仓库克隆完成！"
}

# 应用自定义配置
apply_config() {
  echo "🔧  正在下载自定义 .config 文件..."
  curl -L -o "$BUILD_DIR/.config" "$CONFIG_URL"
  echo "✅  .config 文件已应用！"
}

# 编译固件
compile_firmware() {
  echo "🔨  开始编译固件..."
  cd "$BUILD_DIR"

  # 准备编译环境
  echo "🛠️  生成默认配置..."
  make defconfig

  echo "📦  下载所需的软件包..."
  make -j"$MAX_JOBS" download

  echo "🚀  开始编译（使用 $(nproc) 个线程）..."
  make -j"$(nproc)"

  echo "🎉  编译完成！"
}

# 清理工作目录
clean_workspace() {
  if [ -d "$BUILD_DIR" ]; then
    echo "🧹  正在清理现有工作目录: $BUILD_DIR..."
    rm -rf "$BUILD_DIR"
    echo "✅  工作目录已清理！"
  fi
}

# 显示帮助信息
show_help() {
  echo "用法: $0 [-n]"
  echo "  -n: 强制清理并重新编译（删除现有工作目录）"
  exit 1
}

# 主函数
main() {
  # 解析参数
  while getopts ":n" opt; do
    case $opt in
      n)
        echo "🔧  强制清理模式已启用。"
        clean_workspace
        ;;
      *)
        show_help
        ;;
    esac
  done

  # 如果工作目录已存在且未启用强制模式，则退出
  if [ -d "$BUILD_DIR" ]; then
    echo "❌  目录 $BUILD_DIR 已存在。为避免覆盖，编译已中止。"
    echo "    使用 -n 参数强制清理并重新编译。"
    exit 1
  fi

  # 执行编译流程
  init_environment
  clone_repo
  apply_config
  compile_firmware

  echo "🎉  编译成功！输出文件位于: $BUILD_DIR/bin/targets/"
}

# 执行主函数
main "$@"
