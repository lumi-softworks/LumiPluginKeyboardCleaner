# LumiPluginKeyboardCleaner

📖 English | [中文版](README_zh.md)

Shared remote package for the "Keyboard Cleaner" plugin, assembled by CofficLab sibling apps such as Lumi.

> Enable the plugin, choose a short duration, and click **Start Cleaning**. All keyboard input is ignored system-wide while a full-screen countdown overlay covers every display, so the keyboard can be wiped without typing anything by accident. A session always ends on its own and provides two manual exits.

## Package

- Manifest package name: `LumiPluginKeyboardCleaner` (matches the repository name)
- Product / Target: `PluginKeyboardCleaner`
- Platform: macOS 14+
- Swift tools: 6.0

## What It Provides

- Menu bar popup with duration presets (30 seconds to 5 minutes) and a start button.
- Accessibility permission check with a one-click path to System Settings.
- Global keyboard interception through a `CGEventTap` at the session event tap, inserted at the head of the tap list.
- Full-screen overlay on every display with a live countdown and an **End Cleaning** button.
- Emergency keyboard exit: hold `⌃ ⌥ ⇧ + Esc` for one second.
- Automatic end when the selected duration runs out. There is no unlimited mode.
- Automatic rollback if the tap cannot be created or activated: the overlay is removed and the keyboard is never left in a half-blocked state.
- Persisted duration preference.
- Manual and About entries in the host's docs surface.

## Safety Model

| Situation | Behavior |
|---|---|
| Tap creation fails | Session does not start; an inline error explains the permission check |
| Overlay shown but tap activation fails | Overlay is removed, session returns to idle |
| Host quits or plugin is disabled mid-session | Tap is released immediately by the host process |
| Overlay button, unlock chord, or timer | Any one ends the session and releases the tap |
| Accessibility permission revoked | Next start attempt is rejected before any tap is created |

Keystrokes are never recorded, logged, or stored. The plugin only compares the escape key and modifier state to detect the unlock chord. No Agent tools are contributed, so a language model cannot start a keyboard-blocking session.

## Host Capabilities

The plugin resolves one optional provider at boot. Hosts that do not provide it still get a working plugin — only the duration preference is not persisted.

| Provider | Effect when present | Effect when absent |
|---|---|---|
| `StorageProviding` | Persists the selected duration under the plugin's own data directory | Duration resets to 1 minute on each launch |

`DocsViewProviding`, `SettingViewProviding`, and `MenuBarProviding` are optional contributions; missing providers simply omit that surface.

## Dependencies and Integration

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

The host app must not be sandboxed: a session-level event tap requires Accessibility trust and is not available to sandboxed apps.

## Development

```bash
swift build
swift test
python3 ../path/to/Lumi/Scripts/check-localization.py   # when validating inside the Lumi repo
```

## License

Internal CofficLab package. All rights reserved.