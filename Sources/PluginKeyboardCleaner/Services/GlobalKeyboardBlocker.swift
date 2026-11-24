import AppKit
import CoreGraphics
import Foundation

/// 基于 CGEventTap 的全局键盘拦截器。
///
/// - 事件 tap 挂在主运行循环的 `.commonModes` 上：回调与 AppKit/SwiftUI
///   在同一线程执行，避免跨线程访问视图与状态；回调只做匹配与吞键，
///   开销极小，不会阻塞主线程。
/// - 吞掉所有键盘事件（含修饰键与系统功能键），鼠标事件不受影响，
///   用户仍可点击遮罩上的「结束清洁」。
/// - 系统因超时或用户输入停用 tap 时自动重新启用；若重新启用持续失败，
///   遮罩与定时器仍然把会话带回 idle，不会把键盘永久卡死。
@MainActor
final class GlobalKeyboardBlocker: KeyboardIntercepting {
    /// 媒体键等系统定义事件。新版 CoreGraphics SDK 已不再导出该枚举成员，
    /// 改用 AppKit 的同名事件类型取原始值。
    private static let systemDefinedEventTypeRawValue =
        UInt32(NSEvent.EventType.systemDefined.rawValue)

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: (@Sendable (KeyboardInterceptEvent) -> Void)?
    private var isActive = false

    func prepare(handler: @escaping @Sendable (KeyboardInterceptEvent) -> Void) -> Bool {
        deactivate()

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << Self.systemDefinedEventTypeRawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardCleanerEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        // 先保持关闭，等遮罩显示完成后再由 activate() 打开。
        CGEvent.tapEnable(tap: tap, enable: false)
        eventTap = tap
        runLoopSource = source
        self.handler = handler
        return true
    }

    func activate() -> Bool {
        guard let tap = eventTap, let source = runLoopSource, !isActive else {
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isActive = true
        return true
    }

    func deactivate() {
        isActive = false
        handler = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// 由 C 回调驱动。调用方保证回调运行在主运行循环（主线程）上。
    /// 返回 true 表示事件已被吞掉，调用方应返回 nil 阻止其继续分发。
    fileprivate func shouldSwallow(
        type: CGEventType,
        keyCode: UInt16,
        modifiers: KeyboardModifiers
    ) -> Bool {
        if type.rawValue == Self.systemDefinedEventTypeRawValue {
            return true
        }

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return false

        case .keyDown:
            deliver(kind: .keyDown, keyCode: keyCode, modifiers: modifiers)
            return true

        case .keyUp:
            deliver(kind: .keyUp, keyCode: keyCode, modifiers: modifiers)
            return true

        case .flagsChanged:
            deliver(kind: .flagsChanged, keyCode: keyCode, modifiers: modifiers)
            return true

        default:
            return false
        }
    }

    private func deliver(
        kind: KeyboardInterceptEvent.Kind,
        keyCode: UInt16,
        modifiers: KeyboardModifiers
    ) {
        guard let handler else { return }
        handler(KeyboardInterceptEvent(kind: kind, keyCode: keyCode, modifiers: modifiers))
    }
}

/// 事件 tap 的 C 回调。
///
/// 事件源只添加到 `CFRunLoopGetMain()`，因此这里必定位于主线程；
/// `MainActor.assumeIsolated` 把这一事实告知编译器，避免为每次按键
/// 走一次异步派发。
private func keyboardCleanerEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let blocker = Unmanaged<GlobalKeyboardBlocker>.fromOpaque(refcon).takeUnretainedValue()

    // 只把 Sendable 的字段带进主线程闭包；CGEvent 留在回调线程读取。
    let rawKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let keyCode = UInt16(clamping: rawKeyCode)
    let modifiers = KeyboardModifiers(cgFlags: event.flags)

    let shouldSwallow = MainActor.assumeIsolated {
        blocker.shouldSwallow(type: type, keyCode: keyCode, modifiers: modifiers)
    }
    return shouldSwallow ? nil : Unmanaged.passUnretained(event)
}

extension KeyboardModifiers {
    init(cgFlags: CGEventFlags) {
        var value: UInt = 0
        if cgFlags.contains(.maskControl) { value |= Self.control.rawValue }
        if cgFlags.contains(.maskAlternate) { value |= Self.option.rawValue }
        if cgFlags.contains(.maskShift) { value |= Self.shift.rawValue }
        if cgFlags.contains(.maskCommand) { value |= Self.command.rawValue }
        self.init(rawValue: value)
    }
}