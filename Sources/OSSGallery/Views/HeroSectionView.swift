import SwiftUI

struct HeroSectionView: View {
    let spotlightRepo: GitHubRepo?
    let stats: RepoStats
    var onSpotlightSelect: (GitHubRepo) -> Void
    var onShuffleSpotlight: () -> Void

    @State private var isGlowBreathing = false
    /// 今日精选卡的悬停态（动效方案 B：光晕加强 + 上浮 + 随鼠标轻微 3D 倾斜）
    @State private var spotlightHovered = false
    @State private var spotlightTilt: CGSize = .zero
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    /// Hero 左右内边距。宽 / 窄两态的换算需要用到它。
    /// 宽 / 窄分界 ≈ 左区 ideal 560 + 间距 32 + 精选卡 ideal 440 = 1032pt，
    /// 再减去左右各 24pt 内边距 → 窗口正文宽度约 1080pt 时切换为纵向堆叠。
    private let heroHorizontalPadding: CGFloat = 24

    var body: some View {
        // ViewThatFits 依次尝试：放得下宽版就用宽版，否则退到纵向堆叠。
        // 两侧都用 idealWidth 显式声明理想宽度，避免被 Text 的自然宽度把阈值带偏。
        ViewThatFits(in: .horizontal) {
            wideLayout
            stackedLayout
        }
        .padding(.horizontal, heroHorizontalPadding)
        .padding(.vertical, 32)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottom
            )
        )
    }

    // MARK: - 宽版：左标题区 + 右侧精选卡并排

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 32) {
            titleBlock
                .frame(minWidth: 340, idealWidth: 560, maxWidth: 640, alignment: .leading)

            // 弹性占位：窗口更宽时由它吸收余量，把精选卡推到右边缘。
            Spacer(minLength: 0)

            if let repo = spotlightRepo {
                spotlightCard(for: repo)
                    // 参考图中精选卡约占内容宽 46%、且更方，因此比标题区给得更宽。
                    .frame(minWidth: 340, idealWidth: 440, maxWidth: 520)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 窄版：标题区在上，精选卡在下铺满

    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 24) {
            titleBlock

            if let repo = spotlightRepo {
                spotlightCard(for: repo)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 左侧标题区

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 设置入口统一放在顶栏右上角的齿轮与左栏底部，Hero 里不再重复放一个。
            VStack(alignment: .leading, spacing: 10) {
                // 参考图顶部的那行小号全大写 kicker
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.cyan.opacity(0.8))
                    Text(L("精选开源项目库", "CURATED OPEN SOURCE VAULT"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(1.6)
                }

                Text("OSS Gallery")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(L("精选优质 GitHub 开源项目 · 算法推荐 · 实时探索",
                   "A curated showcase of exceptional GitHub repositories."))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // 统计栏：参考图是「一个圆角容器 + 竖线分隔的三项」。
            // 三项全部由已加载的真实数据算出（原先的 4.3M / 400+ / 32% 是写死的假数据）。
            // 参考图里的"蓝标认证"GitHub 没有对应概念，已替换为「活跃项目占比」。
            HStack(spacing: 0) {
                statCell(
                    icon: "folder.fill",
                    value: "\(stats.count)",
                    title: L("本次加载", "Loaded")
                )

                statDivider

                statCell(
                    icon: "bolt.fill",
                    value: "\(stats.activePercent)%",
                    title: L("活跃项目", "Active")
                )

                statDivider

                statCell(
                    icon: "star.fill",
                    value: stats.maxStars > 0 ? RepoFormat.count(stats.maxStars) : "—",
                    title: L("最高星标", "Top Stars")
                )
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.top, 4)
        }
    }

    private func statCell(icon: String, value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.cyan.opacity(0.8))
                Text(value)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 30)
    }

    // MARK: - 右侧今日精选卡

    private func spotlightCard(for repo: GitHubRepo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.yellow)
                Text(L("今日精选", "TODAY'S PICK"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1.2)

                Spacer()

                // 换一位推荐
                Button(action: onShuffleSpotlight) {
                    Label(L("换一位", "Shuffle"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(L("换一位推荐", "Show another pick"))
            }

            HStack(spacing: 16) {
                // 头像 / Logo
                AsyncImage(url: URL(string: repo.owner.avatarUrl)) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(repo.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(repo.description ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }

            HStack {
                Label("\(repo.stargazersCount / 1000)k " + L("星标", "Stars"), systemImage: "star.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.yellow.opacity(0.9))
                Spacer()
                Button(L("查看", "Explore")) {
                    onSpotlightSelect(repo)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(20)
        // 宽度交给外层 frame 决定：宽版取 320–460，窄版铺满整行。
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    spotlightHovered ? Color.purple.opacity(0.85) : Color.purple.opacity(0.4),
                    lineWidth: spotlightHovered ? 1.5 : 1
                )
        )
        // 悬停动效（方案 B）：光晕加强 + 上浮 2pt + 随鼠标轻微 3D 倾斜，
        // 与网格卡片用的是同一套动效语言。
        .shadow(
            color: .purple.opacity(spotlightHovered ? 0.75 : (isGlowBreathing ? 0.6 : 0.2)),
            radius: spotlightHovered ? 30 : (isGlowBreathing ? 20 : 10)
        )
        .offset(y: spotlightHovered ? -2 : 0)
        .rotation3DEffect(
            .degrees(Double(spotlightTilt.width) * 4),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(Double(-spotlightTilt.height) * 4),
            axis: (x: 1, y: 0, z: 0)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: spotlightHovered)
        .animation(.easeOut(duration: 0.15), value: spotlightTilt)
        .onHover { hovering in
            spotlightHovered = hovering
            if !hovering { spotlightTilt = .zero }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let point):
                // 归一化到 -0.5…0.5，作为倾斜量
                let w = 440.0, h = 200.0
                spotlightTilt = CGSize(
                    width: (point.x / w) - 0.5,
                    height: (point.y / h) - 0.5
                )
            case .ended:
                spotlightTilt = .zero
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isGlowBreathing = true
            }
        }
    }
}
