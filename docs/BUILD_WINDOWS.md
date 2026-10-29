# 在 Windows 上重新编译

## 准备

- Windows 10/11 x64。
- [Godot 4.6.3 Standard](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable) Windows 编辑器；不需要 .NET 版。
- Python 3.10 或以上，`python` 命令可用。
- 构建依赖只有 `scripts/requirements-build.txt` 中固定版本的 Pillow，用于 EXE 图标。运行成品不需要 Python。

从 GitHub 下载本分支源码 ZIP 并解压，或执行：

```powershell
git clone --branch orbitlaser-development https://github.com/LiuZhenyao/hello-world.git
cd hello-world
```

## 一条命令构建

在项目根目录执行，替换为本机 Godot 路径（优先选择官方 console 编辑器 EXE）：

```powershell
powershell -File .\scripts\build-windows.ps1 -GodotPath "C:\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe"
```

脚本安装构建依赖、从官方 4.6.3 发布包提取 Windows x64 release 模板、导入暂存工程、执行数值/导出/界面测试、导出单文件 EXE、嵌入应用图标、运行本机 headless 启动检查，并生成交付 ZIP。不会修改已跟踪的源码或导出配置。

若所在单位限制 PowerShell 脚本，可使用等效 Python 命令，无需修改系统执行策略：

```powershell
python -m pip install -r scripts/requirements-build.txt
python scripts/build.py --godot "C:\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe" --target windows --package
```

## 离线模板

预先安装或取得同版本官方 `windows_release_x86_64.exe` 后可指定：

```powershell
python scripts/build.py --godot "C:\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe" --target windows --template "C:\Templates\windows_release_x86_64.exe" --package
```

依赖和 Godot 就绪时，此方式无需下载模板。默认下载脚本只访问官方 HTTPS 发布包，保持 TLS 验证，校验 ZIP CRC，并记录提取文件 SHA256；记录的 SHA256 是本次观测值，不冒称供应商签名或整包官方校验和。

## 输出

- `build/OrbitLaser.exe`：单文件 Windows 桌面程序。
- `releases/OrbitLaser-1.0-Windows-x64.zip`：可分发成品包。
- `releases/OrbitLaser-1.0-Source.zip`：完整源码归档（不含引擎/缓存）。
- `releases/SHA256SUMS.txt`：校验值。
- `build/logs/`：各阶段日志。
- `build/build-evidence.json`、`build/packaged-smoke.json`：本次构建与启动检查证据。

源码包包含 Godot 项目、全部 GDScript、场景、字体与许可、SVG 图标、导出预设、构建脚本、依赖版本、测试及文档。Windows/Linux 模板和编辑器是外部构建工具，通过固定版本获取，不放入源码包。

## 编辑与测试

用 Godot 打开 `orbitlaser/project.godot` 即可运行或调试。在根目录执行：

```powershell
godot --headless --path orbitlaser --script tests/test_model.gd
godot --headless --path orbitlaser --script tests/test_export.gd
godot --path orbitlaser --script tests/test_ui.gd --audio-driver Dummy
```

第一次使用前先导入：`godot --headless --editor --path orbitlaser --import --quit`。图形版 UI 测试会输出实际截图；headless 测试只验证组件行为，不能证明可见窗口渲染。

也可使用 Godot 内置导出菜单：安装相同版本官方导出模板，选择 `Windows Desktop`，保留内嵌 PCK 选项。自动构建脚本额外完成图标写入和成品启动检查。

## 运行要求及边界

成品支持 Windows 10/11 x64，需要支持 OpenGL 3.3 的显卡驱动，建议 4 GB 内存，无需 Python、Node、浏览器或联网。程序未数字签名，请遵守所在单位的软件运行政策。

本次交付在 Linux 交叉导出；Windows 真机窗口、DPI、原生文件选择框与安全软件兼容性尚未验证。用户在 Windows 执行构建脚本时，会执行本机 headless 成品启动检查；它仍不代替可视窗口验收。
