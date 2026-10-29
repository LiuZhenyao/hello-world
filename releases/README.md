# 卫星轨道模拟仿真教学软件：程序与源码归档

本目录保存的是实际提交至 GitHub 的二进制 ZIP，不是工作区内部链接，也不依赖 GitHub Actions 临时附件。

- [下载 Windows x64 程序包](https://github.com/LiuZhenyao/hello-world/raw/refs/heads/orbitlaser-development/releases/OrbitLaser-1.0-Windows-x64.zip)：约 50.6 MiB。
- [下载完整源码包](https://github.com/LiuZhenyao/hello-world/raw/refs/heads/orbitlaser-development/releases/OrbitLaser-1.0-Source.zip)：约 14.9 MiB。
- [SHA256 校验值](SHA256SUMS.txt)。

**运行：解压 Windows ZIP，打开 `卫星轨道模拟仿真教学软件` 文件夹，双击 `卫星轨道模拟仿真教学软件.exe`。** EXE 大小 约 116 MiB，内置引擎和全部运行资源。包内还包括使用/构建说明、许可、示例场景、CSV、HTML 报告、截图及验证证据。

若浏览器显示二进制文件页面，点击 Download raw file；私有仓库需登录有权限的 GitHub 账号。也可以下载整个分支的 Code → Download ZIP，解压后进入 releases/ 再解压程序包。

Windows 10/11 x64，需 OpenGL 3.3 驱动。无需 Python、Node 或联网。当前程序未签名；本次交叉导出环境为 Linux，Windows 真机窗口、DPI、文件选择框和安全软件兼容性尚未验收。

源码的 Windows 重编译步骤见 [BUILD_WINDOWS.md](../docs/BUILD_WINDOWS.md)，实际测试结果见 [VALIDATION.md](../docs/VALIDATION.md)。
