import SwiftUI
import AppKit

/// 项目详情。原为 `.sheet` 呈现，但 AppKit 的 sheet 本质上是
/// 「附着在父窗口上的模态面板」，**不支持用户拖边缘缩放**，也不带独立窗口的
/// 左上角三个按钮。因此改为独立窗口，由 `WindowGroup(id:for:)` 承载。
struct ProjectDetailWindow: View {
    let repo: GitHubRepo
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var tracker = DetailWindowTracker.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    /// README 提炼出的项目概览。nil 且加载完成时回落到结构化兜底。
    @State private var overview: String?
    @State private var overviewLoading = true
    @State private var overviewFromReadme = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with Cover
            ZStack(alignment: .bottomLeading) {
                if let ogUrl = repo.openGraphImageUrl {
                    AsyncImage(url: ogUrl) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.black
                    }
                    .frame(height: 200)
                    .clipped()
                } else {
                    Color.black.frame(height: 200)
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)

                HStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: repo.owner.avatarUrl)) { img in
                        img.resizable()
                    } placeholder: {
                        Circle().fill(.gray)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .padding(.bottom, -32)
                    .padding(.leading, 24)

                    Spacer()

                    // 卡片右上角关闭按钮
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, -26)
                    .help(L("关闭详情", "Close detail"))
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(repo.fullName)
                        .font(.system(size: 24, weight: .bold))
                        .padding(.top, 40)

                    Text(repo.description ?? L("暂无项目描述", "No description provided."))
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 项目概览：直接回答"这个项目到底是干什么的"。
                // 优先用 README 提炼；提取失败时回落到结构化元数据，保证区块不空白。
                overviewSection

                // 第一行：核心指标
                HStack(spacing: 24) {
                    DetailStatInfo(title: L("星标", "Stars"), value: "\(repo.stargazersCount)", icon: "star.fill", color: .yellow)
                    DetailStatInfo(title: "Forks", value: "\(repo.forksCount)", icon: "tuningfork", color: .gray)
                    DetailStatInfo(title: L("开放 Issue", "Open Issues"), value: "\(repo.openIssuesCount)", icon: "exclamationmark.circle", color: .orange)
                    if let lang = repo.language {
                        DetailStatInfo(title: L("语言", "Language"), value: lang, icon: "curlybraces", color: .cyan)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // 第二行：时间与元信息（卡片上没有、对判断项目有用）
                VStack(alignment: .leading, spacing: 10) {
                    if let created = repo.createdAt {
                        metaRow(icon: "calendar.badge.plus", color: .green,
                                title: L("首次发布", "Created"),
                                value: Self.dateString(created))
                    }
                    if let updated = repo.pushedAt {
                        metaRow(icon: "arrow.triangle.2.circlepath", color: .blue,
                                title: L("最近更新", "Last Push"),
                                value: Self.dateString(updated) + " · \(Self.relativeString(updated))")
                    }
                    if let license = repo.license {
                        metaRow(icon: "doc.text", color: .purple,
                                title: L("许可证", "License"),
                                value: license.spdxId ?? license.name)
                    }
                    metaRow(icon: "internaldrive", color: .gray,
                            title: L("仓库大小", "Size"),
                            value: Self.sizeString(repo.size))
                }

                // Topics 标签
                if !repo.topics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("主题标签", "Topics"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                        FlowLayout(spacing: 8) {
                            ForEach(repo.topics.prefix(10), id: \.self) { topic in
                                Text(topic)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.cyan.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.cyan.opacity(0.25), lineWidth: 1))
                            }
                        }
                    }
                }

                Spacer(minLength: 16)

                HStack {
                    Spacer()

                    // 收藏（纯本地）
                    Button {
                        favorites.toggle(repo)
                    } label: {
                        HStack {
                            Image(systemName: favorites.contains(repo) ? "bookmark.fill" : "bookmark")
                            Text(favorites.contains(repo) ? L("已收藏", "Saved") : L("收藏", "Save"))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(favorites.contains(repo) ? .yellow : .white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // 项目主页（如果有，且与 GitHub 地址不同）
                    if let homepage = repo.homepage,
                       !homepage.isEmpty,
                       let homeUrl = URL(string: homepage) {
                        Button {
                            NSWorkspace.shared.open(homeUrl)
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                Text(L("主页", "Homepage"))
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        if let url = URL(string: repo.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text(L("在 GitHub 打开", "Open in GitHub"))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, 8)

                Text(L("按 ESC 关闭", "Press ESC to close"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        // 只给最小尺寸，不设上限：窗口交给用户自由拉伸。
        .frame(minWidth: 480, minHeight: 460)
        // 显式打开「可缩放 + 可全屏」，否则绿色按钮会显示「+」且拖边缘无效。
        .allowWindowResizingAndFullScreen()
        .preferredColorScheme(.dark)
        .background(WindowAccessor { window in
            WindowConfigurator.apply(to: window)
            ModalWindowManager.shared.registerModalWindow(window)
        })
        // ESC 关闭。这里用局部监听而不是 .keyboardShortcut(.escape)：
        // 后者是全局键等效，会干扰其它窗口。
        .background(EscapeKeyMonitor { dismiss() })
        .onAppear {
            loadOverview()
        }
    }

    // MARK: - 项目概览

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan.opacity(0.85))

                Text(L("项目概览", "Overview"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Spacer(minLength: 0)

                // 如实标注来源：README 摘录 vs 元数据拼合，两者的可信度不同
                Text(overviewLoading
                     ? L("读取中", "loading")
                     : (overviewFromReadme ? L("来自 README", "from README")
                                           : L("来自仓库元数据", "from repo metadata")))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            if overviewLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.5)
                    Text(L("正在读取 README…", "Reading README…"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                Text(overview ?? RepoOverview.fallback(for: repo))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func loadOverview() {
        overviewLoading = true
        Task {
            let text = await RepoOverview.fetch(fullName: repo.fullName)
            overview = text
            overviewFromReadme = (text != nil)
            overviewLoading = false
        }
    }

    private func metaRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
        }
    }

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func relativeString(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        let isZh = ConfigManager.shared.appLanguage.effectiveCode == "zh"
        f.locale = Locale(identifier: isZh ? "zh_CN" : "en_US")
        return f.localizedString(for: date, relativeTo: Date())
    }

    private static func sizeString(_ kb: Int) -> String {
        if kb >= 1024 {
            return String(format: "%.1f MB", Double(kb) / 1024.0)
        }
        return "\(kb) KB"
    }
}

struct DetailStatInfo: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(.gray)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold))
        }
    }
}

/// 简单的流式布局，用于 Topics 标签自动换行。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                maxWidth = max(maxWidth, x)
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        maxWidth = max(maxWidth, x)
        return CGSize(width: min(maxWidth, width), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
