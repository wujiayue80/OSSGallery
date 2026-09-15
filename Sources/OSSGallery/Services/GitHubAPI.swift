import Foundation

/// GitHub Search API 支持的排序方式。
/// 注意：sort/order 必须作为独立参数传递，写在 q 查询串里无效。
enum RepoSortOption: String, CaseIterable, Identifiable {
    /// 客户端综合分混排（发现模式的默认）。
    /// 它不对应任何 GitHub sort 参数 —— 接口只负责给候选池，排序在客户端做。
    case recommended = "recommended"
    case bestMatch = ""       // 相关性（不传 sort 参数，交给 GitHub 自己算）
    case stars = "stars"      // 最多星标
    case forks = "forks"      // 最多 Fork
    case updated = "updated"  // 最近更新

    var id: String { rawValue }

    /// 传给 GitHub 的 sort 参数值；不需要传的返回 nil。
    var apiValue: String? {
        switch self {
        case .recommended, .bestMatch: return nil
        default: return rawValue
        }
    }

    /// 是否需要客户端二次排序（综合分混排）。
    var isClientRanked: Bool { self == .recommended }

    var title: String {
        switch self {
        case .recommended: return L("综合推荐", "Recommended")
        case .bestMatch:   return L("相关性", "Relevance")
        case .stars:       return L("最多星标", "Most Stars")
        case .forks:       return L("最多 Fork", "Most Forks")
        case .updated:     return L("最近更新", "Recently Updated")
        }
    }
}

enum GitHubAPIError: LocalizedError {
    case missingToken
    case badToken
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return L("请先在控制台里填入 GitHub Personal Access Token",
                     "Add a GitHub Personal Access Token in the console first.")
        case .badToken:
            return L("GitHub Token 无效或已过期", "The GitHub token is invalid or has expired.")
        case .http(let code):
            if code == 403 || code == 429 {
                return L("GitHub 接口限流了（HTTP \(code)），稍后再试或确认 Token 已填入",
                         "GitHub rate limit reached (HTTP \(code)). Try again later or check your token.")
            }
            return L("GitHub 返回 HTTP \(code)", "GitHub returned HTTP \(code).")
        }
    }
}

class GitHubAPI {
    static let shared = GitHubAPI()

    /// - Parameters:
    ///   - query: 搜索关键字 / qualifier（例如 "topic:swiftui"）
    ///   - sort: 排序方式（独立 sort 参数）
    ///   - order: 排序方向 "desc" / "asc"
    ///   - perPage: 每页条数（GitHub 上限 100）
    func fetchRepos(query: String,
                    sort: RepoSortOption = .bestMatch,
                    order: String = "desc",
                    perPage: Int = 30) async throws -> [GitHubRepo] {
        guard var urlComponents = URLComponents(string: "https://api.github.com/search/repositories") else {
            throw URLError(.badURL)
        }

        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        if let sortValue = sort.apiValue {
            queryItems.append(URLQueryItem(name: "sort", value: sortValue))
            queryItems.append(URLQueryItem(name: "order", value: order))
        }
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }

        let data = try await send(url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let searchResponse = try decoder.decode(GitHubSearchResponse.self, from: data)
        return searchResponse.items
    }

    /// 并发执行多个子查询，合并去重后返回。
    ///
    /// 用于分类规则里的 `|` 并集（见 `SearchCategory.subQueries`）。
    /// 合并方式：**轮转交错**（各子查询轮流取一条），而不是全部按星标重排 ——
    /// 这样每个子查询都能得到公平的曝光，同时保留接口返回的相对顺序，
    /// 用户选的「排序方式」仍然近似生效。
    func fetchRepos(subQueries: [String],
                    sort: RepoSortOption = .bestMatch,
                    order: String = "desc",
                    perPage: Int = 30) async throws -> [GitHubRepo] {
        let queries = subQueries.isEmpty ? [""] : subQueries

        if queries.count == 1 {
            return try await fetchRepos(query: queries[0], sort: sort, order: order, perPage: perPage)
        }

        var lists: [[GitHubRepo]] = []
        for q in queries {
            do {
                lists.append(try await fetchRepos(query: q, sort: sort, order: order, perPage: perPage))
            } catch {
                // 单个子查询失败（例如限流）不应让整个分类失败，跳过它继续
                lists.append([])
            }
        }

        var seen = Set<Int>()
        var merged: [GitHubRepo] = []
        let maxLen = lists.map(\.count).max() ?? 0
        var index = 0
        while index < maxLen && merged.count < perPage {
            for list in lists where index < list.count {
                let repo = list[index]
                if seen.insert(repo.id).inserted {
                    merged.append(repo)
                    if merged.count >= perPage { break }
                }
            }
            index += 1
        }
        return merged
    }

