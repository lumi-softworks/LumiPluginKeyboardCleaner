# LumiPluginKeyboardCleaner

📖 [English](README.md) | 中文版

「键盘清洁」插件的共享远程包，供 Lumi 等 CofficLab 同系列应用装配。

> 启用插件后选择一段较短的时长，点击「开始清洁」。全屏倒计时遮罩会覆盖每块屏幕，期间全系统忽略键盘输入，用户可以放心擦拭键盘而不会误打字符。会话总会自动结束，并提供两种手动退出方式。

## 包信息

- Manifest 包名：`LumiPluginKeyboardCleaner`（与仓库名一致）
- Product / Target：`PluginKeyboardCleaner`
- 平台：macOS 14+
- Swift tools：6.0

## 提供的能力

- 菜单栏弹窗：30 秒到 5 分钟的时长选项与「开始清洁」按钮。
- 无障碍权限检查，并提供一键打开系统设置的入口。
- 通过会话级 `CGEventTap`（头部插入）全局拦截键盘输入。
- 每块屏幕铺满全屏遮罩，显示实时倒计时与「结束清洁」按钮。
- 紧急键盘退出：按住 `⌃ ⌥ ⇧ + Esc` 一秒。
- 所选时长结束自动退出，不提供无限模式。
- 事件 tap 创建或启用失败时自动回滚：撤掉遮罩，绝不会留下「半屏蔽」状态。
- 持久化上次选择的清洁时长。
- 向宿主说明书与关于页面贡献条目。

## 安全模型

| 场景 | 行为 |
|---|---|
| 事件 tap 创建失败 | 会话不启动，内联提示检查权限 |
| 遮罩已显示但 tap 启用失败 | 撤掉遮罩，会话回到 idle |
| 会话期间宿主退出或插件被禁用 | 宿主进程立即释放 tap |
| 遮罩按钮 / 解锁组合键 / 定时器 | 任意一个都会结束会话并释放 tap |
| 无障碍权限被撤销 | 下一次启动在创建 tap 之前即被拒绝 |

插件不会记录、写入日志或保存任何按键内容，只比较 Esc 与修饰键状态来识别解锁组合键。插件不贡献 Agent 工具，避免语言模型发起屏蔽键盘的会话。

## 宿主能力

插件在启动时解析一个可选 Provider。未提供时插件仍可正常工作，只是时长偏好不会持久化。

| Provider | 提供时的效果 | 缺失时的效果 |
|---|---|---|
| `StorageProviding` | 在插件专属数据目录中持久化所选时长 | 每次启动恢复为 1 分钟 |

`DocsViewProviding`、`SettingViewProviding`、`MenuBarProviding` 均为可选贡献，缺失时对应入口不出现。

## 依赖与接入

```swift
dependencies: [
    .package(url: "https://github.com/lumi-softworks/LumiPluginKeyboardCleaner.git", from: "1.0.0")
]
```

```swift
.target(
    name: "FactoryLumi",
    dependencies: [
        .product(name: "PluginKeyboardCleaner", package: "LumiPluginKeyboardCleaner")
    ]
)
```

```swift
PluginKeyboardCleaner(
    configuration: KeyboardCleanerConfiguration(
        pluginID: "com.example.host.plugin.keyboard-cleaner",
        loggerSubsystem: "com.example.host.plugin.keyboard-cleaner",
        accessibilityIdentifierPrefix: "host.keyboard-cleaner"
    )
)
```

宿主应用不能开启 App Sandbox：会话级事件 tap 依赖无障碍信任，沙盒应用无法使用。

## 开发

```bash
swift build
swift test
```

## 许可

CofficLab 内部共享包，保留所有权利。