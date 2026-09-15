import SwiftUI

struct SettingsView: View {
    @ObservedObject var config = ConfigManager.shared
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    // Token 直接用视图级 @AppStorage 绑定（而不是经 ConfigManager 的 @AppStorage 转发）。
    // 两者读写的是同一个 UserDefaults 键，数据不会不同步；
    // 但视图级 @AppStorage 是官方文档给出的标准用法，绑定行为最可靠。
    @AppStorage("github_api_key") private var apiKey: String = ""

    @State private var newCategoryName = ""
    @State private var newCategoryQuery = ""
    /// 规则试跑的结果文字（"✓ 可查到…"/"✗ …"）
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        // 窗口标题与左上角「关闭 / 最小化 / 全屏」三个按钮由系统提供，
        // 因此不再自绘标题栏与关闭按钮，把垂直空间让给内容。
        TabView {
            generalTab
                .tabItem {
                    Label(L("通用", "General"), systemImage: "gearshape")
                }

            categoriesTab
                .tabItem {
                    Label(L("分类", "Categories"), systemImage: "tag")
                }
        }
        // 最小尺寸交给窗口，用户可自由拉伸；不再写死 540×520。
        .frame(minWidth: 560, minHeight: 520)
        // 显式打开「可缩放 + 可全屏」，否则绿色按钮会显示「+」且拖边缘无效。
        .allowWindowResizingAndFullScreen()
        .preferredColorScheme(.dark)
        .background(WindowAccessor { window in
            WindowConfigurator.apply(to: window)
        })
    }

    // MARK: - 通用

    private var generalTab: some View {
        Form {
            Section(L("界面与语言", "Appearance & Language")) {
                Picker(L("语言", "Language"), selection: $config.appLanguageRaw) {
                    Text(L("跟随系统", "System")).tag(AppLanguage.system.rawValue)
                    Text("中文").tag(AppLanguage.zh.rawValue)
                    Text("English").tag(AppLanguage.en.rawValue)
                }
            }

            Section(L("列表与排序", "List & Sorting")) {
                Picker(L("排序方式", "Sort By"), selection: $config.sortOptionRaw) {
                    Text(L("相关性", "Relevance")).tag(RepoSortOption.bestMatch.rawValue)
                    Text(L("最多星标", "Most Stars")).tag(RepoSortOption.stars.rawValue)
                    Text(L("最多 Fork", "Most Forks")).tag(RepoSortOption.forks.rawValue)
                    Text(L("最近更新", "Recently Updated")).tag(RepoSortOption.updated.rawValue)
                }

                // 原实现把带 Spacer 的 HStack 当作 Stepper 的 label，
                // 在 Form 的 label 列里 Spacer 会被压成 0，两个 Text 挤在一起。
                // 改为 LabeledContent：标签归 label 列，数值与步进器归 value 列。
                LabeledContent(L("每页数量", "Results Per Page")) {
                    HStack(spacing: 10) {
                        Text("\(config.perPage)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        Stepper("", value: $config.perPage, in: 10...100, step: 10)
                            .labelsHidden()
                    }
                }

                Text(L("修改后主窗口会立即重新加载，无需关闭此窗口。",
                       "The main window reloads immediately — no need to close this window."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(L("GitHub API 配置", "GitHub API Configuration")) {
                LabeledContent("Personal Access Token") {
                    SecureField("", text: $apiKey,
                                prompt: Text("ghp_… 或 github_pat_…"))
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 240)
                }

                // 键盘输入不可用时，用鼠标一键填入，绕开键入环节。
                HStack(spacing: 8) {
                    Button(L("从剪贴板粘贴", "Paste from clipboard")) {
                        if let raw = NSPasteboard.general.string(forType: .string) {
                            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { apiKey = trimmed }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(L("清空", "Clear")) { apiKey = "" }
                        .controlSize(.small)
                        .disabled(apiKey.isEmpty)

                    Spacer()

                    Text(apiKey.isEmpty
                         ? L("未填入", "Not set")
                         : L("已填入 \(apiKey.count) 个字符", "\(apiKey.count) characters"))
                        .font(.caption)
                        .foregroundColor(apiKey.isEmpty ? .orange : .green)
                }

                HStack {
                    Text(L("路径：Settings → Developer settings → Personal access tokens（不是 OAuth Apps，也不是 GitHub Apps）",
                           "Path: Settings → Developer settings → Personal access tokens (not OAuth Apps, not GitHub Apps)"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(L("打开申请页", "Open token page")) {
                        if let url = URL(string: "https://github.com/settings/tokens") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }

                Text(L("正确的页面没有任何 URL 字段——创建表单只有 Note、Expiration、Select scopes 三块。推荐经典 Token：Tokens (classic) → Generate new token (classic)，不勾任何 scope。若用细粒度 Token，需 Account permissions → Followers → Read。",
                       "The correct page has no URL fields at all — the form only asks for Note, Expiration and Scopes. A classic token needs no scopes (Tokens (classic) → Generate new token (classic)). A fine-grained token needs Account permissions → Followers → Read."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 分类

    private var categoriesTab: some View {
        VStack(spacing: 0) {
            List {
                ForEach(config.categories) { category in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(category.name).font(.headline)
                            Text(category.query).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        // 并集规则给个标记，一眼看出这条规则会发多次请求
                        if category.isUnion {
                            Text(L("并集 \(category.subQueries.count) 项", "union ×\(category.subQueries.count)"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                .onDelete(perform: config.removeCategory)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                // 规则语法说明 —— 这几行是"怎么配"的全部答案
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("规则怎么写", "How to write a rule"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(L("· `|` = 并集：topic:llm | topic:ai（拆成多次请求后合并去重）\n· 空格 = 交集：topic:ai topic:llm（同时带这两个 topic）\n· 支持原生语法：topic:  language:  stars:>  pushed:>  user:",
                           "· `|` = union: topic:llm | topic:ai (fetched separately, then merged)\n· space = intersection: topic:ai topic:llm\n· native syntax: topic:  language:  stars:>  pushed:>  user:"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LabeledContent(L("名称", "Name")) {
                    TextField("", text: $newCategoryName,
                              prompt: Text(L("如：🔥 Rust Web", "e.g. 🔥 Rust Web")))
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 240)
                }

                LabeledContent(L("规则", "Query")) {
                    HStack(spacing: 8) {
                        TextField("", text: $newCategoryQuery,
                                  prompt: Text(L("如：topic:rust | topic:webassembly", "e.g. topic:rust | topic:webassembly")))
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 240)

                        Button(L("测试", "Test")) { testRule() }
                            .controlSize(.small)
                            .disabled(newCategoryQuery.trimmingCharacters(in: .whitespaces).isEmpty || isTesting)
                    }
                }

                if isTesting {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.5)
                        Text(L("正在查询…", "Querying…"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else if let testResult {
                    Text(testResult)
                        .font(.system(size: 10))
                        .foregroundColor(testResult.hasPrefix("✓") ? .green : .orange)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    Button(L("添加", "Add")) {
                        guard !newCategoryName.isEmpty, !newCategoryQuery.isEmpty else { return }
                        config.addCategory(name: newCategoryName, query: newCategoryQuery)
                        newCategoryName = ""
                        newCategoryQuery = ""
                        testResult = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newCategoryName.isEmpty || newCategoryQuery.isEmpty)
                }
            }
            .padding()
        }
    }

    /// 试跑一次规则，立刻告诉用户"能查到东西"还是"写错了"。
    /// 目的：避免配出一条查不到任何项目的空分类 —— 空分类在界面上和"功能坏了"没有区别。
    private func testRule() {
        let raw = newCategoryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        isTesting = true
        testResult = nil

        let category = SearchCategory(name: "probe", query: raw)
        Task {
            do {
                let repos = try await GitHubAPI.shared.fetchRepos(
                    subQueries: category.subQueries,
                    sort: .stars,
                    order: "desc",
                    perPage: 5
                )
                if repos.isEmpty {
                    testResult = L("✗ 没有查到任何项目，这条规则可能是空的或写错了",
                                   "✗ No results — this rule may be empty or malformed")
                } else {
                    testResult = L("✓ 可查到结果（取回 \(repos.count) 个，例如 \(repos[0].fullName)）",
                                   "✓ Found results (\(repos.count) returned, e.g. \(repos[0].fullName))")
                }
            } catch {
                testResult = L("✗ 查询失败：", "✗ Failed: ") + error.localizedDescription
            }
            isTesting = false
        }
    }
}
