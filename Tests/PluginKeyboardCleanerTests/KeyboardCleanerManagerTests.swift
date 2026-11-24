import Foundation
import Testing
@testable import PluginKeyboardCleaner

@Suite("键盘清洁 · 会话状态机")
@MainActor
struct KeyboardCleanerManagerTests {
    private func makeManager(
        trusted: Bool = true,
        clock: TestClock = TestClock()
    ) -> (KeyboardCleanerManager, FakeKeyboardCleanerEnvironment, TestClock) {
        let environment = FakeKeyboardCleanerEnvironment()
        environment.isAccessibilityTrusted = trusted
        let manager = KeyboardCleanerManager(
            environment: environment,
            monotonicTime: { clock.now }
        )
        return (manager, environment, clock)
    }

    @Test("启动成功后遮罩、拦截器、计时器与活动令牌就绪")
    func startWiresEveryComponent() {
        let (manager, environment, _) = makeManager()

        let failure = manager.startCleaning()

        #expect(failure == nil)
        #expect(manager.isCleaning)
        #expect(environment.interceptor.prepareCount == 1)
        #expect(environment.interceptor.isActive)
        #expect(environment.overlay.presentations.count == 1)
        #expect(environment.overlay.presentations.first?.duration == 60)
        #expect(environment.scheduledSessionDelays == [60])
        #expect(environment.pollingInterval == 0.05)
        #expect(environment.beganActivityCount == 1)

        if case let .cleaning(startedAt, duration) = manager.state {
            #expect(startedAt == environment.currentDate)
            #expect(duration == 60)
        } else {
            Issue.record("会话应处于 cleaning 状态")
        }
    }

    @Test("缺少无障碍权限时拒绝启动并触发系统提示")
    func permissionDeniedStopsBeforeAnyTap() {
        let (manager, environment, _) = makeManager(trusted: false)

        let failure = manager.startCleaning()

        #expect(failure == .permissionRequired)
        #expect(environment.requestAccessibilityCount == 1)
        #expect(environment.interceptor.prepareCount == 0)
        #expect(environment.overlay.presentations.isEmpty)
        #expect(manager.isCleaning == false)
    }

    @Test("事件 tap 创建失败时不会显示遮罩")
    func prepareFailureLeavesNoSideEffects() {
        let (manager, environment, _) = makeManager()
        environment.interceptor.prepareSucceeds = false

        let failure = manager.startCleaning()

        #expect(failure == .interceptorUnavailable)
        #expect(environment.overlay.presentations.isEmpty)
        #expect(environment.scheduledSessionDelays.isEmpty)
        #expect(manager.isCleaning == false)
    }

    @Test("tap 启用失败会完整回滚遮罩与活动令牌")
    func activateFailureRollsBackEverything() {
        let (manager, environment, _) = makeManager()
        environment.interceptor.activateSucceeds = false

        let failure = manager.startCleaning()

        #expect(failure == .interceptorUnavailable)
        #expect(environment.overlay.presentations.count == 1)
        #expect(environment.overlay.hideCount == 1)
        #expect(environment.interceptor.deactivateCount >= 1)
        #expect(environment.endedActivityCount == 1)
        #expect(environment.scheduledSessionDelays.isEmpty)
        #expect(environment.pollingInterval == nil)
        #expect(manager.isCleaning == false)
        #expect(manager.lastStopReason == nil)
    }

    @Test("时长必须落在安全区间内", arguments: [0.0, 5.0, 9.9, 300.6, 3_600.0])
    func rejectsUnsafeDurations(seconds: TimeInterval) {
        let (manager, environment, _) = makeManager()

        let failure = manager.startCleaning(duration: seconds)

        #expect(failure == .invalidDuration)
        #expect(environment.interceptor.prepareCount == 0)
    }

