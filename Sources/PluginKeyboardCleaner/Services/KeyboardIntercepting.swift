import Foundation

/// 全局键盘拦截器。
///
/// 分两步启动，保证「遮罩先出现、键盘后失效」：`prepare` 只创建事件 tap
/// 并保持关闭，等全屏遮罩显示完成后再 `activate`。任一步失败都返回 false，
/// 由会话管理器完整回滚。
@MainActor
protocol KeyboardIntercepting: AnyObject {
    /// 创建事件 tap（尚未生效）。成功返回 true。
    func prepare(handler: @escaping @Sendable (KeyboardInterceptEvent) -> Void) -> Bool

    /// 把事件 tap 挂到运行循环并启用。成功返回 true。
    func activate() -> Bool

    /// 停用并释放事件 tap；可重复调用。
    func deactivate()
}