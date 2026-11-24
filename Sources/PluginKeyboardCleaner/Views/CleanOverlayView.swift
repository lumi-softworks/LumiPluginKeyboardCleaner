import LumiUI
import SwiftUI

/// 清洁模式下覆盖每块屏幕的遮罩。
struct CleanOverlayView: View {
    @LumiTheme private var theme

    let startedAt: Date
    let duration: TimeInterval
    let onStop: @MainActor () -> Void

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var background: some View {
        ZStack {
            Color.black.opacity(0.94)
            RadialGradient(
                colors: [theme.primary.opacity(0.16), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 520
            )
        }
    }

    private var content: some View {
        VStack(spacing: 26) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.white.opacity(0.9))

            VStack(spacing: 8) {
                Text("Keyboard cleaning in progress", tableName: "KeyboardCleaner", bundle: .module)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Keyboard input is temporarily disabled. You can wipe the keyboard safely.", tableName: "KeyboardCleaner", bundle: .module)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            countdownRing

            AppButton(
                KeyboardCleanerText.localized("End Cleaning"),
                systemImage: "xmark.circle.fill",
                style: .primary,
                size: .medium,
                action: onStop
            )
            .accessibilityIdentifier("keyboard-cleaner.overlay.stop")

            HStack(spacing: 6) {
                Image(systemName: "command")
                    .font(.system(size: 10, weight: .semibold))
                Text("Hold ⌃ ⌥ ⇧ + Esc for 1 second to exit immediately", tableName: "KeyboardCleaner", bundle: .module)
                    .font(.system(size: 12))
            }
            .foregroundStyle(.white.opacity(0.46))
        }
        .padding(32)
    }

    private var countdownRing: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let progress = duration > 0 ? min(1, elapsed / duration) : 1
            let remaining = duration - elapsed

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        theme.primary,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(KeyboardCleanerTimeFormatter.countdown(remaining))
                        .font(.system(size: 54, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))

                    Text("Remaining", tableName: "KeyboardCleaner", bundle: .module)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 210, height: 210)
        }
    }
}