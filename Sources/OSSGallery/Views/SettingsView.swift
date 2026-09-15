import SwiftUI

struct SettingsView: View {
    @ObservedObject var config = ConfigManager.shared
    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue
    @AppStorage("github_api_key") private var apiKey: String = ""

    @State private var newCategoryName = ""
    @State private var newCategoryQuery = ""
    @State private var editingCategoryId: UUID? = nil
    /// 规则试跑的结果文字（"✓ 可查到…"/"✗ …"）
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
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
        .frame(minWidth: 600, minHeight: 560)
        .allowWindowResizingAndFullScreen()
        .preferredColorScheme(.dark)
        .background(WindowAccessor { window in
            WindowConfigurator.apply(to: window)
            window.level = .floating
        })
        .onAppear {
            ModalWindowManager.shared.settingsOpened()
        }
        .onDisappear {
            ModalWindowManager.shared.settingsClosed()
        }
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
                }

                Text(L("无需勾选任何敏感权限（保持只读即可）。填入后接口限流从 60 次/小时提升到 5000 次/小时。",
                       "No special scopes required (read-only is fine). Increases rate limit from 60 to 5,000/hr."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 分类

    private var categoriesTab: some View {
        VStack(spacing: 0) {
            // 列表区
            List {
                ForEach(config.categories) { category in
                    let isEditingThis = editingCategoryId == category.id
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(category.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isEditingThis ? .cyan : .white)

                                if isEditingThis {
                                    Text(L("正在编辑", "Editing"))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.cyan)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.cyan.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(category.query)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if category.isUnion {
                            Text(L("并集 \(category.subQueries.count) 项", "union ×\(category.subQueries.count)"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.cyan.opacity(0.9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        // 编辑按钮
                        Button {
                            startEditing(category)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cyan)
                                .padding(6)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(L("修改此分类", "Edit this category"))

                        // 删除按钮
                        Button {
                            deleteCategory(category)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red.opacity(0.85))
                                .padding(6)
                                .background(Color.red.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(L("删除此分类", "Delete this category"))
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: config.removeCategory)
            }

            Divider()

            // 编辑 / 添加 表单区
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let editingId = editingCategoryId,
                       let target = config.categories.first(where: { $0.id == editingId }) {
                        Label(L("修改分类：「\(target.name)」", "Edit Category: \"\(target.name)\""), systemImage: "pencil.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                    } else {
                        Label(L("添加新分类", "Add New Category"), systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    Button(L("恢复初始默认分类", "Reset to Defaults")) {
                        config.resetToDefaultCategories()
                        cancelEditing()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }

                // 规则语法简述
                Text(L("· `|` = 并集：topic:llm | topic:ai（拆成多个子查询合并）\n· 空格 = 交集：topic:ai stars:>1000\n· 原生语法全支持：topic: language: stars:> user: repo:",
                       "· `|` = union: topic:llm | topic:ai\n· space = intersection: topic:ai stars:>1000\n· native qualifiers: topic: language: stars:> user: repo:"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LabeledContent(L("名称", "Name")) {
                    TextField("", text: $newCategoryName,
                              prompt: Text(L("如：🔥 实用工具", "e.g. 🔥 Tools")))
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 260)
                }

                LabeledContent(L("规则", "Query")) {
                    HStack(spacing: 8) {
                        TextField("", text: $newCategoryQuery,
                                  prompt: Text(L("如：topic:cli | topic:tool", "e.g. topic:cli | topic:tool")))
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 260)

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
                    if editingCategoryId != nil {
                        Button(L("取消修改", "Cancel")) {
                            cancelEditing()
                        }
                        .controlSize(.small)
                    }

                    Spacer()

                    Button(editingCategoryId != nil ? L("保存修改", "Save Changes") : L("添加分类", "Add Category")) {
                        saveOrAddCategory()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty ||
                              newCategoryQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
            .background(Color.white.opacity(0.025))
        }
    }

    private func startEditing(_ category: SearchCategory) {
        editingCategoryId = category.id
        newCategoryName = category.name
        newCategoryQuery = category.query
        testResult = nil
    }

    private func cancelEditing() {
        editingCategoryId = nil
        newCategoryName = ""
        newCategoryQuery = ""
        testResult = nil
    }

    private func deleteCategory(_ category: SearchCategory) {
        if editingCategoryId == category.id {
            cancelEditing()
        }
        config.deleteCategory(id: category.id)
    }

    private func saveOrAddCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        let query = newCategoryQuery.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !query.isEmpty else { return }

        if let id = editingCategoryId {
            config.updateCategory(id: id, name: name, query: query)
        } else {
            config.addCategory(name: name, query: query)
        }
        cancelEditing()
    }

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
