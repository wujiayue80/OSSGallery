import SwiftUI

struct ProjectGridView: View {
    let repos: [GitHubRepo]
    let onRepoSelect: (GitHubRepo) -> Void

    /// 直接观察收藏仓库：任何一处收藏 / 取消收藏都会让整格刷新。
    @ObservedObject private var favorites = FavoritesStore.shared

    // 参考图的卡片约 249pt 宽（内容区 835pt、3 列、列间距 20）。
    // 这里把列宽区间下移，使卡片尺寸接近参考图，宽屏下自然多出一列而不是把卡片拉长。
    let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 20)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(repos) { repo in
                    ProjectCardView(
                        repo: repo,
                        isFavorite: favorites.contains(repo),
                        onTap: { onRepoSelect(repo) },
                        onToggleFavorite: { favorites.toggle(repo) }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: 1800)      // 超宽屏下居中，避免无限拉伸
            .frame(maxWidth: .infinity) // 普通宽度下铺满
        }
    }
}
