import SwiftUI
import AppKit

/// 应用内独立窗口的标识。集中在此处，避免同一窗口 id 散落多处。
enum AppWindowID {
    static let settings = "ossgallery.settings"
    static let detail = "ossgallery.detail"
}

/// 在 SwiftUI 中拿到底层 NSWindow，用于窗口级配置。
struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum WindowConfigurator {
    /// 统一窗口外观与行为。三个窗口（主窗口 / 控制台 / 详情）都走这里。
    static func apply(to window: NSWindow) {
        window.appearance = NSAppearance(named: .darkAqua)

        // SwiftUI 在 macOS 上创建的窗口，collectionBehavior 默认带 `.fullScreenNone`（实测）。
        // 只 `insert(.fullScreenPrimary)` 不够 —— 两条标记互相矛盾，AppKit 以
        // `.fullScreenNone` 为准，绿色按钮会退化成「+」缩放样式，
        // 长按也不会出现「移动与调整大小 / 填充与排列 / 全屏幕」菜单。
        // 必须先 `remove(.fullScreenNone)` 再插入 `.fullScreenPrimary`。
        window.collectionBehavior.remove(.fullScreenNone)
        window.collectionBehavior.insert(.fullScreenPrimary)

        // 边缘缩放能力的兜底：SwiftUI 默认已带上 `.resizable`，这里只确保不会被漏掉。
        if !window.styleMask.contains(.resizable) {
            window.styleMask.insert(.resizable)
        }

        window.standardWindowButton(.zoomButton)?.isEnabled = true

        // 关键：显式声明为「常规前台应用」，并激活窗口。
        //
        // 本工程是 SPM 的 executable target，从 Xcode / 终端运行的是**裸二进制**（没有 .app 包）。
        // 实测：裸进程启动后 `NSApp.isActive == false` 且窗口 `isKeyWindow == false`，
        // 此时表现是——鼠标点击控件有反应（能弹出申请页、输入框能出现聚焦描边），
        // 但**键盘输入进不去**、**下拉菜单弹不开**、**窗口边缘不显示缩放光标**
        // （光标形状只反映最上层窗口，而最上层并不是本应用）。
        // 实测对照：把同一二进制装进带 Info.plist 的 .app 包用 `open` 启动，焦点与键盘输入全部正常。
        // `setActivationPolicy(.regular)` 让裸进程也能成为常规前台应用，从而拿到激活与键盘焦点。
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
