import Foundation
import SwiftUI

/// Hero 统计栏要显示的三项。全部由**已加载的真实数据**算出，
/// 不再使用写死的数字（原先的 "4.3M / 400+ / 32%" 是假数据）。
struct RepoStats {
    var count: Int = 0
    /// 近 90 天有推送（pushed_at）的项目占比 —— 衡量"这批项目还有没有人在维护"。
    var activePercent: Int = 0
    var maxStars: Int = 0
}

@MainActor
class GalleryViewModel: ObservableObject {
    // 列表
    @Published var repos: [GitHubRepo] = []
    @Published var spotlightRepo: GitHubRepo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategory: SearchCategory?
    @Published private(set) var stats = RepoStats()

    // 导航（左栏同时决定数据来源）
    @Published var pane: SidebarPane = .discover
    @Published var searchText: String = ""
    @Published var statusHint: String?

    // 随机探索
    @Published private(set) var exploreRepo: GitHubRepo?
    @Published private(set) var isExploring = false

    // 关注页
    /// 已关注的作者登录名（用于头像横条）
    @Published private(set) var followingAuthors: [String] = []
    /// 点头像后只看某一位作者；nil = 看全部关注作者
    @Published var authorFilter: String?

    private let config = ConfigManager.shared
    private let favorites = FavoritesStore.shared
    private var searchTask: Task<Void, Never>?
    private var exploreTask: Task<Void, Never>?

    /// 本轮已抽中次数，用于加权随机（抽过的降低权重，避免反复抽到同一批头部项目）。
    private var drawCounts: [Int: Int] = [:]

    /// 关注流最多纳入多少位作者。
    ///
    /// 与旧实现的区别：现在改成**逐作者调 `/users/{login}/repos`**，
    /// 因此不再受 Search 接口 1000 条上限的约束，能真正列出作者的全部（最近更新的 100 个）项目。
    /// 代价是 N 位作者 = N 次请求，所以这里限流到 30 位并分批并发（见 `fetchReposOfAuthors`）。
    private let followingAuthorLimit = 30

    init() {
        if let first = config.categories.first {
            self.selectedCategory = first
        }
        reload()
    }

    // MARK: - 导航

    func setPane(_ newPane: SidebarPane) {
        guard pane != newPane else { return }
        pane = newPane
        // 切到收藏时清掉搜索词，否则会带着上一次的搜索状态去看本地数据
        if newPane == .saved { searchText = "" }
        reload()
    }

    func selectCategory(_ category: SearchCategory) {
        selectedCategory = category
        reload()
    }

    /// 关注页：点头像只看某位作者（传 nil 看全部）。
    func setAuthorFilter(_ login: String?) {
        guard authorFilter != login else { return }
        authorFilter = login
        reload()
    }

