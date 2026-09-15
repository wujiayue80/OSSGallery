import SwiftUI

struct ProjectCardView: View {
    let repo: GitHubRepo
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovered = false
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    /// 封面尺寸参考图：封面高 : 卡片宽 ≈ 1 : 2.4。
    /// 用固定比例而不是固定高度，避免列宽变化时封面「时胖时瘦」。
    private let coverAspect: CGFloat = 2.4

    var body: some View {
        // 收藏按钮不能嵌在卡片这个 Button 的 label 里（嵌套 Button 不会响应），
        // 因此放到外层 ZStack 叠在封面上方。
        ZStack(alignment: .topLeading) {
            Button(action: onTap) {
                cardBody
            }
            .buttonStyle(.plain)

            favoriteButton
                .padding(10)
        }
        .shadow(color: isHovered ? Color.cyan.opacity(0.7) : Color.black.opacity(0.4), radius: isHovered ? 25 : 8, y: isHovered ? 0 : 4)
        .scaleEffect(isHovered ? 1.06 : 1.0)
        .rotation3DEffect(
            .degrees(isHovered ? 3 : 0),
            axis: (x: -1, y: 0, z: 0)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverTile

            // 信息层（参考图为 3 层：标题 / 两行描述 / 底行指标）
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // 作者 / 发布者账号
                    Text("@\(repo.owner.login)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cyan.opacity(0.85))
                        .lineLimit(1)
                }

                Text(repo.description ?? L("暂无项目描述", "No description yet."))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 32, alignment: .topLeading)

                // 底行：星标 · Fork · 打开 GitHub
                HStack(spacing: 12) {
                    Label(RepoFormat.count(repo.stargazersCount), systemImage: "star.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.yellow)

                    Label(RepoFormat.count(repo.forksCount), systemImage: "tuningfork")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .padding(.top, 2)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color(nsColor: .windowBackgroundColor).opacity(0.7), Color.black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isHovered ? Color.cyan : (isFavorite ? Color.yellow.opacity(0.45) : Color.white.opacity(0.12)),
                    lineWidth: isHovered ? 2.5 : 1
                )
        )
    }

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isFavorite ? .yellow : .white.opacity(0.85))
                .frame(width: 26, height: 26)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help(isFavorite ? L("取消收藏", "Remove from saved") : L("收藏", "Save"))
    }

    // MARK: - 封面：纯色磁贴 + 居中 Logo
    //
    // 参考图的做法。相比直接用 GitHub 的 OpenGraph 自动图（白底黑字、配色不可控），
    // 自绘底色可以从根本上避免"白底刺眼"，且每张卡颜色稳定、有辨识度。
    // Logo 复用 owner 头像 URL —— 卡片上原本就有一处同 URL 请求，命中缓存，几乎不增开销。

    private var coverTile: some View {
        ZStack {
            LinearGradient(
                colors: [repo.coverTint, repo.coverTint.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            AsyncImage(url: URL(string: repo.owner.avatarUrl)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .empty:
                    ProgressView().scaleEffect(0.6)
                case .failure:
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .aspectRatio(coverAspect, contentMode: .fill)
        .clipped()
        .overlay(alignment: .topTrailing) {
            if let lang = repo.language, !lang.isEmpty {
                Text(lang)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    .foregroundColor(.white)
                    .padding(10)
            }
        }
    }
}
