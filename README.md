# LogoerZoom · macOS 华为图标

让 macOS 菜单栏显示 Huawei 华为图标，并支持图标放大与实时背景融合。

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

使用 ScreenCaptureKit 每秒读取图标周围约 40 × 32 点的屏幕，只采样图标外侧的背景色带，逐行插值重建底色、渐变和阴影，再绘制红色图案。不保存截图、不上传画面。未获屏幕录制权限时使用随附静态背景。

优先读取 Logoer 的当前自定义图片，无法读取时使用嵌入的 `Resources/logo.png`。图像提取针对本仓库红色华为图案设计，其他颜色或构图需要调整源码。更换嵌入图片后应重新构建、安装。

当前识别 Logoer 0.2.2 的 24 × 24 点窗口；其他 Logoer 版本可能需要适配。本机内置显示器已确认效果，外接多屏和任意纹理背景尚未完整验证。

运行状态文件：`~/Library/Application Support/Logoer-size-adjustment/capture-status.txt`。

## 构建要求

macOS 15.2 或更新版本，Apple Command Line Tools（含 Swift 编译器与 Python 3）。本机 Apple Silicon / macOS 27.0.1 已确认效果。构建采用本地临时签名，未做 Apple 公证。

## 来源与图标

Logoer 为 [lihaoyun6/Logoer](https://github.com/lihaoyun6/Logoer) 的第三方项目，本仓库提供独立辅助程序，并不包含或修改 Logoer 本体。Huawei / 华为及其图标属于各自权利人，本项目与华为及 Apple 无隶属或背书关系。