    /// 搜索框输入变化：防抖 400ms 后再请求，避免每敲一个字打一次接口。
    func searchTextChanged() {
        if !searchText.isEmpty, pane == .saved {
            pane = .discover
        }
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.reload()
        }
    }

    // MARK: - 取数

    func reload() {
        Task { await performReload() }
    }

    private func performReload() async {
        guard pane.needsNetwork else {
            // 收藏页是纯本地数据，不请求网络
            stats = computeStats(favorites.repos)
            return
        }

        isLoading = true
        errorMessage = nil
        statusHint = nil

        do {
            let fetched = try await fetchForCurrentPane()
            let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            // 只有用户显式选择「综合推荐」时才做客户端混排。
            // 其余选项一律"选什么就按什么排" —— 否则界面上的排序选择器就说了不算，
            // 用户会看到"选了最多星标，48 万排在 39 万后面"这种自相矛盾的结果。
            if config.sortOption.isClientRanked && !isSearching {
                repos = Self.ranked(fetched)
            } else {
                repos = fetched
            }
            stats = computeStats(repos)
            spotlightRepo = Self.dailyPick(from: fetched)
        } catch {
            repos = []
            spotlightRepo = nil
            stats = RepoStats()
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchForCurrentPane() async throws -> [GitHubRepo] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 搜索优先：只要有搜索词就走搜索，不区分当前在哪个入口
        if !trimmed.isEmpty {
            return try await GitHubAPI.shared.fetchRepos(
                query: Self.githubQuery(from: trimmed),
                sort: config.sortOption,
                order: config.sortOrder,
                perPage: config.perPage
            )
        }

        switch pane {
        case .discover:
            // 分类规则支持 `|` 并集，由 GitHubAPI 并发请求后合并去重
            let category = selectedCategory ?? config.categories.first
            return try await GitHubAPI.shared.fetchRepos(
                subQueries: category?.subQueries ?? ["stars:>3000"],
                sort: config.sortOption,
                order: config.sortOrder,
                perPage: config.perPage
            )

        case .following:
            guard !config.apiKey.isEmpty else { throw GitHubAPIError.missingToken }

            // 选中某位作者：只拉他一个人，快很多。
            // 放在前面是为了——即使自己还没关注任何人，也能浏览"推荐作者"的项目。
            if let author = authorFilter {
                let own = try await GitHubAPI.shared.fetchUserRepos(login: author)
                statusHint = L("@\(author) 的公开项目，共 \(own.count) 个。",
                               "Public projects by @\(author) — \(own.count) total.")
                return Self.sorted(own, by: config.sortOption)
            }

            // 只在还没拿到作者列表时请求一次，避免每次切排序都重新拉
            if followingAuthors.isEmpty {
                followingAuthors = try await GitHubAPI.shared.fetchFollowingLogins()
            }
            guard !followingAuthors.isEmpty else {
                statusHint = L("你在 GitHub 上还没有关注任何作者。先去 GitHub 关注几个人，这里就会有内容。",
                               "You don't follow anyone on GitHub yet — follow some accounts first.")
                return []
            }

            // 全部关注作者：逐作者并发拉取后合并去重
            //（旧实现用一次 `user:a user:b …` 搜索，受 1000 条上限，列不全）
            let capped = Array(followingAuthors.prefix(followingAuthorLimit))
            let all = try await GitHubAPI.shared.fetchReposOfAuthors(capped)

            if followingAuthors.count > capped.count {
                statusHint = L("已关注 \(followingAuthors.count) 位作者，本次纳入前 \(capped.count) 位；每位取最近更新的 100 个项目，合并去重后共 \(all.count) 个。",
                               "Following \(followingAuthors.count) authors; first \(capped.count) included, 100 recent repos each — \(all.count) after merge.")
            } else {
                statusHint = L("来自你关注的 \(followingAuthors.count) 位作者，合并去重后共 \(all.count) 个项目。",
                               "From the \(followingAuthors.count) authors you follow — \(all.count) projects after merge.")
            }
            return Self.sorted(all, by: config.sortOption)

        case .saved:
            return favorites.repos
        }
    }

    /// 把搜索框里的人类写法翻译成 GitHub 查询语法。
    ///
    ///   `@antfu`               → `user:antfu`            按作者
    ///   `antfu/vitesse`        → `repo:antfu/vitesse`    精确到某个项目
    ///   `swiftui`              → 原样（GitHub 匹配名称 / 描述 / README）
    ///   `topic:mcp stars:>500` → 原样透传（支持全部原生语法）
    nonisolated static func githubQuery(from raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return text }

        // @作者
        if text.hasPrefix("@"), !text.contains(" ") {
            let login = text.dropFirst().trimmingCharacters(in: .whitespaces)
            return login.isEmpty ? text : "user:\(login)"
        }

        // 作者/项目（不含空格、只有一个斜杠，且不是原生 qualifier）
        if !text.contains(" "),
           text.filter({ $0 == "/" }).count == 1,
           !text.contains(":") {
            return "repo:\(text)"
        }

        return text
    }

    /// 「换一位推荐」：在高质量候选池里随机换一个 ≠ 当前的。
    func shuffleSpotlight() {
        let candidates = Self.topScored(from: repos, count: 10).filter { $0.id != spotlightRepo?.id }
        if let next = candidates.randomElement() {
            spotlightRepo = next
        }
    }

    // MARK: - 收藏（纯本地实现见 FavoritesStore）

    var savedRepos: [GitHubRepo] { favorites.repos }

    /// 当前该显示哪一批卡片。
    var displayedRepos: [GitHubRepo] {
        pane == .saved ? favorites.repos : repos
    }

    // MARK: - 随机探索（抽奖式）

    /// 候选池：当前列表 ∪ 收藏，按仓库去重。
    var explorePool: [GitHubRepo] {
        var seen = Set<Int>()
        var pool: [GitHubRepo] = []
        for repo in repos + favorites.repos where seen.insert(repo.id).inserted {
            pool.append(repo)
        }
        return pool
    }

    /// 加权随机抽取：权重 = 1 / (1 + 本轮已抽中次数)。
    /// 抽过的项目权重递减，保证一轮里不会反复看到同一批头部项目。
    private func weightedPick() -> GitHubRepo? {
        let pool = explorePool
        guard !pool.isEmpty else { return nil }

        let weights = pool.map { 1.0 / Double(1 + (drawCounts[$0.id] ?? 0)) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return pool.randomElement() }

        var remaining = Double.random(in: 0..<total)
        for (index, weight) in weights.enumerated() {
            remaining -= weight
            if remaining <= 0 { return pool[index] }
        }
        return pool.last
    }

    /// 开始一轮「抽奖」：先高速轮播，再逐步减速，最后定格。
    ///
    /// 手感参数刻意集中在这里，方便调：
    ///   前 1.1s 固定 45ms 换一次（约 24 次），之后每步 ×1.35 逐步变慢，
    ///   总时长约 1.75s，最后一次间隔约 200ms。
    func startExplore() {
        exploreTask?.cancel()

        guard !explorePool.isEmpty else {
            exploreRepo = nil
            isExploring = false
            return
        }

        isExploring = true
        exploreTask = Task { [weak self] in
            guard let self else { return }

            let start = Date()
            let fastPhase: TimeInterval = 1.1
            let total: TimeInterval = 1.75
            var delay: UInt64 = 45_000_000

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                if elapsed >= total { break }

                if let next = self.weightedPick() {
                    self.exploreRepo = next
                }

                if elapsed > fastPhase {
                    delay = min(UInt64(Double(delay) * 1.35), 260_000_000)
                }
                try? await Task.sleep(nanoseconds: delay)
            }

            guard !Task.isCancelled else { return }

            // 定格：这一位才是真正"抽中"的，计入权重
            if let final = self.weightedPick() {
                self.exploreRepo = final
                self.drawCounts[final.id, default: 0] += 1
            }
            self.isExploring = false
        }
    }

    func stopExplore() {
        exploreTask?.cancel()
        exploreTask = nil
        isExploring = false
        exploreRepo = nil
    }

    // MARK: - 统计

    private func computeStats(_ list: [GitHubRepo]) -> RepoStats {
        guard !list.isEmpty else { return RepoStats() }
        let cutoff = Date().addingTimeInterval(-90 * 86400)
        let active = list.filter { ($0.pushedAt ?? .distantPast) > cutoff }.count
        return RepoStats(
            count: list.count,
            activePercent: Int((Double(active) / Double(list.count) * 100).rounded()),
            maxStars: list.map(\.stargazersCount).max() ?? 0
        )
    }

    // MARK: - 今日精选推荐算法
    // 综合分 = 0.5×log(星标+1)归一化 + 0.3×log(Fork+1)归一化 + 0.2×最近活跃度
    // 最近活跃度 = exp(-距今天数 / 180)，越近期推送分越高。

    private static func score(of repo: GitHubRepo, maxStars: Double, maxForks: Double) -> Double {
        let s = log(Double(repo.stargazersCount) + 1)
        let f = log(Double(repo.forksCount) + 1)
        let ns = maxStars > 0 ? s / maxStars : 0
        let nf = maxForks > 0 ? f / maxForks : 0
        let days = repo.pushedAt.map { Date().timeIntervalSince($0) / 86400 } ?? 365
        let recency = exp(-max(days, 0) / 180)
        return 0.5 * ns + 0.3 * nf + 0.2 * recency
    }

    /// 逐作者拉取后得到的并集没有接口顺序，必须在客户端按所选项排序。
    /// （Search 接口能直接按 sort 参数返回，这条路径不能。）
    static func sorted(_ repos: [GitHubRepo], by option: RepoSortOption) -> [GitHubRepo] {
        switch option {
        case .stars:
            return repos.sorted { $0.stargazersCount > $1.stargazersCount }
        case .forks:
            return repos.sorted { $0.forksCount > $1.forksCount }
        case .updated, .recommended:
            return repos.sorted { ($0.pushedAt ?? .distantPast) > ($1.pushedAt ?? .distantPast) }
        case .bestMatch:
            // 并集里没有"相关性"可算，退化为按星标
            return repos.sorted { $0.stargazersCount > $1.stargazersCount }
        }
    }

    /// 按综合分从高到低重排。Discover 用它做「算法混排」。
    static func ranked(_ repos: [GitHubRepo]) -> [GitHubRepo] {
        guard !repos.isEmpty else { return [] }
        let maxStars = repos.map { log(Double($0.stargazersCount) + 1) }.max() ?? 1
        let maxForks = repos.map { log(Double($0.forksCount) + 1) }.max() ?? 1
        return repos.sorted {
            score(of: $0, maxStars: maxStars, maxForks: maxForks)
                > score(of: $1, maxStars: maxStars, maxForks: maxForks)
        }
    }

    /// 按综合分从高到低取前 count 个。
    static func topScored(from repos: [GitHubRepo], count: Int) -> [GitHubRepo] {
        Array(ranked(repos).prefix(count))
    }

    /// 今日精选：取综合分 Top5，用当天日期做种子选一个 —— 同一天固定、跨天自动换。
    static func dailyPick(from repos: [GitHubRepo]) -> GitHubRepo? {
        let top = topScored(from: repos, count: 5)
        guard !top.isEmpty else { return nil }
        let daySeed = Int(Date().timeIntervalSince1970 / 86400)
        return top[daySeed % top.count]
    }
}
