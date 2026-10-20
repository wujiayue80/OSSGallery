import SwiftUI
import AppKit

/// 监听 Dock 栏点击事件：当用户关闭主窗口后，再次点击 Dock 图标时重新打开主窗口。
///
/// macOS 的 SwiftUI WindowGroup 在窗口被用户关闭后不会自动重建。
/// 必须通过 NSApplicationDelegate 的 `applicationShouldHandleReopen` 回调，
/// 手动调用 `openWindow(id:)` 或创建新窗口。
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 用户点击 Dock 栏图标时唤出主窗口
        MainWindowHolder.shared.show()
        return true
    }
}

@main
struct OSSGalleryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(id: AppWindowID.main) {
            ContentView()
        }
        // 关键：必须显式给初始尺寸。
        // 不给的话 SwiftUI 会用「内容的理想尺寸」当窗口初始大小，算出来很大，
        // 被屏幕裁成满屏；而满屏窗口四条边全部与屏幕边界重合（上顶菜单栏、下压 Dock、
        // 左右贴屏边），**没有任何一条边可以抓住往里拖**，用户就会觉得"窗口无法缩放"。
        // 该满屏尺寸还会被 macOS 状态恢复记住，每次启动都还原。
        .defaultSize(width: 1200, height: 800)
        .defaultPosition(.center)
        // 允许窗口在内容最小尺寸之上自由缩放（含全屏）。
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About OSS Gallery") {
                    // Custom about action if needed
                }
            }
        }

        // 控制台 / 设置改为独立原生窗口：
        Window(L("控制台", "Console"), id: AppWindowID.settings) {
            SettingsView()
        }
        .defaultSize(width: 640, height: 580)
        .windowResizability(.contentMinSize)

        // 项目详情同样改为独立窗口。
        WindowGroup(L("项目详情", "Project Detail"), id: AppWindowID.detail, for: GitHubRepo.self) { $selected in
            if let repo = selected {
                ProjectDetailWindow(repo: repo)
            } else {
                Text(L("未选择项目", "No project selected"))
                    .frame(minWidth: 480, minHeight: 460)
            }
        }
        .defaultSize(width: 560, height: 680)
        .windowResizability(.contentMinSize)
    }
}
