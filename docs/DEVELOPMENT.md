# 开发与验证

## 技术与构建

Swift、AppKit、SwiftUI、Combine。运行目标为 Apple Silicon / macOS 26+。源码使用 Swift 5 语言模式，已在 Swift 6.2.3 编译器及本机 macOS SDK 下完成构建。

```sh
./build.sh
./test.sh
```

构建先把源码复制到 `/tmp` 临时目录，避免云同步文件夹的时间戳影响 Swift 编译。图标由 `Tools/Icon.swift` 绘制，再由 `Tools/icns.py` 封装。所有构建产物默认位于被 Git 忽略的 `build/` 中。

## 桌面窗口

`DesktopPanel` 是使用 `.nonactivatingPanel` 的 `NSPanel`，不会成为主窗口或键盘焦点窗口。它放在桌面图标层上方、普通应用层下方，关闭主窗口不退出应用。

任务行只在鼠标事件 `clickCount == 2` 时切换完成状态；辅助功能用户还可以调用该行的完成操作。

位置锁定会同时禁用窗口移动、标题拖动和角落缩放。待办行交互独立于锁定状态。外观设置中的尺寸控件仍可调整大小。设置文件兼容缺少锁定字段的旧版数据，默认解锁。

## 数据与测试隔离

默认数据位于用户 Application Support 中。回归测试使用随机临时目录，不读取或修改真实清单。

开发时可通过 `LIST_REMINDER_DATA_DIR` 指定隔离目录。发布应用的 Info.plist 不设置此变量。

## 已验证

回归测试覆盖：空内容与长度限制、编辑、单击/双击路由、完成/恢复、添加/删除/清除的撤销、重启持久化、设置边界、损坏数据备份、保存失败回滚、旧设置兼容、锁定保存、拖动/缩放守卫、锁定时完成待办、解锁。

真实应用界面检查覆盖：主窗口添加与双击完成、简约外观、位置锁定开关、重启后待办与外观设置及锁定状态恢复、主窗口关闭后小组件仍存在。临时测试事项检查后已清理。

当前自动化工具无法向桌面层窗口派发鼠标操作，因此桌面上的真实鼠标双击、拖动和角落缩放尚未完成自动化端到端实测。无显示器的测试环境会跳过依赖显示器的面板检查；点击与锁定守卫的回归测试仍运行。当前版本未进行 Intel 或 Apple 公证验证。

## Apple API

- [NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview)
- [nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel)
