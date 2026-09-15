import Foundation

/// 左侧图标栏的入口。**同时也是数据来源的切换器。**
///
/// 设计变更说明：原先顶栏有一排「发现 / 关注 / 探索」，左栏另有「首页 / 收藏」。
/// 但"发现"（算法混排）与"探索"（手动排序）在界面上**看不出任何区别**，
/// 属于概念重复；参考图的顶栏也没有这排标签（只有搜索 / 随机探索 / 控制台）。
/// 因此：
///   · 取消「探索」——它的行为（按分类浏览）已被「发现」覆盖；
///   · 「发现 / 关注」与「收藏」合并进左栏，顶栏只留 应用名 + 搜索 + 随机探索 + 设置。
enum SidebarPane: String, CaseIterable, Identifiable {
    case discover     // 发现：算法推荐流（以当前分类为候选池，客户端按综合分混排）
    case following    // 关注：读 GitHub 关注列表，拼 user: 并集后查询
    case saved        // 收藏：纯本地数据，不请求网络

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: return L("发现", "Discover")
        case .following: return L("关注", "Following")
        case .saved: return L("收藏", "Saved")
        }
    }

    var icon: String {
        switch self {
        case .discover: return "sparkles"
        case .following: return "person.2.fill"
        case .saved: return "bookmark.fill"
        }
    }

    /// 是否需要走网络。收藏是纯本地数据。
    var needsNetwork: Bool { self != .saved }

    /// 是否显示分类筛选栏。关注流是按作者聚合的，再按主题筛一层意义不大。
    var showsCategoryFilter: Bool { self == .discover }
}
