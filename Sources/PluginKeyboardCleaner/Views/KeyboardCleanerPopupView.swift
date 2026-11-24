import LumiUI
import SwiftUI

/// 菜单栏弹窗：选择时长、检查权限、开始清洁。
struct KeyboardCleanerPopupView: View {
    @LumiTheme private var theme

    let configuration: KeyboardCleanerConfiguration
    let manager: KeyboardCleanerManager

    @State private var startError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            permissionWarning
            durationSection
            Divider()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            startSection
            errorMessage
            footerNote
        }
        .padding(.bottom, 10)
        .background(background)
        .clipped()
        .onAppear {
            manager.refreshAccessibilityPermission()
            startError = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 11))
                .foregroundColor(theme.primary)

            Text("Keyboard Cleaner", tableName: "KeyboardCleaner", bundle: .module)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Permission

    @ViewBuilder
    private var permissionWarning: some View {
        if !manager.hasAccessibilityPermission {
            AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.warning)
                        Text("Accessibility access required", tableName: "KeyboardCleaner", bundle: .module)
                            .font(.system(size: 10, weight: .semibold))
                    }

                    Text("Allow Lumi in System Settings > Privacy & Security > Accessibility to block keyboard input while cleaning.", tableName: "KeyboardCleaner", bundle: .module)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    AppButton(
                        KeyboardCleanerText.localized("Open System Settings"),
                        systemImage: "gearshape",
                        style: .secondary,
                        size: .small,
                        action: manager.openAccessibilitySettings
                    )
                    .accessibilityIdentifier("\(configuration.accessibilityIdentifierPrefix).permission.open-settings")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Duration", tableName: "KeyboardCleaner", bundle: .module)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)

            HStack(spacing: 4) {
                ForEach(KeyboardCleanerDuration.allCases) { duration in
                    let isSelected = manager.selectedDuration == duration
                    AppButton(
                        duration.shortTitle,
                        style: isSelected ? .primary : .secondary,
                        size: .small,
                        action: { manager.selectDuration(duration) }
                    )
                    .accessibilityLabel(Text(verbatim: duration.title))
                    .accessibilityIdentifier(
                        "\(configuration.accessibilityIdentifierPrefix).duration.\(duration.rawValue)"
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
        }
    }

    // MARK: - Start

    private var startSection: some View {
        VStack(spacing: 6) {
            AppButton(
                manager.isCleaning
                    ? KeyboardCleanerText.localized("Cleaning in Progress")
                    : KeyboardCleanerText.localized("Start Cleaning"),
                systemImage: manager.isCleaning ? "checkmark.shield.fill" : "sparkles",
                style: .primary,
                size: .medium,
                fillsWidth: true,
                action: startCleaning
            )
            .disabled(manager.isCleaning)
            .accessibilityIdentifier("\(configuration.accessibilityIdentifierPrefix).start")
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let startError {
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.error)
                Text(verbatim: startError)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("Keyboard input is ignored system-wide during cleaning. Hold ⌃ ⌥ ⇧ + Esc for 1 second to exit at any time.", tableName: "KeyboardCleaner", bundle: .module)
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.top, 8)
    }

    // MARK: - Actions

    private func startCleaning() {
        startError = nil
        guard let failure = manager.startCleaning() else { return }

        switch failure {
        case .permissionRequired:
            // 权限横幅会在 refresh 之后出现，这里不重复提示。
            break
        case .interceptorUnavailable:
            startError = KeyboardCleanerText.localized(
                "The keyboard blocker could not start. Check that Lumi is allowed in System Settings > Privacy & Security > Accessibility, then try again."
            )
        case .alreadyCleaning, .invalidDuration:
            break
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.primary.opacity(0.06),
                    theme.info.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 72))
                    .foregroundColor(theme.primary.opacity(0.04))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 96, y: 54)

                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundColor(theme.info.opacity(0.03))
                    .rotationEffect(.degrees(14))
                    .offset(x: -108, y: 64)
            }
        }
    }
}

#Preview("Keyboard Cleaner Popup") {
    KeyboardCleanerPopupView(
        configuration: KeyboardCleanerConfiguration(),
        manager: KeyboardCleanerManager()
    )
    .frame(width: 300)
}