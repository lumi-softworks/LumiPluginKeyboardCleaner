import LumiUI
import SwiftUI

// MARK: - Manual View

/// 键盘清洁使用手册 —— 编号章节、编号步骤与线框示意图，克制严谨。
/// 通过 `DocsViewProviding` 的 manual 条目暴露，
/// 在 设置 → 通用 → 说明书 中阅读。
struct KeyboardCleanerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Keyboard Cleaner"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("Keyboard Cleaner blocks all keyboard input for a short, fixed period so you can wipe the keyboard without typing anything by accident. Every display shows a countdown, and the session always ends on its own."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Before You Start"))
            ManualStepList(items: [
                .init(L("Enable Keyboard Cleaner in Plugin Management. The plugin is disabled by default.")),
                .init(L("Open System Settings > Privacy & Security > Accessibility and allow Lumi. Without this permission the keyboard blocker cannot start.")),
                .init(L("Make sure the keyboard you want to clean is connected and working normally.")),
            ])

            ManualSectionHeader(number: 3, title: L("Starting a Session"))
            ManualStepList(items: [
                .init(L("Open the menu-bar popup and choose a duration between 30 seconds and 5 minutes.")),
                .init(L("Click Start Cleaning.")),
                .init(L("A full-screen overlay appears on every display. Keyboard input stops responding from that moment.")),
            ])
            overlayFigure

            ManualSectionHeader(number: 4, title: L("During Cleaning"))
            ManualBulletList(items: [
                .init(L("The mouse keeps working, so you can use the overlay button at any time.")),
                .init(L("All keyboard input is ignored system-wide, including shortcuts, function keys, and media keys.")),
                .init(L("Modifier keys and Caps Lock do not change state while the session is active.")),
                .init(L("The display stays awake for the whole session, so the countdown remains visible.")),
            ])

            ManualSectionHeader(number: 5, title: L("Ending a Session"))
            ManualBulletList(items: [
                .init(L("Click End Cleaning on any display.")),
                .init(L("Or hold Control, Option, Shift, and Esc together for one second. All four keys must be held at the same time.")),
                .init(L("Otherwise the session ends automatically when the selected duration runs out.")),
                .init(L("If Lumi quits or the plugin is disabled, the blocker is released immediately.")),
            ])

            ManualSectionHeader(number: 6, title: L("Settings"))
            ManualBulletList(items: [
                .init(L("Cleaning Duration: choose the default duration used by the next session.")),
                .init(L("Session Safety: read how interception, the overlay, and the emergency exit behave.")),
                .init(L("Permission: check accessibility status and open System Settings.")),
                .init(L("Privacy: confirm what the plugin does and does not observe.")),
            ])

            ManualSectionHeader(number: 7, title: L("Troubleshooting"))
            ManualBulletList(items: [
                .init(L("Start Cleaning does nothing: grant Accessibility permission, then try again. macOS may require restarting Lumi after the permission changes.")),
                .init(L("The unlock shortcut does nothing: the session must be running, and all four keys must be held for a full second.")),
                .init(L("Keyboard still does not respond after a session: quit Lumi. The event tap belongs to the Lumi process and is removed when the process exits.")),
                .init(L("No overlay appears: check that the plugin is enabled and that accessibility permission is granted.")),
            ])

            ManualSectionHeader(number: 8, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Keystrokes are never recorded, logged, or stored. The plugin only checks whether the unlock shortcut is held.")),
                .init(L("There is no unlimited mode. A session lasts at most five minutes.")),
                .init(L("For liquid cleaning, turn off or unplug the keyboard first. This plugin only prevents accidental typing; it does not protect the hardware.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 遮罩布局

    private var overlayFigure: some View {
        ManualFigure(caption: L("Figure 1: Cleaning overlay layout")) {
            VStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.primary)
                    Text(L("Keyboard cleaning in progress"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                }

                ZStack {
                    Circle()
                        .stroke(theme.textTertiary.opacity(0.18), lineWidth: 3)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(theme.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 64, height: 64)
                    Text(verbatim: "0:42")
                        .font(.system(size: 15, weight: .light, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                }

                Text(L("Keyboard input is temporarily disabled. You can wipe the keyboard safely."))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textSecondary)

                Text(L("End Cleaning"))
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.primary.opacity(0.16))
                    )
                    .foregroundStyle(theme.primary)

                Text(L("Hold ⌃ ⌥ ⇧ + Esc for 1 second to exit immediately"))
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        KeyboardCleanerText.localized(key)
    }
}

#if DEBUG
#Preview {
    ScrollView {
        KeyboardCleanerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
#endif