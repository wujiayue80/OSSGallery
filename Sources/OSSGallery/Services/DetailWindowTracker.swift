import SwiftUI
import AppKit

/// 全局模态与弹窗状态管理器。
///
/// 统一管理详情窗口、控制台设置窗口与随机探索浮层的互斥状态：
/// 1. 严格基于真实 NSWindow 的可见性与系统 willCloseNotification，绝不会发生遮罩残留或窗口幽灵复活；
/// 2. 任何一个弹窗处于打开且可见状态时，主窗口进入锁定状态（.disabled + 暗色毛玻璃遮罩）；
/// 3. 当用户点击主窗口遮罩时，仅当子窗口真实可见时才发声并置顶；若子窗口已关闭，自动秒级清理状态并恢复主窗口；
/// 4. 彻底杜绝循环重开、多开详情页或主窗口卡死问题。
final class ModalWindowManager: ObservableObject {
    static let shared = ModalWindowManager()

    /// 当前激活并可见的模态子窗口（详情窗口或设置窗口）
    private weak var activeModalWindow: NSWindow? = nil
    private var closeObserver: Any? = nil

    @Published private(set) var isModalWindowVisible = false
    @Published var isExploring = false

    /// 主窗口是否应当处于模态锁定状态
    var isAnyModalActive: Bool {
        if isExploring { return true }
        if let win = activeModalWindow {
            if win.isVisible {
                return true
            } else {
                // 自动清理：如果底层窗口已不可见，立即重置状态
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.activeModalWindow === win {
                        self.activeModalWindow = nil
                        self.isModalWindowVisible = false
                    }
                }
                return false
            }
        }
        return false
    }

    private init() {}

    /// 注册一个模态子窗口（由 WindowAccessor 在窗口创建时挂载）
    func registerModalWindow(_ window: NSWindow) {
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
            closeObserver = nil
        }

        self.activeModalWindow = window
        window.level = .floating
        self.isModalWindowVisible = true
        objectWillChange.send()

        // 监听该窗口的真正关闭通知（由 AppKit 底层直接发出，100% 可靠，无生命周期延迟）
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self = self else { return }
            if self.activeModalWindow === window {
                self.activeModalWindow = nil
                self.isModalWindowVisible = false
                self.objectWillChange.send()
            }
        }
    }

    /// 显式注销模态子窗口
    func unregisterModalWindow(_ window: NSWindow) {
        if activeModalWindow === window {
            activeModalWindow = nil
            isModalWindowVisible = false
            objectWillChange.send()
        }
    }

    /// 聚焦激活的子窗口（仅在该窗口实际可见时才聚焦，绝不复活已关闭窗口）
    func bringActiveModalToFront() {
        guard let window = activeModalWindow, window.isVisible else {
            // 如果窗口已经被系统关闭或隐藏，立即恢复主窗口状态，绝不调用 makeKeyAndOrderFront
            activeModalWindow = nil
            isModalWindowVisible = false
            objectWillChange.send()
            return
        }

        NSSound.beep()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 兼容旧接口
    var openCount: Int { isAnyModalActive ? 1 : 0 }
    func opened() {}
    func closed() {}
    func detailOpened() {}
    func detailClosed() {}
    func settingsOpened() {}
    func settingsClosed() {}
}

/// 保持对旧名 DetailWindowTracker 的完全兼容
typealias DetailWindowTracker = ModalWindowManager

/// 在本窗口内按 ESC 时触发回调。
struct EscapeKeyMonitor: NSViewRepresentable {
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onEscape: onEscape) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onEscape = onEscape
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var onEscape: () -> Void
        private weak var window: NSWindow?
        private var monitor: Any?

        init(onEscape: @escaping () -> Void) { self.onEscape = onEscape }

        func attach(to window: NSWindow) {
            self.window = window
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handle(event)
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard event.keyCode == 53 else { return event } // 53 = ESC
            if let first = window?.firstResponder, first is NSTextView {
                return event
            }
            onEscape()
            return nil
        }
    }
}