    @Test("允许的最长时长为五分钟")
    func acceptsMaximumDuration() {
        let (manager, environment, _) = makeManager()

        let failure = manager.startCleaning(duration: 300)

        #expect(failure == nil)
        #expect(environment.scheduledSessionDelays == [300])
    }

    @Test("重复启动被拒绝且不创建新会话")
    func rejectsDuplicateStart() {
        let (manager, environment, _) = makeManager()

        #expect(manager.startCleaning() == nil)
        let second = manager.startCleaning()

        #expect(second == .alreadyCleaning)
        #expect(environment.interceptor.prepareCount == 1)
        #expect(environment.overlay.presentations.count == 1)
    }

    @Test("计时结束会完整清理会话")
    func timerFinishesSession() {
        let (manager, environment, _) = makeManager()
        #expect(manager.startCleaning() == nil)

        environment.fireSessionTimer()

        #expect(manager.isCleaning == false)
        #expect(manager.lastStopReason == .finished)
        #expect(environment.overlay.hideCount == 1)
        #expect(environment.interceptor.isActive == false)
        #expect(environment.endedActivityCount == 1)
        #expect(environment.cancelledSessionTimerCount >= 1)
        #expect(environment.stoppedPollingCount >= 1)
    }

    @Test("遮罩按钮结束会话")
    func overlayStopEndsSession() {
        let (manager, environment, _) = makeManager()
        #expect(manager.startCleaning() == nil)

        environment.overlay.triggerStop()

        #expect(manager.isCleaning == false)
        #expect(manager.lastStopReason == .userRequested)
        #expect(environment.overlay.hideCount == 1)
    }

    @Test("解锁组合键按住一秒后结束会话")
    func unlockChordEndsSession() {
        let (manager, environment, clock) = makeManager()
        #expect(manager.startCleaning() == nil)

        environment.interceptor.send(
            KeyboardInterceptEvent(kind: .flagsChanged, keyCode: 0, modifiers: .unlockChord)
        )
        environment.interceptor.send(
            KeyboardInterceptEvent(kind: .keyDown, keyCode: KeyboardUnlockChord.escapeKeyCode, modifiers: .unlockChord)
        )

        environment.fireUnlockPoll()
        #expect(manager.isCleaning)

        clock.advance(1.1)
        environment.fireUnlockPoll()

        #expect(manager.isCleaning == false)
        #expect(manager.lastStopReason == .unlockChord)
    }

    @Test("普通按键轮询不会结束会话")
    func pollingWithoutChordKeepsSession() {
        let (manager, environment, _) = makeManager()
        #expect(manager.startCleaning() == nil)

        environment.interceptor.send(
            KeyboardInterceptEvent(kind: .keyDown, keyCode: 0, modifiers: [])
        )
        environment.fireUnlockPoll()

        #expect(manager.isCleaning)
    }

    @Test("重复停止不会重复清理")
    func duplicateStopIsIdempotent() {
        let (manager, environment, _) = makeManager()
        #expect(manager.startCleaning() == nil)

        manager.stopCleaning(reason: .userRequested)
        manager.stopCleaning(reason: .shutdown)

        #expect(environment.overlay.hideCount == 1)
        #expect(manager.lastStopReason == .userRequested)
    }

    @Test("使用用户选择的时长启动")
    func usesSelectedDuration() {
        let (manager, environment, _) = makeManager()
        manager.selectDuration(.minutes3)

        #expect(manager.startCleaning() == nil)
        #expect(environment.scheduledSessionDelays == [180])
        #expect(environment.overlay.presentations.first?.duration == 180)
    }

    @Test("显示器唤醒不可用时仍可清洁")
    func worksWithoutDisplayActivity() {
        let (manager, environment, _) = makeManager()
        environment.displayActivityAvailable = false

        let failure = manager.startCleaning()

        #expect(failure == nil)
        #expect(environment.beganActivityCount == 0)
        #expect(environment.endedActivityCount == 0)
        #expect(manager.isCleaning)
    }
}