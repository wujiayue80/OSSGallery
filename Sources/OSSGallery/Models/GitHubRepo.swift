import Foundation

struct GitHubSearchResponse: Codable {
    let totalCount: Int
    let items: [GitHubRepo]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}

struct GitHubRepo: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let forksCount: Int
    let watchersCount: Int
    let openIssuesCount: Int
    let language: String?
    let htmlUrl: String
    let homepage: String?
    let size: Int
    let defaultBranch: String
    let topics: [String]
    let createdAt: Date?
    let updatedAt: Date?
    let pushedAt: Date?
    let license: License?
    let owner: Owner

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, owner, size, topics, license, homepage
        case fullName = "full_name"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case watchersCount = "watchers_count"
        case openIssuesCount = "open_issues_count"
        case htmlUrl = "html_url"
        case defaultBranch = "default_branch"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pushedAt = "pushed_at"
    }

    struct Owner: Codable, Hashable {
        let login: String
        let avatarUrl: String

        enum CodingKeys: String, CodingKey {
            case login
            case avatarUrl = "avatar_url"
        }
    }

    struct License: Codable, Hashable {
        let name: String
        let spdxId: String?

        enum CodingKeys: String, CodingKey {
            case name
            case spdxId = "spdx_id"
        }
    }

    var openGraphImageUrl: URL? {
        URL(string: "https://opengraph.githubassets.com/1/\(owner.login)/\(name)")
    }
}
