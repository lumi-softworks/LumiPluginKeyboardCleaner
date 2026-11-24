import KernelCore
import ProviderDocsView
import ProviderMenuBar
import ProviderSettingView
import SwiftUI
import Testing
@testable import PluginKeyboardCleaner

/// 插件的核心契约是「onBoot 贡献状态栏弹窗、设置与说明书入口，
/// onShutdown 按 id 撤回」。这里通过真实的 Provider 实现验证注册表行为，
/// 不触碰视图渲染，也不启动真实的事件 tap。
@Suite("PluginKeyboardCleaner 插件生命周期")
@MainActor
struct PluginKeyboardCleanerLifecycleTests {
    private func makeKernel() -> KernelCoreContainer {
        KernelCoreContainer()
    }

    private func makePlugin(
        configuration: KeyboardCleanerConfiguration = KeyboardCleanerConfiguration()
    ) -> PluginKeyboardCleaner {
        PluginKeyboardCleaner(configuration: configuration, policy: .enabledByDefault)
    }

    @Test("onBoot 注册状态栏弹窗")
    func onBootRegistersPopupView() throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = makePlugin()
        try kernel.start(plugins: [plugin])

        #expect(popups.popupItems.count == 1)
        #expect(popups.popupItems.first?.id == "\(plugin.id).popup")
        #expect(popups.popupItems.first?.ownerPluginID == plugin.id)
    }

    @Test("弹窗按呈现权重排序")
    func popupUsesPresentationOrder() throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)

        popups.addPopup(MenuBarContribution(
            id: "OtherPlugin.popup",
            title: "Other",
            order: 200,
            ownerPluginID: "OtherPlugin"
        ) {
            Text("Other")
        })

        let plugin = makePlugin()
        try kernel.start(plugins: [plugin])

        #expect(popups.popupItems.first?.id == "\(plugin.id).popup")
        #expect(popups.popupItems.first?.order == PluginKeyboardCleaner.popupOrder)
    }

    @Test("onBoot 注册设置入口")
    func onBootRegistersSettingEntry() throws {
        let kernel = makeKernel()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = makePlugin()
        try kernel.start(plugins: [plugin])

        #expect(settings.entries.count == 1)
        #expect(settings.entries.first?.id == plugin.id)
        #expect(settings.entries.first?.title == plugin.metadata.name)
    }

    @Test("onBoot 贡献说明书与关于条目")
    func onBootContributesDocs() throws {
        let kernel = makeKernel()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = makePlugin()
        try kernel.start(plugins: [plugin])

        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries.first?.id == plugin.id)
        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries.first?.id == plugin.id)
    }

    @Test("onShutdown 撤回本插件贡献")
    func onShutdownRemovesContributions() throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        let settings = DefaultSettingViewProviding()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = makePlugin()
        try kernel.start(plugins: [plugin])
        #expect(popups.popupItems.count == 1)

        try kernel.stop()

        #expect(popups.popupItems.isEmpty)
        #expect(settings.entries.isEmpty)
        #expect(docs.manualEntries.isEmpty)
        #expect(docs.aboutEntries.isEmpty)
    }

    @Test("禁用自动撤回，重新启用恢复弹窗")
    func disableAndEnableRestoresPopup() async throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        let plugin = makePlugin()
        try kernel.start(plugins: [plugin])

        try await kernel.disablePlugin(id: plugin.id)
        #expect(popups.popupItems.isEmpty)

        try await kernel.enablePlugin(id: plugin.id)
        #expect(popups.popupItems.map(\.id) == ["\(plugin.id).popup"])
    }

    @Test("缺少 provider 时优雅降级")
    func degradesWithoutProviders() throws {
        let kernel = makeKernel()
        let plugin = makePlugin()

        try kernel.start(plugins: [plugin])
        try kernel.stop()

        #expect(kernel.registeredPluginCount == 0)
    }

    @Test("插件元数据与 id 一致")
    func metadataMatchesIdentity() {
        let plugin = PluginKeyboardCleaner()

        plugin.logger.info("PluginKeyboardCleaner metadata test")
        #expect(plugin.metadata.id == plugin.id)
        #expect(plugin.metadata.name.isEmpty == false)
        #expect(plugin.metadata.policy == .disabledByDefault)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .preview)
        #expect(plugin.order == 262)
    }

    @Test("禁用状态下启动时不贡献任何入口")
    func disabledByDefaultDoesNotBoot() throws {
        let kernel = makeKernel()
        let popups = DefaultMenuBarProviding()
        try kernel.registerProvider(MenuBarProviding.self, popups)

        let plugin = PluginKeyboardCleaner()
        try kernel.start(plugins: [plugin])

        #expect(popups.popupItems.isEmpty)
    }
}

/// onShutdown 在清洁仍进行时会立即释放事件 tap 与遮罩。
@Suite("PluginKeyboardCleaner 卸载时结束清洁", .serialized)
@MainActor
struct PluginKeyboardCleanerShutdownTests {
    @Test("卸载时若仍在清洁则结束会话")
    func shutdownStopsActiveSession() throws {
        let environment = FakeKeyboardCleanerEnvironment()
        let manager = KeyboardCleanerManager(environment: environment)
        let configuration = KeyboardCleanerConfiguration(pluginID: "test.keyboard-cleaner.shutdown")

        let plugin = PluginKeyboardCleaner(
            configuration: configuration,
            order: 262,
            policy: .enabledByDefault,
            manager: manager
        )

        #expect(manager.startCleaning() == nil)
        #expect(manager.isCleaning)

        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [plugin])
        try kernel.stop()

        #expect(manager.isCleaning == false)
        #expect(manager.lastStopReason == .shutdown)
        #expect(environment.overlay.hideCount == 1)
        #expect(environment.interceptor.isActive == false)
        #expect(environment.endedActivityCount == 1)
    }
}