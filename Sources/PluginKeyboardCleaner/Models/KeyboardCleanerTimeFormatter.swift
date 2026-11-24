import Foundation

enum KeyboardCleanerTimeFormatter {
    /// 把剩余秒数格式化为 `m:ss`。
    ///
    /// 向上取整，避免倒计时刚开始就从 0:59 起跳；负数与异常值钳制到安全范围
    /// （数值来自墙钟差值，系统时间跳变时可能是负数或极大值）。
    static func countdown(_ remaining: TimeInterval) -> String {
        let clamped = min(max(remaining, 0), 86_400)
        let totalSeconds = Int(clamped.rounded(.up))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}