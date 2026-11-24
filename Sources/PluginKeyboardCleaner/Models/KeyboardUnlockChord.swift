import Foundation

/// 与 CoreGraphics 解耦的修饰键集合，便于在测试里直接构造事件。
struct KeyboardModifiers: OptionSet, Hashable, Sendable {
    let rawValue: UInt

    static let control = KeyboardModifiers(rawValue: 1 << 0)
    static let option = KeyboardModifiers(rawValue: 1 << 1)
    static let shift = KeyboardModifiers(rawValue: 1 << 2)
    static let command = KeyboardModifiers(rawValue: 1 << 3)

    /// 紧急解锁组合键的修饰部分。
    static let unlockChord: KeyboardModifiers = [.control, .option, .shift]
}

/// 从事件拦截器送入匹配器的键盘事件。
///
/// 只携带判断解锁组合键所需的最小信息；插件不会记录按键内容。
struct KeyboardInterceptEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case keyDown
        case keyUp
        case flagsChanged
    }

    let kind: Kind
    let keyCode: UInt16
    let modifiers: KeyboardModifiers
}

/// 紧急退出组合键：按住 ⌃ ⌥ ⇧ + Esc 一段时间即可结束清洁。
///
/// 选择 Esc 而不是普通字母键，是因为 Esc 不参与文本输入，
/// 用户擦拭时误触也不会留下内容；同时要求三个修饰键，
/// 进一步降低擦拭过程中误退出的概率。
struct KeyboardUnlockChord: Equatable, Sendable {
    static let escapeKeyCode: UInt16 = 53

    var keyCode: UInt16
    var requiredModifiers: KeyboardModifiers
    var holdDuration: TimeInterval

    init(
        keyCode: UInt16 = KeyboardUnlockChord.escapeKeyCode,
        requiredModifiers: KeyboardModifiers = .unlockChord,
        holdDuration: TimeInterval = 1.0
    ) {
        self.keyCode = keyCode
        self.requiredModifiers = requiredModifiers
        self.holdDuration = holdDuration
    }

    static let standard = KeyboardUnlockChord()
}