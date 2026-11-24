import AppKit
import SwiftUI

/// 在所有屏幕上铺一层置顶遮罩，提示清洁状态并承载倒计时与「结束清洁」按钮。
///
/// 面板使用 `.screenSaver` 层级，覆盖菜单栏与全屏应用；`nonactivatingPanel`
/// 保证点击按钮不会切换前台应用。键盘此时本来就被屏蔽，面板不抢夺焦点
/// 也不会影响鼠标操作。
@MainActor
final class CleanOverlayController: CleanOverlayPresenting {
    private var panels: [NSPanel] = []
    private var screenObserver: ScreenChangeObserver?
    private var startedAt = Date()
    private var duration: TimeInterval = 0
    private var onStop: (@MainActor () -> Void)?

    func show(startedAt: Date, duration: TimeInterval, onStop: @escaping @MainActor () -> Void) {
        hide()

        self.startedAt = startedAt
        self.duration = duration
        self.onStop = onStop
        self.screenObserver = ScreenChangeObserver { [weak self] in
            self?.rebuildPanels()
        }
        rebuildPanels()
    }

    func hide() {
        screenObserver = nil
        closePanels()
        onStop = nil
    }

    private func rebuildPanels() {
        guard let onStop else { return }
        closePanels()

        for screen in NSScreen.screens {
            let panel = makePanel(for: screen, onStop: onStop)
            panels.append(panel)
            panel.orderFrontRegardless()
        }
    }

    private func closePanels() {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
    }

    private func makePanel(for screen: NSScreen, onStop: @escaping @MainActor () -> Void) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(
            rootView: CleanOverlayView(
                startedAt: startedAt,
                duration: duration,
                onStop: onStop
            )
        )
        panel.setFrame(screen.frame, display: true)
        return panel
    }
}

/// 屏幕参数变化时重建面板：插拔显示器或改分辨率后遮罩需要重新铺满。
@MainActor
private final class ScreenChangeObserver: NSObject {
    private let onChange: @MainActor () -> Void

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersDidChange() {
        onChange()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}