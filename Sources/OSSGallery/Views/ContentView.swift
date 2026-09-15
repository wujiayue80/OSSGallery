import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = GalleryViewModel()
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var detailTracker = DetailWindowTracker.shared
    @Environment(\.openWindow) private var openWindow
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    // 设置是独立窗口，没有 sheet 的 onDismiss 回调，改为监听这两项自动重新取数。
    @AppStorage("per_page") private var perPage: Int = 30
    @AppStorage("sort_option") private var sortOptionRaw: String = RepoSortOption.recommended.rawValue
    /// 收藏页的本地排序：按收藏时间 / 按星标
    @AppStorage("saved_sort") private var savedSort: String = "time"

    /// 随机探索浮层是否可见
    @State private var exploring = false

    /// 关注页为空时建议关注的作者（真实账号，点开可看其项目或去关注）
    private let suggestedAuthors = [
        "torvalds", "sindresorhus", "antfu", "yyx990803",
        "karpathy", "ggerganov", "hwchase17", "tj"
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarView(
                    pane: viewModel.pane,
                    savedCount: favorites.repos.count,
                    onSelect: { viewModel.setPane($0) },
                    onOpenSettings: openSettings
                )

                VStack(spacing: 0) {
                    TopBarView(
                        searchText: $viewModel.searchText,
                        canExplore: !viewModel.explorePool.isEmpty,
                        onExplore: startExploring,
                        onOpenSettings: openSettings
                    )

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)

                    contentArea
                }
            }

            // 准模态遮罩：详情窗口打开时盖住主窗口并吞掉点击。
            // 要点——**只拦本应用的窗口**，切到别的软件不受影响，
            // 这正是"弹出后只能操作它，除非关闭"要的效果。
            if detailTracker.openCount > 0 && !exploring {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { /* 只吞掉点击，不关闭 */ }
            }

            // 随机探索：全屏浮层，盖在所有内容之上
            if exploring {
                RandomExploreView(
                    repo: viewModel.exploreRepo,
                    isRolling: viewModel.isExploring,
                    onReroll: { viewModel.startExplore() },
                    onClose: stopExploring
                )
            }
        }
        .background(WindowAccessor { window in
            WindowConfigurator.apply(to: window)
        })
        .preferredColorScheme(.dark)
        // 窗口尺寸由「内容尺寸」驱动（场景用了 windowResizability(.contentMinSize)）：
        //   min    → 能被缩到多小（左侧有 78pt 图标栏，因此下限比纯内容更宽）
        //   ideal  → 启动时的初始大小（实测 .defaultSize 在此组合下不生效，用 ideal 才可靠）
        //   max    → 不设上限，允许自由拉伸到全屏
        .frame(minWidth: 860, idealWidth: 1280, maxWidth: .infinity,
               minHeight: 560, idealHeight: 820, maxHeight: .infinity)
        // 显式打开「可缩放 + 可全屏」，覆盖 SwiftUI 对窗口交互能力的默认判断。
        .allowWindowResizingAndFullScreen()
        .animation(.easeOut(duration: 0.15), value: detailTracker.openCount)
        .onChange(of: perPage) { viewModel.reload() }
        .onChange(of: sortOptionRaw) { viewModel.reload() }
        .onChange(of: viewModel.searchText) { viewModel.searchTextChanged() }
    }

    // MARK: - 主内容区

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.pane {
        case .discover:
            VStack(spacing: 0) {
                HeroSectionView(
                    spotlightRepo: viewModel.spotlightRepo,
                    stats: viewModel.stats,
                    onSpotlightSelect: openDetail,
                    onShuffleSpotlight: { viewModel.shuffleSpotlight() }
                )
                FilterBarView(
                    selectedCategory: viewModel.selectedCategory,
                    onSelect: { viewModel.selectCategory($0) },
                    onOpenSettings: openSettings
                )
                listArea
            }

        case .following:
            VStack(spacing: 0) {
                FollowingHeaderView(
                    authors: viewModel.followingAuthors,
                    selectedAuthor: viewModel.authorFilter,
                    repoCount: viewModel.repos.count,
                    onSelectAuthor: { viewModel.setAuthorFilter($0) }
                )
                if let hint = viewModel.statusHint {
                    hintRow(hint)
                }
                if viewModel.followingAuthors.isEmpty && viewModel.authorFilter == nil {
                    followingEmptyState
                } else if viewModel.isLoading {
                    Spacer()
                    ProgressView().scaleEffect(1.5)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    errorState(error)
                } else {
                    listArea
                }
            }

        case .saved:
            VStack(spacing: 0) {
                SavedHeaderView(
                    count: favorites.repos.count,
                    languageCounts: savedLanguageCounts,
                    sortBy: $savedSort,
                    onClear: { favorites.removeAll() }
                )
                if favorites.repos.isEmpty {
                    emptySavedState
                } else {
                    RepoCollectionView(repos: savedReposSorted, onRepoSelect: openDetail)
                }
            }
        }
    }

    private func hintRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.cyan.opacity(0.8))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(L("加载项目出错", "Error Loading Projects"))
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if viewModel.pane == .following {
                Button(L("打开控制台填入 Token", "Open the console to add a token")) {
                    openSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var listArea: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Spacer()
        } else if let error = viewModel.errorMessage {
            errorState(error)
        } else if viewModel.repos.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 34))
                    .foregroundColor(.white.opacity(0.35))
                Text(L("没有找到项目", "No projects found"))
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        } else {
            RepoCollectionView(repos: viewModel.repos, onRepoSelect: openDetail)
        }
    }

    // MARK: - 关注页空状态

    private var followingEmptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))

            Text(L("你还没有关注任何作者", "You follow nobody yet"))
                .font(.headline)
                .foregroundColor(.white.opacity(0.75))

            Text(L("去 GitHub 关注几位作者后，这里会列出他们全部的开源项目。\n也可以直接点下面的作者，先看看他们有什么。",
                   "Follow some accounts on GitHub and their projects will show up here.\nOr click an account below to browse their work right now."))
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text(L("可以从这些作者开始", "Suggested accounts"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                FlowLayout(spacing: 8) {
                    ForEach(suggestedAuthors, id: \.self) { login in
                        suggestedAuthorChip(login)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func suggestedAuthorChip(_ login: String) -> some View {
        HStack(spacing: 6) {
            Button {
                viewModel.setAuthorFilter(login)
            } label: {
                HStack(spacing: 6) {
                    AsyncImage(url: URL(string: "https://github.com/\(login).png?size=64")) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Circle().fill(Color.white.opacity(0.12))
                        }
                    }
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())

                    Text(login)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help(L("查看 @\(login) 的项目", "Browse @\(login)'s projects"))

            Button {
                if let url = URL(string: "https://github.com/\(login)") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.cyan.opacity(0.9))
            }
            .buttonStyle(.plain)
            .help(L("在 GitHub 打开主页去关注", "Open on GitHub to follow"))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        .fixedSize()
    }

    private var emptySavedState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            Text(L("还没有收藏", "Nothing saved yet"))
                .font(.headline)
                .foregroundColor(.white.opacity(0.75))
            Text(L("在发现页把鼠标移到卡片左上角的书签图标上即可收藏。",
                   "Hover a card in Discover and click the bookmark icon to save it."))
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 收藏页的本地排序与语言分布

    private var savedReposSorted: [GitHubRepo] {
        savedSort == "stars"
            ? favorites.repos.sorted { $0.stargazersCount > $1.stargazersCount }
            : favorites.repos   // entries 本身按收藏时间倒序
    }

    private var savedLanguageCounts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for repo in favorites.repos {
            guard let language = repo.language, !language.isEmpty else { continue }
            counts[language, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (name: $0.key, count: $0.value) }
    }

    // MARK: - 随机探索

    private func startExploring() {
        exploring = true
        viewModel.startExplore()
    }

    private func stopExploring() {
        exploring = false
        viewModel.stopExplore()
    }

    // MARK: - 窗口

    private func openSettings() {
        openWindow(id: AppWindowID.settings)
    }

    /// 详情是独立窗口，用 value 把项目数据带过去。
    private func openDetail(_ repo: GitHubRepo) {
        openWindow(id: AppWindowID.detail, value: repo)
    }
}
