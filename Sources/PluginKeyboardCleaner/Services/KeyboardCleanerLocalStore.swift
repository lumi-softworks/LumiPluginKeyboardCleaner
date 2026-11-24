import Foundation
import LumiLoggingKit
import OSLog
import ProviderStorage

/// 键盘清洁插件的本地存储。
///
/// 只持久化一个偏好：上次选择的清洁时长。
/// 存储位置：`storage.pluginDataDirectory(for:)/settings/settings.plist`
/// 按插件 ID 分开寻址，宿主注入自己的数据根目录，插件不写死宿主品牌信息。
@MainActor
final class KeyboardCleanerLocalStore: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🧽"

    private static let logger = Logger(
        subsystem: KeyboardCleanerConfiguration.defaultLoggerSubsystem,
        category: "plugin.keyboard-cleaner.local-store"
    )

    static let shared = KeyboardCleanerLocalStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "KeyboardCleanerLocalStore.queue", qos: .userInitiated)
    private var settingsDirectoriesByPluginID: [String: URL] = [:]

    convenience init() {
        self.init(settingsDirectory: nil)
    }

    /// 仅用于测试：直接绑定到一个固定的设置目录。
    init(settingsDirectory root: URL?, pluginID: String = KeyboardCleanerConfiguration.defaultPluginID) {
        guard let root else { return }
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create keyboard cleaner settings directory failed: \(error.localizedDescription)")
        }
        settingsDirectoriesByPluginID[pluginID] = root
    }

    func configure(storage: (any StorageProviding)?, pluginID: String) {
        guard let storage else {
            Self.logger.error("\(self.t)storage is nil; keyboard cleaner local store stays unconfigured")
            settingsDirectoriesByPluginID.removeValue(forKey: pluginID)
            return
        }

        let settingsRoot = storage.pluginDataDirectory(for: pluginID)
            .appendingPathComponent("settings", isDirectory: true)
        do {
            try fileManager.createDirectory(at: settingsRoot, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create keyboard cleaner settings directory failed: \(error.localizedDescription)")
        }
        settingsDirectoriesByPluginID[pluginID] = settingsRoot
    }

    func storedDurationSeconds(pluginID: String) -> Int? {
        queue.sync {
            readSettings(pluginID: pluginID)[Keys.selectedDurationSeconds] as? Int
        }
    }

    @discardableResult
    func setStoredDurationSeconds(_ seconds: Int, pluginID: String) -> Bool {
        queue.sync {
            var settings = readSettings(pluginID: pluginID)
            settings[Keys.selectedDurationSeconds] = seconds
            return writeSettings(settings, pluginID: pluginID)
        }
    }

    // MARK: - Private Helpers

    private func settingsFileURL(pluginID: String) -> URL? {
        settingsDirectoriesByPluginID[pluginID]?.appendingPathComponent("settings.plist")
    }

    private func readSettings(pluginID: String) -> [String: Any] {
        guard let url = settingsFileURL(pluginID: pluginID),
              fileManager.fileExists(atPath: url.path) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read keyboard cleaner settings failed: root plist is not a dictionary")
                quarantineCorruptSettings(pluginID: pluginID)
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read keyboard cleaner settings failed: \(error.localizedDescription)")
            quarantineCorruptSettings(pluginID: pluginID)
            return [:]
        }
    }

    @discardableResult
    private func writeSettings(_ settings: [String: Any], pluginID: String) -> Bool {
        guard let directory = settingsDirectoriesByPluginID[pluginID],
              let url = settingsFileURL(pluginID: pluginID) else {
            Self.logger.error("\(self.t)Persist keyboard cleaner settings skipped: store not configured")
            return false
        }

        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: settings, format: .binary, options: 0)
        } catch {
            Self.logger.error("\(self.t)Encode keyboard cleaner settings failed: \(error.localizedDescription)")
            return false
        }

        let tmp = directory.appendingPathComponent("settings.tmp")
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: url)
            }
            return true
        } catch {
            Self.logger.error("\(self.t)Persist keyboard cleaner settings failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmp)
            return false
        }
    }

    private func quarantineCorruptSettings(pluginID: String) {
        guard let directory = settingsDirectoriesByPluginID[pluginID] else { return }
        let url = directory.appendingPathComponent("settings.plist")
        let corruptURL = directory.appendingPathComponent("settings.corrupt.plist")
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            if fileManager.fileExists(atPath: corruptURL.path) {
                try fileManager.removeItem(at: corruptURL)
            }
            try fileManager.moveItem(at: url, to: corruptURL)
        } catch {
            Self.logger.error("\(self.t)Quarantine corrupt keyboard cleaner settings failed: \(error.localizedDescription)")
        }
    }

    private enum Keys {
        static let selectedDurationSeconds = "selectedDurationSeconds"
    }
}