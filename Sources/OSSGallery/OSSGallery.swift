import SwiftUI

@main
struct OSSGalleryApp: App {
    var body: some Scene {
        WindowGroup {
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
        // 由系统提供左上角「关闭 / 最小化 / 全屏(绿色双箭头)」三个标准按钮，
        // 并支持用户自由拉伸。用 Window 而非 WindowGroup，避免出现"新建窗口"菜单项。
        Window(L("控制台", "Console"), id: AppWindowID.settings) {
            SettingsView()
        }
        .defaultSize(width: 640, height: 580)
        .windowResizability(.contentMinSize)

        // 项目详情同样改为独立窗口。
        // 原本用 .sheet 呈现，但 AppKit 的 sheet 是附着在父窗口上的模态面板，
        // 无论怎么配置都无法被用户拖拽边缘缩放，也没有独立窗口的交通灯按钮。
        // 这里用 for: GitHubRepo.self 把项目数据带进窗口，每个项目一个窗口。
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
