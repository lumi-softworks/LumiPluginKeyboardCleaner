import Testing
@testable import PluginKeyboardCleaner

@Suite("键盘清洁 · 解锁组合键匹配")
struct KeyboardUnlockChordMatcherTests {
    private let escape: UInt16 = KeyboardUnlockChord.escapeKeyCode

    private func matcher(clock: TestClock) -> KeyboardUnlockChordMatcher {
        KeyboardUnlockChordMatcher(now: { clock.now })
    }

    private func flags(_ modifiers: KeyboardModifiers) -> KeyboardInterceptEvent {
        KeyboardInterceptEvent(kind: .flagsChanged, keyCode: 0, modifiers: modifiers)
    }

    private func escapeDown(_ modifiers: KeyboardModifiers) -> KeyboardInterceptEvent {
        KeyboardInterceptEvent(kind: .keyDown, keyCode: escape, modifiers: modifiers)
    }

    private func escapeUp(_ modifiers: KeyboardModifiers) -> KeyboardInterceptEvent {
        KeyboardInterceptEvent(kind: .keyUp, keyCode: escape, modifiers: modifiers)
    }

    @Test("缺少任一修饰键都不会解锁")
    func requiresEveryModifier() {
        let clock = TestClock()
        let matcher = matcher(clock: clock)

        matcher.handle(flags([.control, .option]))
        matcher.handle(escapeDown([.control, .option]))
        clock.advance(2)

        #expect(matcher.isSatisfied() == false)
    }

    @Test("按住满一秒才解锁")
    func satisfiesAfterHoldDuration() {
        let clock = TestClock()
        let matcher = matcher(clock: clock)

        matcher.handle(flags(.unlockChord))
        matcher.handle(escapeDown(.unlockChord))

        clock.advance(0.9)
        #expect(matcher.isSatisfied() == false)

        clock.advance(0.2)
        #expect(matcher.isSatisfied())
    }

    @Test("按住期间没有事件也能通过轮询确认")
    func pollingConfirmsSilentHold() {
        let clock = TestClock()
        let matcher = matcher(clock: clock)

        matcher.handle(escapeDown(.unlockChord))
        clock.advance(1.05)

        #expect(matcher.isSatisfied())
    }

    @Test("松开 Esc 会重新计时")
    func releasingResetsHold() {
        let clock = TestClock()
        let matcher = matcher(clock: clock)

        matcher.handle(escapeDown(.unlockChord))
        clock.advance(0.7)
        matcher.handle(escapeUp(.unlockChord))

        clock.advance(0.6)
        #expect(matcher.isSatisfied() == false)

        matcher.handle(escapeDown(.unlockChord))
        clock.advance(0.5)
        #expect(matcher.isSatisfied() == false)

        clock.advance(0.6)
        #expect(matcher.isSatisfied())
    }

    @Test("松开修饰键会重新计时")
    func releasingModifierResetsHold() {
        let clock = TestClock()
        let matcher = matcher(clock: clock)

        matcher.handle(escapeDown(.unlockChord))
        clock.advance(0.8)
        matcher.handle(flags([.control, .option]))

        clock.advance(0.5)
        #expect(matcher.isSatisfied() == false)

        matcher.handle(flags(.unlockChord))
        clock.advance(0.4)
        #expect(matcher.isSatisfied() == false)

        clock.advance(0.7)
        #expect(matcher.isSatisfied())
    }

    @Test("带 Command 的组合不触发")
    func commandDisqualifiesChord() {
        let clock = TestClock()
        let matcher = matcher(clock: clock)
        let withCommand: KeyboardModifiers = [.control, .option, .shift, .command]

        matcher.handle(escapeDown(withCommand))
        clock.advance(3)

        #expect(matcher.isSatisfied() == false)
    }

    @Test("达标后即使立刻松手也保持已解锁")
    func satisfactionsLatchesUntilReset() {
        let clock = TestClock()
        let matcher = matcher(clock: clock)

        matcher.handle(escapeDown(.unlockChord))
        clock.advance(1.2)
        matcher.handle(escapeUp(.unlockChord))

        #expect(matcher.isSatisfied())

        matcher.reset()
        #expect(matcher.isSatisfied() == false)
    }

    @Test("普通按键不会满足组合键")
    func otherKeysDoNotSatisfy() {
        let clock = TestClock()
        let matcher = matcher(clock: clock)

        matcher.handle(KeyboardInterceptEvent(kind: .keyDown, keyCode: 0, modifiers: .unlockChord))
        clock.advance(2)

        #expect(matcher.isSatisfied() == false)
    }
}