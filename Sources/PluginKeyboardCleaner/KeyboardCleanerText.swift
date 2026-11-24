import Foundation

/// 插件资源表的文案入口。
///
/// SwiftUI 字面量用 `Text(..., tableName: "KeyboardCleaner", bundle: .module)`；
/// 需要字符串的 API（`AppButton`、`LandingHero` 等）走这里。
/// `String(localized:)` 的 key 需要编译期字面量，动态 key 取不到条目，
/// 因此统一用 `Bundle.module.localizedString`。
enum KeyboardCleanerText {
    static func localized(_ key: String) -> String {
        Bundle.module.localizedString(forKey: key, value: key, table: "KeyboardCleaner")
    }
}