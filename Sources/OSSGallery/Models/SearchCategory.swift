import Foundation

struct SearchCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var query: String

    /// 规则里的 `|` 表示**并集**：拆成多个子查询，由客户端并发请求后合并去重。
    ///
    /// 为什么不用 GitHub 原生的 `OR`：实测 `topic:a OR topic:b` 会被直接拒绝
    /// （HTTP 422，"Logical operators only apply to text, not to qualifiers"）——
    /// OR 只能作用于文本，不能作用于 topic:/user: 这类限定符。
    /// 所以在同一个分类里覆盖多个 topic，只能靠客户端把多次查询的结果合并。
    ///
    /// 而**空格**仍是 GitHub 原生语义（交集），例如 `topic:ai topic:llm` 表示
    /// 同时带这两个 topic 的仓库（实测 34,753 条）。
    var subQueries: [String] {
        let parts = query
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [query] : parts
    }

    var isUnion: Bool { subQueries.count > 1 }
}
