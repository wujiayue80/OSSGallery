import SwiftUI

/// 列表显示：一行一个项目，信息密度高于网格，适合快速扫读。
struct RepoListView: View {
    let repos: [GitHubRepo]
    let onRepoSelect: (GitHubRepo) -> Void

    @ObservedObject private var favorites = FavoritesStore.shared
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 8) {
                ForEach(repos) { repo in
                    RepoListRow(
                        repo: repo,
                        isFavorite: favorites.contains(repo),
                        onTap: { onRepoSelect(repo) },
                        onToggleFavorite: { favorites.toggle(repo) }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: 1800)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct RepoListRow: View {
    let repo: GitHubRepo
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // 缩略封面（与网格卡片同一套配色）
            ZStack {
                LinearGradient(
                    colors: [repo.coverTint, repo.coverTint.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                AsyncImage(url: URL(string: repo.owner.avatarUrl)) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(repo.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let language = repo.language, !language.isEmpty {
                        Text(language)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                Text("@\(repo.owner.login)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.85))
                    .lineLimit(1)

                Text(repo.description ?? L("暂无项目描述", "No description yet."))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                Label(RepoFormat.count(repo.stargazersCount), systemImage: "star.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.yellow)
                    .fixedSize()

                Label(RepoFormat.count(repo.forksCount), systemImage: "tuningfork")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize()
            }

            HStack(spacing: 6) {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isFavorite ? .yellow : .white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(isFavorite ? L("取消收藏", "Remove from saved") : L("收藏", "Save"))

                if let url = URL(string: repo.htmlUrl) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.cyan.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(L("在 GitHub 打开", "Open on GitHub"))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isHovered ? 0.055 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.cyan.opacity(0.5) : Color.white.opacity(0.08),
                        lineWidth: isHovered ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

/// 按当前显示方式（网格 / 列表）渲染卡片区。
struct RepoCollectionView: View {
    let repos: [GitHubRepo]
    let onRepoSelect: (GitHubRepo) -> Void

    @AppStorage("view_style") private var viewStyle: String = RepoViewStyle.grid.rawValue

    var body: some View {
        if viewStyle == RepoViewStyle.list.rawValue {
            RepoListView(repos: repos, onRepoSelect: onRepoSelect)
        } else {
            ProjectGridView(repos: repos, onRepoSelect: onRepoSelect)
        }
    }
}
