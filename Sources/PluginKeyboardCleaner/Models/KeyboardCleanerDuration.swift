import Foundation

/// 清洁会话的可选时长。
///
/// 刻意不提供「无限」选项：键盘被全局屏蔽却忘了退出，会把用户困在
/// 一个看不见输入反馈的状态里。最长 5 分钟，且总会自动结束。
enum KeyboardCleanerDuration: Int, CaseIterable, Identifiable, Sendable {
    case seconds30 = 30
    case minute1 = 60
    case minutes2 = 120
    case minutes3 = 180
    case minutes5 = 300

    static let `default` = KeyboardCleanerDuration.minute1

    /// 会话时长的合法区间（秒）。
    static let shortestSession: TimeInterval = 10
    static let longestSession: TimeInterval = 300

    var id: Int { rawValue }

    var seconds: TimeInterval { TimeInterval(rawValue) }

    /// 设置页使用的完整名称。
    var title: String {
        switch self {
        case .seconds30: KeyboardCleanerText.localized("30 seconds")
        case .minute1: KeyboardCleanerText.localized("1 minute")
        case .minutes2: KeyboardCleanerText.localized("2 minutes")
        case .minutes3: KeyboardCleanerText.localized("3 minutes")
        case .minutes5: KeyboardCleanerText.localized("5 minutes")
        }
    }

    /// 菜单栏弹窗使用的紧凑名称。
    var shortTitle: String {
        switch self {
        case .seconds30: KeyboardCleanerText.localized("30s")
        case .minute1: KeyboardCleanerText.localized("1m")
        case .minutes2: KeyboardCleanerText.localized("2m")
        case .minutes3: KeyboardCleanerText.localized("3m")
        case .minutes5: KeyboardCleanerText.localized("5m")
        }
    }

    /// 校验并规整会话时长；超出安全区间时返回 nil。
    static func validatedSession(_ seconds: TimeInterval) -> TimeInterval? {
        guard seconds.isFinite,
              seconds >= shortestSession,
              seconds <= longestSession else {
            return nil
        }
        return seconds.rounded()
    }

    /// 从持久化的秒数还原选项；无法精确匹配时回退到默认值。
    static func fromStoredSeconds(_ seconds: Int?) -> KeyboardCleanerDuration {
        guard let seconds, let option = KeyboardCleanerDuration(rawValue: seconds) else {
            return .default
        }
        return option
    }
}