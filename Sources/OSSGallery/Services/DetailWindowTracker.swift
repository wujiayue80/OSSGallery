import SwiftUI
import AppKit

/// 追踪当前打开的详情窗口数量。
/// 主窗口据此决定是否铺一层"模态遮罩"——详情打开时主窗口点不动，
/// 但仍可切换到其它应用（这正是用户要的"准模态"行为）。
final class DetailWindowTracker: ObservableObject {
    static let shared = DetailWindowTracker()

    @Published private(set) var openCount = 0

    private init() {}

    func opened() { openCount += 1 }
    func closed() { openCount = max(0, openCount - 1) }
}

/// 在本窗口内按 ESC 时触发回调。
///
/// 用局部事件监听而不是 `.keyboardShortcut(.escape)`：
/// 后者是全局键等效，会影响其它窗口；而这里只关心"详情窗口自己的 ESC"。
/// 另外 `firstResponder is NSTextView` 时放行，避免影响文本编辑。
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
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window === window, event.keyCode == 53 else { return event }
            if window.firstResponder is NSTextView { return event }
            onEscape()
            return nil
        }
    }
}
