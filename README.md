# 卫星轨道模拟仿真教学软件

Windows 离线桌面版星间激光测量数据仿真工具，覆盖 LEO 至 GEO 轨道高度。

**开发分支：[`orbitlaser-development`](https://github.com/LiuZhenyao/hello-world/tree/orbitlaser-development)。所有模块分别提交并推送，`master` 保持不变。**

## 下载程序

- [Windows x64 完整包（内含中文名称可执行程序）](https://github.com/LiuZhenyao/hello-world/raw/refs/heads/orbitlaser-development/releases/OrbitLaser-1.0-Windows-x64.zip)
- [完整源码 ZIP](https://github.com/LiuZhenyao/hello-world/raw/refs/heads/orbitlaser-development/releases/OrbitLaser-1.0-Source.zip)
- [校验值和交付文件](https://github.com/LiuZhenyao/hello-world/tree/orbitlaser-development/releases)

下载链接对应本分支实际提交的文件。若仓库为私有，请先登录具有访问权限的 GitHub 账号；也可进入 `releases/` 文件页面点击 Download raw file。下载源码也可使用 GitHub 的 Code → Download ZIP。

Windows 包解压后双击 `卫星轨道模拟仿真教学软件.exe`。内置引擎、中文字体和全部资源，无需安装 Python、Node 或联网；需要 Windows 10/11 x64、OpenGL 3.3 显卡驱动，建议 4 GB 内存。

## 功能

- 双卫星六参数椭圆轨道，LEO-LEO、LEO-GEO、GEO-GEO 预设及任意中间半长轴高度。
- 双体传播、ECI 轨道、单向光行时迭代、球形地球遮挡。
- 高斯光束、接收口径、等效 RMS 指向损耗、效率与光子门限。
- 测距噪声底、单光子定时抖动、固定测距偏差、接收端时钟偏差和随机种子。
- 中文工作台、可旋转/缩放轨道视图、快照、时间回放、四类科学曲线。
- 后台计算、进度和取消、参数校验、分页数据表、有效采样窗口。
- JSON 场景保存/载入、UTF-8 BOM CSV 和带内嵌 SVG 图表的独立 HTML 报告。
- 最多 50,000 点、最长 48 小时；应用内提供完整模型说明及第三方许可。

## Windows 重新编译

安装 Godot 4.6.3 Standard、Python 3.10+ 后，在项目根目录运行：

```powershell
powershell -File .\scripts\build-windows.ps1 -GodotPath "C:\Tools\Godot\Godot_v4.6.3-stable_win64_console.exe"
```

完整步骤、离线模板方法及等效 Python 命令见 [Windows 构建说明](docs/BUILD_WINDOWS.md)。输出 `build/OrbitLaser.exe` 和 `releases/OrbitLaser-1.0-Windows-x64.zip`。

## 验证与边界

Linux 上已通过 24 项数值检查、9 项导入导出检查、18 项真实渲染桌面集成检查。默认场景 2161 点中 1355 条有效测量，残差 RMS 约 0.019795 m。

Windows EXE 由官方模板交叉导出；加载内嵌资源包的检查不等于 Windows 原生运行。本次尚未进行 Windows 真机窗口、DPI、原生文件框与安全软件兼容性验收；程序未数字签名。见 [实际测试记录](docs/VALIDATION.md)。

采用双体与工程链路近似，不含 J2、第三体、相对论、姿态/接收机全动态等高保真因素。适用于概念分析与算法输入研究，不能替代精密任务定轨工具或工程认证。

源码、配置、资源、字体许可、构建工具和测试均保存于此分支。原工作区不可访问且无可恢复文件，本版本根据对话中的完整实现记录重建，而非文件快照恢复。
