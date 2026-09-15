import Foundation

/// 本地收藏。
///
/// 设计取舍：纯本地存储，不与 GitHub 账号绑定、不需要任何授权。
/// 好处是离线可用、零权限；代价是换机器需要重新收藏。
/// （另一种做法是复用 PAT 读 GitHub 的 star 列表，但那会把「能否用收藏」
/// 绑定到「有没有填 PAT」上，因此这里不采用。）
///
/// 存储：UserDefaults + JSON，键 `saved_repos`。
/// 记录收藏时间，用于收藏页的「按收藏时间 / 按星标」排序。
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    private let storageKey = "saved_repos"

    /// 收藏条目。带上 savedAt 才能按收藏时间排序、显示收藏时间角标。
    struct Entry: Codable, Identifiable {
        var repo: GitHubRepo
        var savedAt: Date
        var id: Int { repo.id }
    }

    @Published private(set) var entries: [Entry] = []

    /// 兼容旧接口：只取仓库本身。
    var repos: [GitHubRepo] { entries.map(\.repo) }

    private init() {
        load()
    }

    func contains(_ repo: GitHubRepo) -> Bool {
        entries.contains { $0.repo.id == repo.id }
    }

    func savedAt(_ repo: GitHubRepo) -> Date? {
        entries.first { $0.repo.id == repo.id }?.savedAt
    }

    /// 收藏 / 取消收藏。新收藏插到最前，符合"最近收藏优先"的直觉。
    func toggle(_ repo: GitHubRepo) {
        if let index = entries.firstIndex(where: { $0.repo.id == repo.id }) {
            entries.remove(at: index)
        } else {
            entries.insert(Entry(repo: repo, savedAt: Date()), at: 0)
        }
        save()
    }

    func removeAll() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }

        // 新格式：带收藏时间
        if let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
            return
        }
        // 旧格式：只有仓库数组。迁移过来，收藏时间用"现在"兜底。
        if let legacy = try? JSONDecoder().decode([GitHubRepo].self, from: data) {
            let now = Date()
            entries = legacy.map { Entry(repo: $0, savedAt: now) }
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
