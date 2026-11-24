import LumiUI
import SwiftUI

struct KeyboardCleanerSettingsView: View {
    @LumiTheme private var theme

    let configuration: KeyboardCleanerConfiguration
    let manager: KeyboardCleanerManager

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            AppSettingSection(title: KeyboardCleanerText.localized("Cleaning Duration")) {
                VStack(spacing: 0) {
                    ForEach(KeyboardCleanerDuration.allCases) { duration in
                        durationRow(duration)
                        if duration != KeyboardCleanerDuration.allCases.last {
                            Divider().padding(.vertical, 8)
                        }
                    }
                }
            }

            AppSettingSection(title: KeyboardCleanerText.localized("Session Safety")) {
                VStack(spacing: 0) {
                    AppSettingRow(
                        title: KeyboardCleanerText.localized("Automatic End"),
                        description: KeyboardCleanerText.localized("Every session ends by itself after the selected duration. There is no unlimited mode."),
                        icon: "timer"
                    ) { EmptyView() }

                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: KeyboardCleanerText.localized("Global Interception"),
                        description: KeyboardCleanerText.localized("All keyboard input is ignored, including media keys. The mouse keeps working."),
                        icon: "keyboard"
                    ) { EmptyView() }

                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: KeyboardCleanerText.localized("Emergency Exit"),
                        description: KeyboardCleanerText.localized("Hold ⌃ ⌥ ⇧ + Esc for 1 second, or click End Cleaning on the full-screen overlay."),
                        icon: "escape"
                    ) { EmptyView() }
                }
            }

            AppSettingSection(title: KeyboardCleanerText.localized("Permission")) {
                AppSettingRow(
                    title: KeyboardCleanerText.localized("Accessibility Access"),
                    description: manager.hasAccessibilityPermission
                        ? KeyboardCleanerText.localized("Granted. Keyboard input can be blocked.")
                        : KeyboardCleanerText.localized("Required to block keyboard input system-wide."),
                    icon: "lock.shield",
                    titleColor: manager.hasAccessibilityPermission ? nil : theme.warning
                ) {
                    if manager.hasAccessibilityPermission {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.success)
                            .accessibilityLabel(Text("Granted", tableName: "KeyboardCleaner", bundle: .module))
                    } else {
                        AppButton(
                            KeyboardCleanerText.localized("Open System Settings"),
                            systemImage: "gearshape",
                            style: .secondary,
                            size: .small,
                            action: manager.openAccessibilitySettings
                        )
                        .accessibilityIdentifier("\(configuration.accessibilityIdentifierPrefix).permission.open-settings")
                    }
                }
            }

            AppSettingSection(title: KeyboardCleanerText.localized("Privacy")) {
                AppCard(style: .subtle, cornerRadius: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        privacyLine(KeyboardCleanerText.localized("Keystrokes are never recorded, logged, or stored."))
                        privacyLine(KeyboardCleanerText.localized("The plugin only checks whether the unlock shortcut is being held."))
                        privacyLine(KeyboardCleanerText.localized("The blocker is removed the moment a session ends."))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear {
            manager.refreshAccessibilityPermission()
        }
    }

    private func durationRow(_ duration: KeyboardCleanerDuration) -> some View {
        AppSettingRow(
            title: duration.title,
            description: manager.selectedDuration == duration
                ? KeyboardCleanerText.localized("Used for the next cleaning session.")
                : nil,
            icon: "clock",
            action: { manager.selectDuration(duration) }
        ) {
            if manager.selectedDuration == duration {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.primary)
                    .accessibilityLabel(Text("Selected", tableName: "KeyboardCleaner", bundle: .module))
            } else {
                Text("Use", tableName: "KeyboardCleaner", bundle: .module)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("\(configuration.accessibilityIdentifierPrefix).duration.\(duration.rawValue)")
    }

    private func privacyLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 12))
                .foregroundStyle(theme.success)
            Text(verbatim: text)
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    KeyboardCleanerSettingsView(
        configuration: KeyboardCleanerConfiguration(),
        manager: KeyboardCleanerManager()
    )
    .frame(width: 460, height: 640)
}