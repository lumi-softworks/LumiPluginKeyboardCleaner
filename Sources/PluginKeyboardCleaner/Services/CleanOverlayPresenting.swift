import Foundation

@MainActor
protocol CleanOverlayPresenting: AnyObject {
    func show(startedAt: Date, duration: TimeInterval, onStop: @escaping @MainActor () -> Void)
    func hide()
}