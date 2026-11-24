import Foundation

/// 键盘清洁插件的品牌配置。
///
/// 共享远程包：宿主（Lumi / Wakey / …）在装配时注入自己的品牌配置，
/// 插件本身不写死任何宿主品牌信息。
///
/// - `pluginID`：插件唯一标识。宿主应传入自己的历史 id，
///   否则会丢失用户已保存的启用状态、清洁时长偏好与插件专属数据目录。
/// - `loggerSubsystem`：日志子系统，便于宿主在系统日志中区分品牌。
/// - `accessibilityIdentifierPrefix`：控件无障碍标识前缀，
///   宿主注入后可让 UI 测试按各自品牌定位控件。
public struct KeyboardCleanerConfiguration: Sendable {
    /// Lumi 品牌的默认插件标识。
    public static let defaultPluginID = "com.coffic.lumi.plugin.keyboard-cleaner"

    /// Lumi 品牌的默认日志子系统。
    public static let defaultLoggerSubsystem = "com.coffic.lumi.plugin.keyboard-cleaner"

    /// 插件唯一标识。
    public let pluginID: String

    /// 日志子系统。
    public let loggerSubsystem: String

    /// 控件的无障碍标识前缀。
    public let accessibilityIdentifierPrefix: String

    public init(
        pluginID: String = KeyboardCleanerConfiguration.defaultPluginID,
        loggerSubsystem: String = KeyboardCleanerConfiguration.defaultLoggerSubsystem,
        accessibilityIdentifierPrefix: String = "keyboard-cleaner"
    ) {
        self.pluginID = pluginID
        self.loggerSubsystem = loggerSubsystem
        self.accessibilityIdentifierPrefix = accessibilityIdentifierPrefix
    }
}