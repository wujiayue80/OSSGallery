import Foundation
import SwiftUI

/// 应用语言偏好。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system     // 跟随系统
    case zh         // 中文
    case en         // English

    var id: String { rawValue }

    /// 生效的本地化语言代码（system 时按系统首选语言判断）。
    var effectiveCode: String {
        switch self {
        case .zh: return "zh"
        case .en: return "en"
        case .system:
            return (Locale.preferredLanguages.first?.hasPrefix("zh") == true) ? "zh" : "en"
        }
    }
}

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @AppStorage("github_api_key") var apiKey: String = ""
    @AppStorage("custom_categories") private var customCategoriesData: Data = Data()

    // MARK: - 通用设置（语言 / 记录数 / 排序）
    @AppStorage("app_language") var appLanguageRaw: String = AppLanguage.system.rawValue
    @AppStorage("per_page") var perPage: Int = 30
    @AppStorage("sort_option") var sortOptionRaw: String = RepoSortOption.stars.rawValue
    @AppStorage("sort_order") var sortOrder: String = "desc"
    /// 默认分类的版本号，用于把重新设计过的默认分类推送给老用户。
    @AppStorage("categories_version") private var categoriesVersion: Int = 0

    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRaw) ?? .system }
        set { appLanguageRaw = newValue.rawValue }
    }

    var sortOption: RepoSortOption {
        get { RepoSortOption(rawValue: sortOptionRaw) ?? .stars }
        set { sortOptionRaw = newValue.rawValue }
    }

    @Published var categories: [SearchCategory] = []

    /// 默认分类的版本号。每次调整默认分类就 +1 ——
    /// 否则用户本地已存的 custom_categories 会一直盖住新默认值，改了也看不到。
    private let currentCategoriesVersion = 2

    // 查询语句里不写 sort:stars-desc —— GitHub 排序走独立 sort/order 参数，
    // 写在 q 里属于无效 qualifier。
    //
    // 规则语法（两套并存）：
    //   · `|`  = 并集：拆成多个子查询，客户端并发请求后合并去重
    //            （GitHub 的 OR 不能用于 topic:/user: 等限定符，实测会被 422 拒绝）
    //   · 空格 = 交集：GitHub 原生语义
    //   · 支持全部原生语法：topic: language: stars:> pushed:> user: repo:
    //
    // 命名原则：一个分类对应一类"用户真正想要的东西"，而不是按语言切。
    // 下面每个 topic 都实测过真实量级，不会配出空分类。
    let defaultCategories: [SearchCategory] = [
        SearchCategory(name: "🔥 热门", query: "stars:>3000"),
        SearchCategory(name: "🤖 AI / LLM", query: "topic:llm | topic:ai"),
        SearchCategory(name: "🧩 AI Agent", query: "topic:ai-agent | topic:agents | topic:agent"),
        SearchCategory(name: "🧠 RAG / MCP", query: "topic:rag | topic:mcp"),
        SearchCategory(name: "🛠️ 开发工具", query: "topic:developer-tools | topic:cli"),
        SearchCategory(name: "🔌 插件 / 扩展", query: "topic:plugin | topic:vscode-extension"),
        SearchCategory(name: "🍎 Claude / Skill", query: "topic:claude-code | topic:skills | topic:prompt-engineering"),
        SearchCategory(name: "🖥️ 桌面软件", query: "topic:desktop-app | topic:tauri | topic:electron")
    ]

    init() {
        loadCategories()
    }

    func loadCategories() {
        // 版本迁移：默认分类被重新设计过，覆盖用户本地那份旧默认
        if categoriesVersion < currentCategoriesVersion {
            self.categories = defaultCategories
            categoriesVersion = currentCategoriesVersion
            saveCategories()
            return
        }

        if let decoded = try? JSONDecoder().decode([SearchCategory].self, from: customCategoriesData), !decoded.isEmpty {
            self.categories = decoded
        } else {
            self.categories = defaultCategories
            saveCategories()
        }
    }

    func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            customCategoriesData = encoded
        }
    }

    func addCategory(name: String, query: String) {
        let newCategory = SearchCategory(name: name, query: query)
        categories.append(newCategory)
        saveCategories()
    }

    func updateCategory(id: UUID, name: String, query: String) {
        if let index = categories.firstIndex(where: { $0.id == id }) {
            categories[index].name = name
            categories[index].query = query
            saveCategories()
        }
    }

    func deleteCategory(id: UUID) {
        categories.removeAll(where: { $0.id == id })
        saveCategories()
    }

    func resetToDefaultCategories() {
        categories = defaultCategories
        saveCategories()
    }

    func removeCategory(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        saveCategories()
    }
}
