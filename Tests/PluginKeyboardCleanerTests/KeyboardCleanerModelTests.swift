import Foundation
import Testing
@testable import PluginKeyboardCleaner

@Suite("键盘清洁 · 时长与格式化")
struct KeyboardCleanerModelTests {
    @Test("只接受 10 秒到 5 分钟的时长")
    func validatesSessionBounds() {
        #expect(KeyboardCleanerDuration.validatedSession(9.9) == nil)
        #expect(KeyboardCleanerDuration.validatedSession(10) == 10)
        #expect(KeyboardCleanerDuration.validatedSession(60) == 60)
        #expect(KeyboardCleanerDuration.validatedSession(300) == 300)
        #expect(KeyboardCleanerDuration.validatedSession(300.6) == nil)
        #expect(KeyboardCleanerDuration.validatedSession(.infinity) == nil)
        #expect(KeyboardCleanerDuration.validatedSession(.nan) == nil)
    }

    @Test("持久化秒数无法匹配选项时回退到默认值")
    func restoresStoredDuration() {
        #expect(KeyboardCleanerDuration.fromStoredSeconds(nil) == .default)
        #expect(KeyboardCleanerDuration.fromStoredSeconds(45) == .default)
        #expect(KeyboardCleanerDuration.fromStoredSeconds(120) == .minutes2)
        #expect(KeyboardCleanerDuration.fromStoredSeconds(300) == .minutes5)
    }

    @Test("倒计时向上取整并以 m:ss 显示")
    func formatsCountdown() {
        #expect(KeyboardCleanerTimeFormatter.countdown(0) == "0:00")
        #expect(KeyboardCleanerTimeFormatter.countdown(-10) == "0:00")
        #expect(KeyboardCleanerTimeFormatter.countdown(0.2) == "0:01")
        #expect(KeyboardCleanerTimeFormatter.countdown(59) == "0:59")
        #expect(KeyboardCleanerTimeFormatter.countdown(59.2) == "1:00")
        #expect(KeyboardCleanerTimeFormatter.countdown(65) == "1:05")
        #expect(KeyboardCleanerTimeFormatter.countdown(300) == "5:00")
    }

    @Test("异常大的剩余时间被钳制")
    func clampsHugeCountdown() {
        #expect(KeyboardCleanerTimeFormatter.countdown(1_000_000) == "1440:00")
    }
}

@Suite("键盘清洁 · 本地存储")
@MainActor
struct KeyboardCleanerLocalStoreTests {
    @Test("时长偏好可以跨实例读回")
    func persistsDuration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("keyboard-cleaner-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let pluginID = "test.keyboard-cleaner"
        let store = KeyboardCleanerLocalStore(settingsDirectory: directory, pluginID: pluginID)

        #expect(store.storedDurationSeconds(pluginID: pluginID) == nil)
        #expect(store.setStoredDurationSeconds(120, pluginID: pluginID))
        #expect(store.storedDurationSeconds(pluginID: pluginID) == 120)

        let reloaded = KeyboardCleanerLocalStore(settingsDirectory: directory, pluginID: pluginID)
        #expect(reloaded.storedDurationSeconds(pluginID: pluginID) == 120)
    }

    @Test("未配置的插件 ID 读写都不会崩溃")
    func unconfiguredPluginIsInert() {
        let store = KeyboardCleanerLocalStore()

        #expect(store.storedDurationSeconds(pluginID: "missing") == nil)
        #expect(store.setStoredDurationSeconds(60, pluginID: "missing") == false)
    }
}