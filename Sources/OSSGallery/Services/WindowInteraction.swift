import SwiftUI

extension View {
    /// 让承载本视图的窗口「可被用户拖边缘缩放」且「可进入全屏」。
    ///
    /// 为什么必须显式声明：
    /// SwiftUI 在使用了 `windowResizability(_:)` 的场景下，会额外用
    /// **「窗口内容的最大尺寸」参与判断该窗口能否全屏**（Apple 文档
    /// `windowFullScreenBehavior(_:)` 明确写了这一点）。一旦判断为「不能全屏」，
    /// 后果有两个：
    ///   1. 左上角绿色交通灯退化为「+」展开样式，而不是双箭头全屏样式；
    ///   2. SwiftUI 会在窗口代理里否决用户的缩放请求 —— 表现就是拖边缘完全没反应。
    ///
    /// 关键陷阱：此时底层 `NSWindow.isResizable`、`styleMask`、`maxSize` 依然报告
    /// 「可缩放」，`collectionBehavior` 也确实是 `.fullScreenPrimary`。也就是说
    /// **只读 AppKit 属性会得出「一切正常」的错误结论**，必须从 SwiftUI 这一层覆盖。
    ///
    /// macOS 15 起提供 `windowResizeBehavior` / `windowFullScreenBehavior` 覆盖该默认判断；
    /// 部署目标仍是 macOS 14，低版本走原行为。
    @ViewBuilder
    func allowWindowResizingAndFullScreen() -> some View {
        if #available(macOS 15.0, *) {
            self
                .windowResizeBehavior(.enabled)
                .windowFullScreenBehavior(.enabled)
        } else {
            self
        }
    }
}
