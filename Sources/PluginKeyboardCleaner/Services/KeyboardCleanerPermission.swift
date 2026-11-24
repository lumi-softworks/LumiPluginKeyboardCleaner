import AppKit
import ApplicationServices

/// 无障碍权限：CGEventTap 的 `defaultTap` 需要宿主进程被信任。
@MainActor
protocol KeyboardCleanerPermissionChecking: AnyObject {
    var isAccessibilityTrusted: Bool { get }
    func requestAccessibilityAccess()
    func openAccessibilitySettings()
}

@MainActor
final class SystemKeyboardCleanerPermission: KeyboardCleanerPermissionChecking {
    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityAccess() {
        // 不直接引用全局变量 kAXTrustedCheckOptionPrompt（Swift 6 视为共享可变状态），
        // 其值就是这个固定的键名。
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}