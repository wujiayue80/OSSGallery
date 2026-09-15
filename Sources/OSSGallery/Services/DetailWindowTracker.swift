import SwiftUI
import AppKit

/// 全局模态与弹窗状态管理器。
///
/// 统一管理详情窗口、控制台设置窗口与随机探索浮层的互斥状态：
/// 1. 任何一个弹窗处于打开状态时，主窗口进入锁定状态（.disabled + 暗色毛玻璃遮罩）；
/// 2. 主窗口拦截所有点击，点击时调用系统提示音并将当前激活的弹窗置顶获得焦点；
/// 3. 禁止重复弹出第二个详情窗口或跨窗口乱点。
final class ModalWindowManager: ObservableObject {
    static let shared = ModalWindowManager()

    @Published private(set) var detailCount = 0
    @Published private(set) var isSettingsOpen = false
    @Published var isExploring = false

    var isAnyModalActive: Bool {
        detailCount > 0 || isSettingsOpen || isExploring
    }

    private init() {}

    // MARK: - 详情窗口追踪
    func detailOpened() {
        detailCount += 1
    }

    func detailClosed() {
        detailCount = max(0, detailCount - 1)
    }

    // MARK: - 设置窗口追踪
    func settingsOpened() {
        isSettingsOpen = true
    }

    func settingsClosed() {
        isSettingsOpen = false
    }

    // MARK: - 聚焦激活的子窗口
    func bringActiveModalToFront() {
        NSSound.beep()

        // 寻找打开的详情窗口或控制台窗口并激活置顶
        for window in NSApp.windows {
            let title = window.title
            if title.contains("详情") || title.contains("Detail") ||
               title.contains("控制台") || title.contains("Console") ||
               window.identifier?.rawValue.contains("detail") == true ||
               window.identifier?.rawValue.contains("settings") == true {
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
    }
}

/// 保持对旧名 DetailWindowTracker 的完全兼容
typealias DetailWindowTracker = ModalWindowManager

extension ModalWindowManager {
    var openCount: Int { detailCount }
    func opened() { detailOpened() }
    func closed() { detailClosed() }
}

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
