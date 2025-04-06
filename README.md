
# ImmortalWrt 固件自动化编译

本项目通过自动化流程实现 ImmortalWrt 固件的每日编译。固件包含多种实用插件，采用默认的分区配置，适合多种场景下的用户需求。

## 一键编译脚本

为了方便用户快速开始编译，您可以使用以下一键脚本：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/lonelysoul/immortalwrt/refs/heads/main/build_immortalwrt.sh)"
```

## 编译流程

- **周期**：每日检查上游代码库（ImmortalWrt 官方仓库），如有更新，自动触发编译。
- **编译时间**：固件将在每日早上 8 点前完成编译并发布到项目的 Releases 页面。

## 集成插件

固件集成了以下插件，提供了丰富的功能支持，满足家庭、办公及轻量级服务器需求：

### 基础功能
- `upnp`：通用即插即用支持
- `ddns-go`：动态域名解析服务

### 文件管理与共享
- `diskman`：磁盘管理工具
- `filebrowser-go`：文件管理器
- `samba`：文件共享服务

### 网络增强
- `hysteria2`：高性能代理工具
- `airplay2`：音频投屏支持
- `arpbind`：ARP 绑定工具
- `luci-dapp-dae`：基于 eBPF 的 Linux 高性能透明代理解决方案

### USB 支持
- `usb-audio`：USB 声卡支持

### 增强代理与防火墙
- `luci-app-openclash`：强大的 Clash 图形化管理界面，支持多种代理协议（如 Vmess、Trojan、SSR 等）

### 其他实用工具
- `openssh-sftp-server`：SFTP 服务

## 分区配置

固件采用上游代码的默认分区配置，无需额外调整即可适配大多数设备：

- **Kernel Partition**：32M
- **Root Filesystem Partition**：160M

## 使用说明

1. **获取固件**：在 [Releases](https://github.com/lonelysoul/immortalwrt/releases) 页面下载最新编译的固件。
2. **刷写固件**：
   - 确保设备硬件支持 ImmortalWrt 固件。
   - 按设备型号对应的刷写方式进行安装。
3. **定制需求**：如需添加插件或修改分区设置，可自行克隆仓库并参考官方文档调整配置。

## 贡献与支持

如果您有任何问题或建议，欢迎提交 Issue 或 Pull Request。您的支持是我们持续改进的动力！

