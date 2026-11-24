import Foundation
import LumiLoggingKit
import Observation
import OSLog
import ProviderStorage

/// 清洁会话的结束原因。
enum KeyboardCleanerStopReason: String, Equatable, Sendable {
    /// 计时结束，自动退出。
    case finished
    /// 用户点击了遮罩上的「结束清洁」。
    case userRequested
    /// 用户按住了 ⌃ ⌥ ⇧ + Esc。
    case unlockChord
    /// 插件被卸载或宿主退出。
    case shutdown
}

/// 启动清洁失败的原因。
enum KeyboardCleanerStartFailure: Equatable, Sendable {
    case alreadyCleaning
    case permissionRequired
    case interceptorUnavailable
    case invalidDuration
}

/// 清洁会话状态。
enum KeyboardCleanerSessionState: Equatable {
    case idle
    case cleaning(startedAt: Date, duration: TimeInterval)
}

/// 键盘清洁会话管理器。
///
/// 一次会话的启动顺序是刻意安排的：
/// 1. 校验无障碍权限；
/// 2. 创建但暂不启用事件 tap；
/// 3. 在所有屏幕铺开遮罩并显示倒计时；
/// 4. 启用事件 tap，开始屏蔽键盘。
///
/// 任一步失败都会回滚已完成的步骤，保证「遮罩在但没有拦截」或
/// 「拦截在但没有遮罩」这两种半成品状态不会留给用户。
@MainActor
@Observable
final class KeyboardCleanerManager: SuperLog {
    nonisolated static let emoji = "🧽"

    static let shared = KeyboardCleanerManager()

    // MARK: - Observable State

    private(set) var state: KeyboardCleanerSessionState = .idle

    /// 最近一次会话的结束原因；尚未结束过会话时为 nil。
    private(set) var lastStopReason: KeyboardCleanerStopReason?

    /// 宿主进程当前是否已被授予无障碍权限。
    private(set) var hasAccessibilityPermission: Bool

    /// 用户选择的清洁时长，供下一次会话使用并持久化。
    private(set) var selectedDuration: KeyboardCleanerDuration = .default

    var isCleaning: Bool {
        if case .cleaning = state { return true }
        return false
    }

    // MARK: - Dependencies

    private let environment: any KeyboardCleanerEnvironment
    private let monotonicTime: @Sendable () -> TimeInterval

    private var interceptor: (any KeyboardIntercepting)?
    private var overlay: (any CleanOverlayPresenting)?
    private var matcher: KeyboardUnlockChordMatcher?
    private var activity: (any KeyboardCleanerActivityToken)?

    private var pluginID = KeyboardCleanerConfiguration.defaultPluginID

    init(
        environment: any KeyboardCleanerEnvironment = SystemKeyboardCleanerEnvironment(),
        monotonicTime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.environment = environment
        self.monotonicTime = monotonicTime
        self.hasAccessibilityPermission = environment.isAccessibilityTrusted
    }

    // MARK: - Host Wiring

    /// 宿主在 `onBoot` 时调用一次，绑定存储目录并恢复上次的时长偏好。
    func configure(storage: (any StorageProviding)?, pluginID: String) {
        self.pluginID = pluginID
        KeyboardCleanerLocalStore.shared.configure(storage: storage, pluginID: pluginID)
        selectedDuration = KeyboardCleanerDuration.fromStoredSeconds(
            KeyboardCleanerLocalStore.shared.storedDurationSeconds(pluginID: pluginID)
        )
        refreshAccessibilityPermission()
    }

    func refreshAccessibilityPermission() {
        hasAccessibilityPermission = environment.isAccessibilityTrusted
    }

    func openAccessibilitySettings() {
        environment.openAccessibilitySettings()
    }

    /// 选择下一次会话的时长并持久化。
    func selectDuration(_ duration: KeyboardCleanerDuration) {
        selectedDuration = duration
        let pluginID = pluginID
        KeyboardCleanerLocalStore.shared.setStoredDurationSeconds(duration.rawValue, pluginID: pluginID)
    }

    // MARK: - Session Lifecycle

    /// 开始清洁。成功返回 nil；失败返回原因，且不会留下任何系统副作用。
    ///
    /// - Parameter duration: 本次时长（秒）；传 nil 时使用用户选择的时长。
    @discardableResult
    func startCleaning(duration: TimeInterval? = nil) -> KeyboardCleanerStartFailure? {
        guard case .idle = state else {
            return .alreadyCleaning
        }
        guard let seconds = KeyboardCleanerDuration.validatedSession(
            duration ?? selectedDuration.seconds
        ) else {
            return .invalidDuration
        }

        refreshAccessibilityPermission()
        guard hasAccessibilityPermission else {
            // 触发系统自带的授权提示；用户仍可从弹窗再次打开系统设置。
            environment.requestAccessibilityAccess()
            return .permissionRequired
        }

        let matcher = KeyboardUnlockChordMatcher(
            chord: .standard,
            now: monotonicTime
        )
        let interceptor = environment.makeKeyboardInterceptor()

        guard interceptor.prepare(handler: { event in
            matcher.handle(event)
        }) else {
            interceptor.deactivate()
            return .interceptorUnavailable
        }

        let overlay = environment.makeOverlayPresenter()
        let startedAt = environment.now()
        let activity = environment.beginDisplayAwakeActivity()

        self.matcher = matcher
        self.interceptor = interceptor
        self.overlay = overlay
        self.activity = activity
        self.state = .cleaning(startedAt: startedAt, duration: seconds)

        overlay.show(startedAt: startedAt, duration: seconds) { [weak self] in
            self?.stopCleaning(reason: .userRequested)
        }

        guard interceptor.activate() else {
            // 遮罩已出现但拦截没起来：撤回全部步骤，不留半成品会话。
            teardown(markStopReason: nil)
            return .interceptorUnavailable
        }

        environment.scheduleSessionTimer(after: seconds) { [weak self] in
            self?.stopCleaning(reason: .finished)
        }
        environment.startUnlockPolling(interval: 0.05) { [weak self] in
            self?.handleUnlockPoll()
        }

        return nil
    }

    /// 结束清洁。未处于清洁状态时无操作。
    func stopCleaning(reason: KeyboardCleanerStopReason = .userRequested) {
        guard case .cleaning = state else { return }
        teardown(markStopReason: reason)
    }

    /// 由环境以固定间隔调用，检查紧急退出组合键是否已按住足够久。
    func handleUnlockPoll() {
        guard case .cleaning = state else { return }
        guard matcher?.isSatisfied() == true else { return }
        stopCleaning(reason: .unlockChord)
    }

    // MARK: - Private

    private func teardown(markStopReason reason: KeyboardCleanerStopReason?) {
        environment.cancelSessionTimer()
        environment.stopUnlockPolling()

        interceptor?.deactivate()
        overlay?.hide()
        if let activity {
            environment.endDisplayAwakeActivity(activity)
        }
        matcher?.reset()

        interceptor = nil
        overlay = nil
        matcher = nil
        activity = nil
        state = .idle
        if let reason {
            lastStopReason = reason
        }
    }
}