import Foundation

/// 判断用户是否按住了解锁组合键。
///
/// 事件来自全局事件 tap，可能在任意线程送达；主线程的轮询也会读取状态，
/// 因此全部状态由内部锁保护。匹配器只比较按键码与修饰键状态，
/// 不保存、不记录任何实际输入。
final class KeyboardUnlockChordMatcher: @unchecked Sendable {
    private let chord: KeyboardUnlockChord
    private let now: @Sendable () -> TimeInterval
    private let lock = NSLock()

    private var isPrimaryKeyDown = false
    private var modifiers: KeyboardModifiers = []
    private var holdStartedAt: TimeInterval?
    private var didSatisfy = false

    init(
        chord: KeyboardUnlockChord = .standard,
        now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.chord = chord
        self.now = now
    }

    func handle(_ event: KeyboardInterceptEvent) {
        lock.lock()
        defer { lock.unlock() }

        // 先按事件到达前的状态结算一次：按住满时长后，若松开事件先于
        // 轮询到达，也应该锁存为已解锁，而不是被这次松开直接抹掉。
        refreshLocked()

        switch event.kind {
        case .keyDown:
            modifiers = event.modifiers
            if event.keyCode == chord.keyCode {
                isPrimaryKeyDown = true
            }
        case .keyUp:
            modifiers = event.modifiers
            if event.keyCode == chord.keyCode {
                isPrimaryKeyDown = false
            }
        case .flagsChanged:
            modifiers = event.modifiers
        }

        refreshLocked()
    }

    /// 组合键是否已被按住足够久。
    ///
    /// 按住期间没有任何事件到达，所以仍需要轮询调用来确认「时间到」。
    func isSatisfied() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        refreshLocked()
        return didSatisfy
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        isPrimaryKeyDown = false
        modifiers = []
        holdStartedAt = nil
        didSatisfy = false
    }

    private func refreshLocked() {
        let isChordDown = isPrimaryKeyDown
            && modifiers.isSuperset(of: chord.requiredModifiers)
            && !modifiers.contains(.command)

        guard isChordDown else {
            // 组合键被松开后又重新按下时，应该重新计时。
            holdStartedAt = nil
            return
        }

        if let start = holdStartedAt {
            if now() - start >= chord.holdDuration {
                // 一旦达标就锁存：用户恰好在轮询前松手也不影响退出。
                didSatisfy = true
            }
        } else {
            holdStartedAt = now()
        }
    }
}