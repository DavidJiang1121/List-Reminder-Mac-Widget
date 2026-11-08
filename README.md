<p align="center">
  <img src="assets/icon.png" width="112" alt="List Reminder icon">
</p>

<h1 align="center">List Reminder</h1>

<p align="center">一张留在桌面的清单，让待办一目了然。</p>

<p align="center">
  macOS 26+ · Apple Silicon · Swift / AppKit / SwiftUI
</p>

<p align="center">
  中文 · <a href="README.en.md">English</a>
</p>

List Reminder 是一款简约的原生 macOS 待办应用。你可以在主窗口整理事项，再把液态玻璃小组件放到桌面合适的位置。双击某一行即可完成待办，保持当前工作节奏。

## 下载

前往本仓库的 **[Releases](https://github.com/solitarystar123/DavidJiang/releases/latest)**，下载 `List-Reminder-macOS-arm64.zip`，解压后将 **List Reminder.app** 拖入“应用程序”并打开。

需要 **M 系列芯片的 Mac** 和 **macOS 26 或更新版本**。当前发布包使用临时签名，尚未进行 Apple 公证。

## 功能

- **桌面待办**：在独立的桌面小组件中查看未完成事项，关闭主窗口后仍可使用。
- **双击完成**：主窗口和桌面小组件均支持双击完成；桌面单击不会打开主窗口。
- **系统液态玻璃**：使用 `NSGlassEffectView`，背景透明度可调，文字保持清晰。
- **自由布局**：拖动标题移动位置，拖动右下角缩放；也可在主应用选择尺寸或调节宽高。
- **锁定位置**：放好后在主应用开启锁定，防止桌面误拖动。锁定后仍可双击完成事项。
- **简约外观**：中性色调，没有橙色装饰、进度条或常驻操作提示，支持浅色、深色与跟随系统。
- **清单管理**：添加、编辑、删除、查看已完成记录，以及撤销最近一次待办操作。
- **本地保存**：无需账号或联网，待办、外观设置、位置和锁定状态自动保存。

## 开始使用

1. 在主窗口输入待办，按回车添加。
2. 在主窗口或桌面小组件中，双击一行完成；在“已完成”中双击可恢复。
3. 打开 **小组件外观**，调节透明度、尺寸与色调。
4. 将小组件拖到想要的位置，开启 **锁定位置**。
5. 关闭主窗口后继续从桌面使用。点击 Dock 或菜单栏清单图标可重新打开主窗口。

小组件是应用自带的桌面常驻窗口，无需在系统小组件图库中添加。它显示在普通应用窗口下方，不会覆盖工作中的窗口。锁定后桌面拖动和角落缩放均被禁用，尺寸仍可从主应用调节。

完整操作说明见 **[使用说明](docs/使用说明.md)**。

## 本地数据

```text
~/Library/Application Support/List Reminder/reminders.json
```

复制整个 `List Reminder` 数据文件夹即可备份或迁移。应用以原子写入方式保存；文件无法读取时会先保留备份，无法备份则停止写入。

发布包与源码仓库不包含个人待办数据。

## 从源码构建

需要完整 Xcode，以及包含 macOS 26+ SDK 的命令行工具。

```sh
chmod +x build.sh test.sh
./build.sh
./test.sh
```

应用会生成在 `build/List Reminder.app`。构建脚本包含图标生成、arm64 编译、临时签名与签名校验。

## 项目结构

| 文件 | 职责 |
| --- | --- |
| `Sources/App.swift` | 主窗口、菜单栏、快捷键与应用生命周期 |
| `Sources/MainView.swift` | 待办列表、编辑界面与小组件外观设置 |
| `Sources/DesktopWidget.swift` | 桌面窗口、液态玻璃、双击、拖动、缩放与位置锁定 |
| `Sources/Store.swift` | 数据模型、保存恢复、设置兼容与撤销 |
| `Tests/Regression.swift` | 持久化、点击逻辑、锁定、异常写入与旧设置兼容验证 |
| `Tools/` | 应用图标生成工具 |

更多构建与验证细节见 **[开发说明](docs/DEVELOPMENT.md)**。

## 反馈

遇到问题或有功能建议，欢迎通过本仓库的 **[Issues](https://github.com/solitarystar123/DavidJiang/issues)** 反馈。请附上 macOS 版本、芯片型号和复现步骤，并避免提交个人待办文件。
