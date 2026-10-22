# LogoerZoom · macOS 华为图标

让 macOS 菜单栏显示 Huawei 华为图标，并支持图标放大、静态背景与轻量运行。

![macOS 华为图标效果](docs/images/huawei-logo.png)

配合 [Logoer](https://github.com/lihaoyun6/Logoer) 使用，将原先 18 × 18 点的红色华为图标显示为 22.5 × 22.5 点，增加 25%。仅在检测到 Logoer 可见图标窗口时显示；点击穿透，不添加 Dock 或菜单栏图标。

## 使用

先安装 Logoer，在其设置中选择 [`Resources/logo.png`](Resources/logo.png) 并开启自定义图标。在仓库根目录执行：

```sh
./scripts/install.sh
```

辅助程序安装到 `~/Library/Application Support/Logoer-size-adjustment/LogoerZoom.app`，通过当前用户的 LaunchAgent 自动启动。升级时保留旧版本备份，无需管理员密码。

只构建不安装：`./scripts/build.sh`。

停止并关闭自动启动：`./scripts/uninstall.sh`。原版 Logoer 将恢复自身的图标大小。

## 显示方式

背景从资源图片加载一次，复用已校准好的底色、渐变和阴影，不再采集屏幕或实时重建背景。应用不链接 ScreenCaptureKit，不请求录屏或辅助功能权限，不联网。

只加载内嵌的 `Resources/logo.png`，不再轮询 Logoer 的图片文件。更换图标后需要重新构建、安装。

没有周期定时器。应用启动／退出／激活、切换桌面、显示器变化及系统外观变化时，通过通知读取一次窗口位置。闲置时等待系统事件；重新打开 LogoerZoom 可手动刷新位置。原生菜单栏外观由一个零宽度状态栏项通知，不显示额外图标。

随附 `Resources/background.png` 是示例蓝色壁纸的一次性校准资源。固定壁纸、缩放和菜单栏外观下可以一直复用；其他环境需替换静态图片。无实时采样意味着不自动匹配任意壁纸，也不承诺即时跟踪全屏自动隐藏菜单栏的鼠标悬停变化。

当前识别 Logoer 0.2.2 的 24 × 24 点窗口；其他 Logoer 版本可能需要适配。本机内置显示器已确认效果，外接多屏和任意纹理背景尚未完整验证。

运行状态文件：`~/Library/Application Support/Logoer-size-adjustment/status.json`。

## 构建要求

macOS 15.2 或更新版本，Apple Command Line Tools（含 Swift 编译器与 Python 3）。本机 Apple Silicon / macOS 27.0.1 已确认效果。构建采用本地临时签名，未做 Apple 公证。

## 来源与图标

Logoer 为 [lihaoyun6/Logoer](https://github.com/lihaoyun6/Logoer) 的第三方项目，本仓库提供独立辅助程序，并不包含或修改 Logoer 本体。Huawei / 华为及其图标属于各自权利人，本项目与华为及 Apple 无隶属或背书关系。

深色菜单栏可另提供 `Resources/background-dark.png`；缺少对应外观模板时使用固定的浅／深色底保证文字可读，不触发截图采样。验证记录见 [轻量版本机验证](docs/lightweight-validation.md)。
