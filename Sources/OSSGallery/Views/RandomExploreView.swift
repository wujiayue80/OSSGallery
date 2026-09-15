import SwiftUI
import AppKit

/// 随机探索：全屏遮罩 + 居中资料卡。
///
/// 交互（对应参考图）：
///   · 打开后先"抽奖"——卡片高速轮播，再逐步减速，最后定格
///   · `R` 再抽一次，`ESC` 或点击空白处关闭
/// 抽取算法见 `GalleryViewModel.startExplore()`（本地池加权随机）。
struct RandomExploreView: View {
    let repo: GitHubRepo?
    let isRolling: Bool
    var onReroll: () -> Void
    var onClose: () -> Void

    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            if let repo {
                card(for: repo)
                    .transition(.opacity)
                    // 轮播过程中轻微缩放，制造"正在抽取"的动感
                    .scaleEffect(isRolling ? 0.97 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: isRolling)
            } else {
                Text(L("当前没有可抽取的项目", "Nothing to pick from yet"))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .background(KeyPressMonitor { key in
            switch key {
            case .reroll: onReroll(); return true
            case .close:  onClose();  return true
            }
        })
    }

    // MARK: - 资料卡

    private func card(for repo: GitHubRepo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            cover(for: repo)

            VStack(alignment: .leading, spacing: 12) {
                // 头像压边 + 名字 + 账号
                HStack(alignment: .bottom, spacing: 12) {
                    AsyncImage(url: URL(string: repo.owner.avatarUrl)) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Circle().fill(Color.gray.opacity(0.35))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 3))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(repo.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text("@\(repo.owner.login) · \(RepoFormat.count(repo.stargazersCount)) \(L("星标", "stars"))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.cyan.opacity(0.9))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                // 让头像向上压住封面
                .offset(y: -20)
                .padding(.bottom, -12)

                chips(for: repo)

                Text(repo.description ?? L("暂无项目描述", "No description provided."))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.78))
                    .lineSpacing(3)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isRolling {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.6)
                        Text(L("正在抽取…", "Picking…"))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                } else {
                    HStack(spacing: 10) {
                        Button {
                            if let url = URL(string: repo.htmlUrl) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(L("直达 GitHub 主页", "Open on GitHub"))
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.cyan)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: onReroll) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(L("再抽一次 (R)", "Again (R)"))
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .frame(width: 430)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.cyan.opacity(isRolling ? 0.35 : 0.55), lineWidth: 1)
        )
        .shadow(color: .cyan.opacity(0.28), radius: 34)
        .padding(.bottom, 34)
        .overlay(alignment: .bottom) {
            Text(L("按 ESC 或点击空白处关闭", "Press ESC or click outside to close"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
        }
    }

    private func cover(for repo: GitHubRepo) -> some View {
        ZStack {
            LinearGradient(
                colors: [repo.coverTint, repo.coverTint.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            AsyncImage(url: URL(string: repo.owner.avatarUrl)) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .frame(height: 172)
        .clipped()
        .overlay(alignment: .topTrailing) {
            Text(repo.fullName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(12)
        }
    }

    private func chips(for repo: GitHubRepo) -> some View {
        HStack(spacing: 6) {
            if let language = repo.language, !language.isEmpty {
                chip(language, tint: .cyan)
            }
            ForEach(repo.topics.prefix(3), id: \.self) { topic in
                chip(topic, tint: .white)
            }
        }
        .lineLimit(1)
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(tint.opacity(0.9))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

/// 弹窗内的按键监听：R 再抽、ESC 关闭。
private struct KeyPressMonitor: NSViewRepresentable {
    enum Key { case reroll, close }

    let onKey: (Key) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(onKey: onKey) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKey = onKey
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var onKey: (Key) -> Bool
        private weak var window: NSWindow?
        private var monitor: Any?

        init(onKey: @escaping (Key) -> Bool) { self.onKey = onKey }

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
            guard let window, event.window === window else { return event }
            // 正在文本框里输入 → 放行
            if window.firstResponder is NSTextView { return event }

            let hasCommandModifier = !event.modifierFlags
                .intersection([.command, .control, .option]).isEmpty

            // ESC（keyCode 53）
            if event.keyCode == 53 {
                return onKey(.close) ? nil : event
            }

            guard !hasCommandModifier,
                  event.charactersIgnoringModifiers?.lowercased() == "r" else {
                return event
            }
            return onKey(.reroll) ? nil : event
        }
    }
}
