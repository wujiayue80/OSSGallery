import SwiftUI

/// 收藏页专属头部。
///
/// 为什么要单独做：收藏页原来直接复用首页布局（Hero + 网格），
/// 结果是"看不出这是收藏"。这里换成收藏自己的信息结构：
/// 标题 + 数量 + 语言分布 + 按收藏时间/星标排序 + 清空。
struct SavedHeaderView: View {
    let count: Int
    let languageCounts: [(name: String, count: Int)]
    @Binding var sortBy: String
    var onClear: () -> Void

    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.yellow)
                    Text(L("我的收藏", "Saved"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }

                if !languageCounts.isEmpty {
                    HStack(spacing: 6) {
                        Text(L("语言分布", "Languages"))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        ForEach(languageCounts, id: \.name) { item in
                            HStack(spacing: 4) {
                                Text(item.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.cyan.opacity(0.9))
                                Text("\(item.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            // 卡片区右上角：本地排序 + 显示方式
            HStack(spacing: 8) {
                Picker("", selection: $sortBy) {
                    Text(L("按收藏时间", "By saved time")).tag("time")
                    Text(L("按星标", "By stars")).tag("stars")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .help(L("收藏页是本地数据，按收藏时间或星标排序", "Local data — sort by saved time or stars"))

                ViewStyleToggle()

                Button(role: .destructive, action: onClear) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red.opacity(0.85))
                .help(L("清空全部收藏", "Clear all saved"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }
}

/// 关注页专属头部。
///
/// 关注流是"按作者聚合"的，所以头部是作者维度：
/// 作者头像横条（点头像只看他一个人的项目）+ 统计 + 排序与显示方式。
struct FollowingHeaderView: View {
    let authors: [String]
    let selectedAuthor: String?
    let repoCount: Int
    var onSelectAuthor: (String?) -> Void

    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.cyan)
                        Text(L("我关注的作者", "Following"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text(L("已关注 \(authors.count) 位作者 · 合并去重后 \(repoCount) 个项目",
                           "\(authors.count) authors · \(repoCount) projects after merge"))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer(minLength: 0)

                // 卡片区右上角：排序 + 显示方式
                CardAreaControls()
            }

            if !authors.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        authorChip(login: nil, title: L("全部", "All"))

                        ForEach(authors.prefix(40), id: \.self) { login in
                            authorChip(login: login, title: login)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private func authorChip(login: String?, title: String) -> some View {
        let isSelected = (selectedAuthor == login)

        return Button {
            onSelectAuthor(login)
        } label: {
            HStack(spacing: 6) {
                if let login {
                    AsyncImage(url: URL(string: "https://github.com/\(login).png?size=64")) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Circle().fill(Color.white.opacity(0.12))
                        }
                    }
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 10))
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.65))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}
