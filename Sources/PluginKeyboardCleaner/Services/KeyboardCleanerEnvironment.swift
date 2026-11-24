import AppKit
import Foundation

/// 清洁期间持有「保持显示器唤醒」的系统活动令牌。
@MainActor
protocol KeyboardCleanerActivityToken: AnyObject {}

/// 清洁会话依赖的全部系统能力。
///
/// 事件 tap、全屏面板、系统权限与计时器都有真实副作用（会真的屏蔽键盘、
/// 弹出全屏遮罩、打开系统设置），测试进程里无法安全触发，因此收敛到本协议之后：
/// 生产环境由 `SystemKeyboardCleanerEnvironment` 提供真实实现，测试注入可控实现。
@MainActor
protocol KeyboardCleanerEnvironment: AnyObject {
    var isAccessibilityTrusted: Bool { get }
    func requestAccessibilityAccess()
    func openAccessibilitySettings()

    func makeKeyboardInterceptor() -> any KeyboardIntercepting
    func makeOverlayPresenter() -> any CleanOverlayPresenting

    func beginDisplayAwakeActivity() -> (any KeyboardCleanerActivityToken)?
    func endDisplayAwakeActivity(_ token: any KeyboardCleanerActivityToken)

    func scheduleSessionTimer(after delay: TimeInterval, handler: @escaping @MainActor () -> Void)
    func cancelSessionTimer()

    func startUnlockPolling(interval: TimeInterval, handler: @escaping @MainActor () -> Void)
    func stopUnlockPolling()

    func now() -> Date
}

@MainActor
final class SystemKeyboardCleanerEnvironment: KeyboardCleanerEnvironment {
    private let permission: any KeyboardCleanerPermissionChecking
    private var sessionTimer: Timer?
    private var pollingTimer: Timer?

    init(permission: any KeyboardCleanerPermissionChecking = SystemKeyboardCleanerPermission()) {
        self.permission = permission
    }

    var isAccessibilityTrusted: Bool { permission.isAccessibilityTrusted }

    func requestAccessibilityAccess() {
        permission.requestAccessibilityAccess()
    }

    func openAccessibilitySettings() {
        permission.openAccessibilitySettings()
    }

    func makeKeyboardInterceptor() -> any KeyboardIntercepting {
        GlobalKeyboardBlocker()
    }

    func makeOverlayPresenter() -> any CleanOverlayPresenting {
        CleanOverlayController()
    }

    func beginDisplayAwakeActivity() -> (any KeyboardCleanerActivityToken)? {
        let reason = KeyboardCleanerText.localized(
            "Keeping the display awake while the keyboard is being cleaned"
        )
        let raw = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleDisplaySleepDisabled],
            reason: reason
        )
        return ProcessInfoActivityToken(raw: raw)
    }

    func endDisplayAwakeActivity(_ token: any KeyboardCleanerActivityToken) {
        guard let token = token as? ProcessInfoActivityToken else { return }
        ProcessInfo.processInfo.endActivity(token.raw)
    }

    func scheduleSessionTimer(after delay: TimeInterval, handler: @escaping @MainActor () -> Void) {
        cancelSessionTimer()
        let timer = Timer(timeInterval: delay, repeats: false) { _ in
            Task { @MainActor in handler() }
        }
        RunLoop.main.add(timer, forMode: .common)
        sessionTimer = timer
    }

    func cancelSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    func startUnlockPolling(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        stopUnlockPolling()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in handler() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
    }

    func stopUnlockPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func now() -> Date { Date() }
}

@MainActor
private final class ProcessInfoActivityToken: KeyboardCleanerActivityToken {
    let raw: NSObjectProtocol

    init(raw: NSObjectProtocol) {
        self.raw = raw
    }
}