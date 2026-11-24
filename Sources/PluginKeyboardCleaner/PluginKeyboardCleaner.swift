import KernelCore
import OSLog
import ProviderDocsView
import ProviderMenuBar
import ProviderSettingView
import ProviderStorage
import SwiftUI

/// 键盘清洁插件：在限定时间内全局屏蔽键盘输入，让用户可以放心擦拭键盘。
///
/// 共享远程包：宿主（Lumi / Wakey / …）在装配时注入自己的品牌配置，
/// 插件本身不写死任何宿主品牌信息。
@MainActor
public final class PluginKeyboardCleaner: SuperPlugin {
    public let configuration: KeyboardCleanerConfiguration

    /// 日志子系统跟随宿主注入的子系统，便于宿主在系统日志中区分品牌。
    nonisolated let logger: Logger

    public let id: String
    public let order: Int
    public let metadata: PluginMetadata

    /// 菜单栏弹窗的呈现权重。
    ///
    /// 与启动顺序（`order`）解耦：这是纯呈现诉求，安全工具不必抢占菜单栏首位。
    public static let popupOrder = 10

    private let manager: KeyboardCleanerManager

    /// - Parameters:
    ///   - configuration: 品牌配置。宿主必须传入自己的历史 id，
    ///     否则会丢失用户已保存的启用状态、清洁时长偏好与插件专属数据目录。
    ///   - order: 插件启动顺序（数值越小越先启动）。
    ///   - policy: 启用策略。键盘拦截影响全系统输入，默认关闭，由用户显式开启。
    public convenience init(
        configuration: KeyboardCleanerConfiguration = KeyboardCleanerConfiguration(),
        order: Int = 262,
        policy: PluginEnablePolicy = .disabledByDefault
    ) {
        self.init(
            configuration: configuration,
            order: order,
            policy: policy,
            manager: KeyboardCleanerManager.shared
        )
    }

    init(
        configuration: KeyboardCleanerConfiguration,
        order: Int,
        policy: PluginEnablePolicy,
        manager: KeyboardCleanerManager
    ) {
        self.configuration = configuration
        self.id = configuration.pluginID
        self.order = order
        self.manager = manager
        self.metadata = PluginMetadata(
            id: configuration.pluginID,
            name: String(
                localized: "Keyboard Cleaner",
                table: "KeyboardCleaner",
                bundle: .module,
                comment: "Name of the keyboard cleaning plugin"
            ),
            description: String(
                localized: "Temporarily ignore keyboard input so you can clean the keyboard",
                table: "KeyboardCleaner",
                bundle: .module,
                comment: "Description of what the Keyboard Cleaner plugin does"
            ),
            category: .system,
            stage: .preview,
            policy: policy
        )
        self.logger = Logger(subsystem: configuration.loggerSubsystem, category: "KeyboardCleaner")
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        manager.configure(
            storage: kernel.resolveProvider((any StorageProviding).self),
            pluginID: id
        )

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                KeyboardCleanerManualView()
            })
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                KeyboardCleanerAboutView()
            })
        }

        kernel.resolveProvider((any SettingViewProviding).self)?
            .addEntries([
                SettingEntryItem(
                    id: id,
                    title: metadata.name,
                    systemImage: "keyboard",
                    detail: {
                        KeyboardCleanerSettingsView(
                            configuration: self.configuration,
                            manager: self.manager
                        )
                    }
                )
            ])

        try contributeMenuBar(to: kernel)
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        try contributeMenuBar(to: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // `removeEntries(id:)` 同时撤回同一 id 的说明书与关于条目。
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])

        // 卸载插件时若仍在清洁，立即释放事件 tap 与遮罩。
        if manager.isCleaning {
            manager.stopCleaning(reason: .shutdown)
        }
    }

    private func contributeMenuBar(to kernel: KernelCoreContainer) throws {
        guard let menuBar = kernel.resolveProvider(MenuBarProviding.self) else { return }
        let ownerID = id
        try kernel.trackContribution {
            menuBar.removeItems(ownedBy: ownerID)
        }
        menuBar.addPopup(MenuBarContribution(
            id: "\(id).popup",
            title: metadata.name,
            order: Self.popupOrder,
            ownerPluginID: id
        ) {
            KeyboardCleanerPopupView(
                configuration: self.configuration,
                manager: self.manager
            )
        })
    }
}