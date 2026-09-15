import SwiftUI

/// 卡片区的显示方式。
enum RepoViewStyle: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }

    var title: String {
        switch self {
        case .grid: return L("网格", "Grid")
        case .list: return L("列表", "List")
        }
    }
}

/// 排序（作用于接口取数）。只用于"发现 / 关注"这类要联网的卡片区。
struct SortControl: View {
    @ObservedObject var config = ConfigManager.shared

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))

            Picker("", selection: $config.sortOptionRaw) {
                Text(RepoSortOption.recommended.title).tag(RepoSortOption.recommended.rawValue)
                Text(RepoSortOption.stars.title).tag(RepoSortOption.stars.rawValue)
                Text(RepoSortOption.forks.title).tag(RepoSortOption.forks.rawValue)
                Text(RepoSortOption.updated.title).tag(RepoSortOption.updated.rawValue)
                Text(RepoSortOption.bestMatch.title).tag(RepoSortOption.bestMatch.rawValue)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .help(L("选「综合推荐」由算法混排；选其它则严格按所选排序。",
                   "\"Recommended\" is ranked by score; other options sort strictly as named."))
        }
    }
}

/// 网格 / 列表切换。
struct ViewStyleToggle: View {
    @AppStorage("view_style") private var viewStyle: String = RepoViewStyle.grid.rawValue

    var body: some View {
        HStack(spacing: 2) {
            ForEach(RepoViewStyle.allCases) { style in
                let isSelected = viewStyle == style.rawValue
                Button {
                    viewStyle = style.rawValue
                } label: {
                    Image(systemName: style.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                        .frame(width: 24, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.cyan.opacity(0.22) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.cyan.opacity(0.45) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(style.title)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

/// 卡片区右上角：排序 + 显示方式。
///
/// 放在卡片区而不是顶栏，因为它作用的对象就是下方这批卡片（Finder 也是这个位置）。
/// 发现页由筛选栏承载；关注页由关注头部承载；收藏页是纯本地数据，
/// 排序语义不同（按收藏时间 / 按星标），因此那里只用 `ViewStyleToggle`。
struct CardAreaControls: View {
    var body: some View {
        HStack(spacing: 8) {
            SortControl()
            ViewStyleToggle()
        }
    }
}
