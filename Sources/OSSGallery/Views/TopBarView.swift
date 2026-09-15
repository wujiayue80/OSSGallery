import SwiftUI
import AppKit

/// 顶栏：应用名（左）＋ 居中搜索框（中）＋ 随机探索与设置（右）。
///
/// 原先这里还有一排「发现 / 关注 / 探索」模式标签，已移除 ——
/// 其中"发现"与"探索"在界面上看不出区别，属于概念重复；
/// 现在这三个入口合并到左侧图标栏（见 `SidebarPane`），顶栏只保留全局动作。
struct TopBarView: View {
    @ObservedObject var config = ConfigManager.shared
    @Binding var searchText: String
    let canExplore: Bool
    var onExplore: () -> Void
    var onOpenSettings: () -> Void

    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            brand
                .frame(maxWidth: .infinity, alignment: .leading)

            searchField
                .frame(minWidth: 180, maxWidth: 380)

            actions
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        // `/` 聚焦搜索框。
        // 刻意不用 .keyboardShortcut("/")：那是**全局键等效**，
        // macOS 会在文本输入之前先做键等效匹配，导致在任何输入框里都打不出 `/`。
        // 改用局部事件监听，并显式放行"正在编辑文本"的情形。
        .background(SlashKeyMonitor { searchFocused = true })
    }

    // MARK: - 左侧：应用名

    private var brand: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.cyan.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
            }
            .frame(width: 24, height: 24)

            Text("OSS Gallery")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
        }
        .fixedSize()
    }

    // MARK: - 中间：搜索框

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            TextField(L("搜索项目、@作者、作者/项目…", "Search repos, @author, author/repo…"),
                      text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .focused($searchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help(L("清空搜索", "Clear search"))
            }

            // `/` 快捷键徽章（参考图样式）
            Text("/")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .help(L("按 / 快速定位搜索框", "Press / to focus search"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(
                searchFocused ? Color.cyan.opacity(0.85) : Color.white.opacity(0.12),
                lineWidth: searchFocused ? 1.5 : 1
            )
        )
        .contentShape(Capsule())
    }

    // MARK: - 右侧：随机探索与设置

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: onExplore) {
                HStack(spacing: 6) {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L("随机探索", "Shuffle"))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundColor(canExplore ? .white : .white.opacity(0.35))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(canExplore ? Color.cyan.opacity(0.16) : Color.white.opacity(0.04))
                )
                .overlay(
                    Capsule().stroke(
                        canExplore ? Color.cyan.opacity(0.45) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(!canExplore)
            .fixedSize()
            .help(canExplore
                  ? L("随机抽一个项目", "Pick a random project")
                  : L("当前没有可抽取的项目", "No projects to pick from yet"))

            Button(action: onOpenSettings) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("控制台 / 设置", "Console / Settings"))
        }
        .fixedSize()
    }
}

/// 局部按键监听：在**本窗口**内按 `/` 时触发回调，把焦点交给搜索框。
///
/// 与 `.keyboardShortcut("/")` 的区别（这是刻意选择）：
/// keyboardShortcut 注册的是全局键等效，macOS 会在文本输入之前先匹配它，
/// 结果是在任何输入框里都打不出 `/`。这里改为监听本窗口的 keyDown：
///   · 只在事件属于本窗口时处理（不影响其它窗口）
///   · 当 firstResponder 是文本编辑器（正在输入）时原样放行
private struct SlashKeyMonitor: NSViewRepresentable {
    let onSlash: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSlash: onSlash) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSlash = onSlash
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var onSlash: () -> Void
        private weak var window: NSWindow?
        private var monitor: Any?

        init(onSlash: @escaping () -> Void) { self.onSlash = onSlash }

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
            // 只处理本窗口的按键
            guard let window, event.window === window else { return event }
            // 必须正好是 "/"（不抢 ⌘/ ⌃/ ⌥ 组合键）
            guard event.charactersIgnoringModifiers == "/",
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
                return event
            }
            // 正在文本框里编辑 → 放行，让 "/" 正常输入
            if window.firstResponder is NSTextView { return event }

            onSlash()
            return nil
        }
    }
}
