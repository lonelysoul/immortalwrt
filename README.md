# 固件说明

本固件每日约在九点左右发布，集成多种插件和功能，满足家庭网络及多媒体需求。

## 插件功能

- **`dae prepare`**：系统环境配置及预备工具。
- **`LuCI`**：Web 管理界面，简化路由器配置。
- **`airplay`**：支持 AirPlay 无线音视频传输。
- **`daed`**：提供 Daed 系统支持。
- **`homeproxy`**：家庭代理服务，便于网络流量管理。
- **`samba`**：文件共享服务，支持 SMB 协议。
- **`statistics`**：流量统计分析插件。
- **`upnp`**：自动端口映射服务。
- **`vnstat`**：实时网络流量监控。
- **`wireguard`**：高效、安全的 VPN 服务。
- **`kmod-media-controller`**：多媒体设备支持模块。
- **`usb-audio`**：扩展 USB 音频输出支持。
- **`ip-full`**：增强的 IP 工具集。

## 分区大小

- **Kernel Partition**：32M  
- **Root Filesystem Partition**：160M  

## 自动更新机制

- 每次编译前自动检测代码库更新。
- 若无更新，则跳过编译以节省资源。

## 使用场景

本固件适用于：
- 文件共享需求。
- 网络流量监控与管理。
- 家庭多媒体设备扩展。

---

### License

本项目基于 [MIT License](LICENSE) 许可协议。
