import Foundation
@testable import PluginKeyboardCleaner

/// 可控的键盘拦截器：记录启动顺序，并允许注入失败。
@MainActor
final class FakeKeyboardInterceptor: KeyboardIntercepting {
    var prepareSucceeds = true
    var activateSucceeds = true

    private(set) var prepareCount = 0
    private(set) var activateCount = 0
    private(set) var deactivateCount = 0
    private(set) var isPrepared = false
    private(set) var isActive = false
    private(set) var handler: (@Sendable (KeyboardInterceptEvent) -> Void)?

    func prepare(handler: @escaping @Sendable (KeyboardInterceptEvent) -> Void) -> Bool {
        prepareCount += 1
        guard prepareSucceeds else { return false }
        self.handler = handler
        isPrepared = true
        return true
    }

    func activate() -> Bool {
        activateCount += 1
        guard isPrepared, activateSucceeds else { return false }
        isActive = true
        return true
    }

    func deactivate() {
        deactivateCount += 1
        isPrepared = false
        isActive = false
        handler = nil
    }

    /// 模拟事件 tap 回调。
    func send(_ event: KeyboardInterceptEvent) {
        handler?(event)
    }
}

/// 可控的全屏遮罩。
@MainActor
final class FakeCleanOverlay: CleanOverlayPresenting {
    struct Presentation: Equatable {
        let startedAt: Date
        let duration: TimeInterval
    }

    private(set) var presentations: [Presentation] = []
    private(set) var hideCount = 0
    private(set) var onStop: (@MainActor () -> Void)?

    func show(startedAt: Date, duration: TimeInterval, onStop: @escaping @MainActor () -> Void) {
        presentations.append(Presentation(startedAt: startedAt, duration: duration))
        self.onStop = onStop
    }

    func hide() {
        hideCount += 1
        onStop = nil
    }

    func triggerStop() {
        onStop?()
    }
}

/// 可控的环境：所有副作用都被记录，不会真的屏蔽键盘或点亮屏幕。
@MainActor
final class FakeKeyboardCleanerEnvironment: KeyboardCleanerEnvironment {
    var isAccessibilityTrusted = true
    var displayActivityAvailable = true

    let interceptor = FakeKeyboardInterceptor()
    let overlay = FakeCleanOverlay()

    private(set) var requestAccessibilityCount = 0
    private(set) var openSettingsCount = 0
    private(set) var beganActivityCount = 0
    private(set) var endedActivityCount = 0
    private(set) var activeTokens: [FakeActivityToken] = []
    private(set) var scheduledSessionDelays: [TimeInterval] = []
    private(set) var cancelledSessionTimerCount = 0
    private(set) var pollingInterval: TimeInterval?
    private(set) var stoppedPollingCount = 0

    var currentDate = Date(timeIntervalSince1970: 1_700_000_000)
    private var sessionTimerHandler: (@MainActor () -> Void)?
    private var pollingHandler: (@MainActor () -> Void)?

    func requestAccessibilityAccess() {
        requestAccessibilityCount += 1
    }

    func openAccessibilitySettings() {
        openSettingsCount += 1
    }

    func makeKeyboardInterceptor() -> any KeyboardIntercepting {
        interceptor
    }

    func makeOverlayPresenter() -> any CleanOverlayPresenting {
        overlay
    }

    func beginDisplayAwakeActivity() -> (any KeyboardCleanerActivityToken)? {
        guard displayActivityAvailable else { return nil }
        beganActivityCount += 1
        let token = FakeActivityToken()
        activeTokens.append(token)
        return token
    }

    func endDisplayAwakeActivity(_ token: any KeyboardCleanerActivityToken) {
        endedActivityCount += 1
    }

    func scheduleSessionTimer(after delay: TimeInterval, handler: @escaping @MainActor () -> Void) {
        scheduledSessionDelays.append(delay)
        sessionTimerHandler = handler
    }

    func cancelSessionTimer() {
        cancelledSessionTimerCount += 1
        sessionTimerHandler = nil
    }

    func startUnlockPolling(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        pollingInterval = interval
        pollingHandler = handler
    }

    func stopUnlockPolling() {
        stoppedPollingCount += 1
        pollingHandler = nil
    }

    func now() -> Date {
        currentDate
    }

    // MARK: - Test Helpers

    func fireSessionTimer() {
        let handler = sessionTimerHandler
        sessionTimerHandler = nil
        handler?()
    }

    func fireUnlockPoll() {
        pollingHandler?()
    }
}

@MainActor
final class FakeActivityToken: KeyboardCleanerActivityToken {}

/// 线程安全的手动时钟，供组合键匹配器测试推进时间。
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time: TimeInterval = 0

    var now: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return time
    }

    func advance(_ delta: TimeInterval) {
        lock.lock()
        time += delta
        lock.unlock()
    }
}