    /// 某个用户的公开仓库列表（`/users/{login}/repos`）。
    ///
    /// 与 Search 接口的关键区别：**没有 1000 条结果上限**，
    /// 因此这才是"列出某位作者的全部开源项目"的正确做法。
    /// 实测该接口返回的字段与 `GitHubRepo` 完全兼容（`topics` 无标签时返回空数组）。
    func fetchUserRepos(login: String, perPage: Int = 100) async throws -> [GitHubRepo] {
        guard var comps = URLComponents(string: "https://api.github.com/users/\(login)/repos") else {
            throw URLError(.badURL)
        }
        comps.queryItems = [
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "type", value: "owner")
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        let data = try await send(url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GitHubRepo].self, from: data)
    }

    /// 并发拉取多位作者的公开仓库并合并去重。
    ///
    /// 并发数刻意限制：一次打太多请求容易触发限流；分批串行推进，
    /// 单批内并发，兼顾速度与稳定。单个作者失败只跳过该作者，不影响整体。
    func fetchReposOfAuthors(_ logins: [String],
                             perAuthor: Int = 100,
                             concurrency: Int = 6) async throws -> [GitHubRepo] {
        var seen = Set<Int>()
        var merged: [GitHubRepo] = []
        var index = 0

        while index < logins.count {
            let batch = Array(logins[index..<min(index + concurrency, logins.count)])
            index += concurrency

            await withTaskGroup(of: [GitHubRepo].self) { group in
                for login in batch {
                    group.addTask {
                        (try? await self.fetchUserRepos(login: login, perPage: perAuthor)) ?? []
                    }
                }
                for await list in group {
                    for repo in list where seen.insert(repo.id).inserted {
                        merged.append(repo)
                    }
                }
            }
        }
        return merged
    }

    /// 读取当前 Token 对应用户的关注列表。
    ///
    /// 实测结论（用 curl 直接打 api.github.com 验证过），这也是关注流能做成的前提：
    ///   · `user:a OR user:b` 会被 GitHub 拒绝（HTTP 422，"Logical operators only apply
    ///     to text, not to qualifiers"）—— OR 不能用于限定符；
    ///   · 但**空格分隔的多个 `user:` 限定符是取并集**的：torvalds(9) + gaearon(61)
    ///     + sindresorhus(1129) 三条并排查询 total_count 恰好 1199；
    ///   · 查询串长度上限（文档写 256 字符）实测未被强制，100 个作者 / 1799 字符仍返回 200。
    /// 因此关注流可以用一次 Search 请求拼出来，不需要 N+1 次逐作者请求。
    ///
    /// 注意：`/user/following` 必须带 Token，无授权返回 401。
    func fetchFollowingLogins(perPage: Int = 100) async throws -> [String] {
        guard var comps = URLComponents(string: "https://api.github.com/user/following") else {
            throw URLError(.badURL)
        }
        comps.queryItems = [URLQueryItem(name: "per_page", value: String(perPage))]
        guard let url = comps.url else { throw URLError(.badURL) }

        let data = try await send(url)
        return try JSONDecoder().decode([GitHubUser].self, from: data).map(\.login)
    }

    // MARK: - 统一请求

    private func send(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let apiKey = ConfigManager.shared.apiKey
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // 401/403 在没有 Token 时最常见的含义是"未授权 / 限流"，分开提示更可操作
                throw apiKey.isEmpty ? GitHubAPIError.missingToken : GitHubAPIError.http(httpResponse.statusCode)
            }
            throw GitHubAPIError.http(httpResponse.statusCode)
        }
        return data
    }
}

/// `/user/following` 返回的条目只取登录名。
struct GitHubUser: Codable {
    let login: String
}
