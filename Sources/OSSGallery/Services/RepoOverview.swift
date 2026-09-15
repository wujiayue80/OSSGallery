import Foundation

/// 从 README 提炼一段"这个项目是干什么的"。
///
/// 取法：`GET /repos/{owner}/{repo}/readme` + `Accept: application/vnd.github.raw+json`
/// → 直接返回原始 Markdown，**不需要解 base64**（实测确认）。
///
/// 为什么不能直接截前 N 个字符：实测 `public-apis` 的 README 开头是赞助广告
/// （链接带 `utm_source`），`oven-sh/bun` 的开头是 `<p align="center">` + logo + 一堆 shields 徽章。
///
/// 实测过三种策略（同一测试集：openclaw / public-apis / awesome / tensorflow / freeCodeCamp / markitdown）：
///   ① 前几段拼接              → 一半项目抓到广告或导航
///   ② 按"越像长句子越好"打分    → **更糟**，会取到文档中段（Node 安装说明、认证流程说明）
///   ③ 从开头取第一个干净段落    → 最好（本实现）
///
/// 关键点：判断"脏段落"必须在**剥离 Markdown 链接之前**用原始段落做，
/// 否则识别不出 `utm_` / `&nbsp;` / 链接密度。
///
/// 局限（已知）：覆盖率约 2/3。README 本身是导航页（如 `sindresorhus/awesome`）
/// 或开头就是提示块的项目会提取失败 —— 此时调用方必须走 `fallback(for:)`。
enum RepoOverview {

    /// 返回 nil 表示没提取到可用叙述，调用方应走结构化兜底。
    static func fetch(fullName: String) async -> String? {
        guard let url = URL(string: "https://api.github.com/repos/\(fullName)/readme") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
        let token = ConfigManager.shared.apiKey
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let markdown = String(data: data, encoding: .utf8) else {
            return nil
        }
        return extract(from: markdown)
    }

    static func extract(from markdown: String, limit: Int = 400) -> String? {
        let paragraphs = markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var picked: [String] = []
        var total = 0

        for paragraph in paragraphs.prefix(10) {
            guard !isNoise(paragraph) else { continue }
            let text = plainText(paragraph)
            guard !text.isEmpty else { continue }
            picked.append(text)
            total += text.count
            if total >= limit { break }
        }

        guard !picked.isEmpty else { return nil }
        return String(picked.joined(separator: " ").prefix(limit))
    }

    /// 结构化兜底：README 提取失败时，用客观事实拼一段概述，保证「概览」区块永不空白。
    /// 明确标注来源是元数据而不是项目自述，避免误导。
    static func fallback(for repo: GitHubRepo) -> String {
        var parts: [String] = []

        if let language = repo.language, !language.isEmpty {
            parts.append(L("以 \(language) 为主的开源项目", "Open-source project mainly in \(language)"))
        } else {
            parts.append(L("开源项目", "Open-source project"))
        }

        if repo.topics.isEmpty == false {
            parts.append(L("主题 \(repo.topics.prefix(5).joined(separator: " / "))",
                           "topics \(repo.topics.prefix(5).joined(separator: " / "))"))
        }

        parts.append(L("\(RepoFormat.count(repo.stargazersCount)) 星标 · \(RepoFormat.count(repo.forksCount)) Fork",
                       "\(RepoFormat.count(repo.stargazersCount)) stars · \(RepoFormat.count(repo.forksCount)) forks"))

        if let pushed = repo.pushedAt {
            let days = Int(Date().timeIntervalSince(pushed) / 86400)
            parts.append(days <= 30
                         ? L("近 30 天仍有更新", "updated within 30 days")
                         : L("最近推送在 \(days) 天前", "last pushed \(days) days ago"))
        }

        if let license = repo.license {
            parts.append(L("许可证 \(license.spdxId ?? license.name)", "license \(license.spdxId ?? license.name)"))
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - 内部

    /// 脏段落判定。**必须用原始段落**（含 Markdown 链接），否则看不出 utm_ 与链接密度。
    private static func isNoise(_ raw: String) -> Bool {
        let text = plainText(raw)
        if text.count < 55 { return true }

        let lower = raw.lowercased()
        if lower.contains("utm_") || lower.contains("sponsor") || lower.contains("donate") { return true }
        if lower.contains("shields.io") || lower.contains("img.shields") || lower.contains("badge") { return true }
        if raw.contains("&nbsp;") { return true }
        // GitHub 的 [!IMPORTANT] / [!NOTE] 提示块
        if raw.hasPrefix("[!") { return true }
        // 以链接开头的段落（通常是 logo 行）
        if let range = raw.range(of: "https?://", options: .regularExpression),
           raw.distance(from: raw.startIndex, to: range.lowerBound) < 20 {
            return true
        }
        // 链接密度过高 → 导航栏
        let links = matchCount(pattern: #"\[[^\]]*\]\([^)]*\)"#, in: raw)
        if links >= 2, text.count < links * 25 { return true }

        return false
    }

    /// 剥离 Markdown / HTML 标记，得到纯文本。
    private static func plainText(_ raw: String) -> String {
        var text = raw
        text = replacing(#"<[^>]+>"#, with: " ", in: text)
        text = replacing(#"!\[[^\]]*\]\([^)]*\)"#, with: " ", in: text)     // 图片
        text = replacing(#"\[([^\]]*)\]\([^)]*\)"#, with: "$1", in: text)    // 链接 → 保留文字
        text = replacing(#"(?m)^#{1,6}\s*"#, with: "", in: text)             // 标题标记
        text = replacing(#"(?m)^[>\-\*\+\d\.]+\s*"#, with: "", in: text)     // 列表 / 引用
        text = replacing(#"[`*_|]"#, with: "", in: text)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        return text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func replacing(_ pattern: String, with template: String, in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func matchCount(pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }
}
