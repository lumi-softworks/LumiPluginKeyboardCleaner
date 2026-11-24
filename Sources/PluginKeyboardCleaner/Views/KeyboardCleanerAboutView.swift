import LumiUI
import SwiftUI

/// 键盘清洁插件关于视图 —— 以产品落地页的形式介绍功能。
struct KeyboardCleanerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            designedForCleaningSection
            howItWorksSection
            exitsSection
            requirementsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "keyboard.badge.ellipsis",
            tagline: L("Wipe the keyboard without typing anything by accident."),
            chips: [
                L("Full-screen overlay"),
                L("Automatic end"),
                L("Emergency exit"),
            ],
            metrics: [
                .init(value: "5", label: L("minute maximum")),
                .init(value: "3", label: L("ways to exit")),
                .init(value: "0", label: L("keystrokes stored")),
            ]
        )
        .landingAppear(delay: 0)
    }

    // MARK: - 功能

    private var designedForCleaningSection: some View {
        LandingSection(
            title: L("Made for cleaning"),
            icon: "sparkles",
            subtitle: L("A short, bounded session instead of a keyboard lock")
        ) {
            LandingFeatureGrid(items: [
                .init(
                    icon: "rectangle.inset.filled",
                    tint: theme.primary,
                    title: L("Full-screen overlay"),
                    description: L("Every display shows a countdown, so there is no doubt whether cleaning mode is on.")
                ),
                .init(
                    icon: "keyboard",
                    tint: theme.warning,
                    title: L("System-wide interception"),
                    description: L("Keystrokes, shortcuts, and media keys are ignored while the session runs.")
                ),
                .init(
                    icon: "timer",
                    tint: theme.info,
                    title: L("Always ends"),
                    description: L("Choose 30 seconds to 5 minutes. The session ends automatically with no indefinite mode.")
                ),
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(
            title: L("How it works"),
            icon: "gearshape.2",
            subtitle: L("A global event tap plus a screen-level overlay")
        ) {
            LandingStepFlow(steps: [
                .init(
                    title: L("Check access"),
                    description: L("The plugin verifies that Lumi is allowed in Accessibility."),
                    icon: "lock.shield"
                ),
                .init(
                    title: L("Show the overlay"),
                    description: L("Every screen is covered before the keyboard is blocked.")
                ),
                .init(
                    title: L("Block the keyboard"),
                    description: L("A head-insert event tap swallows keyboard events and keeps the display awake.")
                ),
                .init(
                    title: L("Clean up"),
                    description: L("The tap is removed and the overlay disappears when the session ends.")
                ),
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 退出方式

    private var exitsSection: some View {
        LandingSection(
            title: L("Three ways out"),
            icon: "escape",
            subtitle: L("You are never locked out, even if the mouse is unavailable")
        ) {
            LandingFeatureGrid(items: [
                .init(
                    icon: "xmark.circle",
                    tint: theme.primary,
                    title: L("End Cleaning button"),
                    description: L("Click the button on any display to stop immediately.")
                ),
                .init(
                    icon: "keyboard",
                    tint: theme.info,
                    title: L("Unlock shortcut"),
                    description: L("Hold ⌃ ⌥ ⇧ + Esc for one second to end the session from the keyboard.")
                ),
                .init(
                    icon: "hourglass",
                    tint: theme.success,
                    title: L("Automatic finish"),
                    description: L("The selected duration always runs out, at most five minutes.")
                ),
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - 要求

    private var requirementsSection: some View {
        LandingSection(title: L("Requirements"), icon: "checkmark.seal") {
            AppCard(style: .subtle, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    requirementRow(L("macOS 14.0 or later"))
                    requirementRow(L("Accessibility permission for Lumi"))
                    requirementRow(L("A keyboard and at least one display"))
                }
            }
        }
        .landingAppear(delay: 0.2)
    }

    private func requirementRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(theme.success)
            Text(verbatim: text)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        KeyboardCleanerText.localized(key)
    }
}

#Preview {
    ScrollView {
        KeyboardCleanerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}