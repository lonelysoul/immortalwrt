# 在TrueNAS中生成和使用磁盘镜像

本指南提供了在TrueNAS中生成`disk.img.gz`固件、转换格式并使用生成的磁盘镜像设置虚拟机的分步说明。

## 前提条件

- 一个`disk.img.gz`固件文件（本地生成或从GitHub下载）。
- 对TrueNAS系统的管理员访问权限。
- 命令行工具：`gunzip`、`qemu-img`。
- 足够存储空间用于ZFS卷（zvol），最小大小为2GB。

## 步骤

1. **在TrueNAS中创建ZFS卷（zvol）**

   - 在TrueNAS web界面中，导航到**存储 &gt; 池**。
   - 创建一个新的zvol：
     - 进入你的数据集，点击**添加Zvol**。
     - 将zvol大小设置为至少2GB（当前固件需要约1GB，但为灵活性分配更多空间）。
     - 为zvol命名（例如，`zvolname`）。
     - 保存配置。

2. **将QCOW2转换为Raw并附加到Zvol**

   - 将`qcow2`镜像转换为raw格式并写入zvol：

     ```bash
     sudo qemu-img convert -O raw /path/to/disk.qcow2 /dev/zvol/datasets/zvolname
     ```

   - 将`/path/to/disk.qcow2`替换为你的`qcow2`文件路径，将`zvolname`替换为你的zvol名称。

3. **在TrueNAS中创建和配置虚拟机**

   - 在TrueNAS web界面中，导航到**虚拟化 &gt; 虚拟机**。
   - 创建一个新的虚拟机：
     - 分配足够的CPU、内存和其他资源。
     - 在**磁盘**下，选择第3步中创建的zvol（`/dev/zvol/datasets/zvolname`）。
     - 根据需要配置其他设置（例如，网络、显示）。
   - 保存虚拟机配置。

4. **启动虚拟机**

   - 从TrueNAS界面启动虚拟机。
   - 验证虚拟机是否使用固件正确启动。

## 注意事项

1. 确保zvol大小足够（2GB或以上）以容纳固件并避免问题。
2. 将占位符路径（例如，`/path/to/disk.img`）替换为系统中的实际文件路径。

- 在继续之前，验证你的TrueNAS系统已安装`qemu-img`和`gunzip`。
