import SwiftUI

/// 分类筛选栏。
/// 只负责「按主题筛选」，排序已上移到顶栏，这里不再放排序控件。
struct FilterBarView: View {
    @ObservedObject var config = ConfigManager.shared
    let selectedCategory: SearchCategory?
    let onSelect: (SearchCategory) -> Void
    var onOpenSettings: () -> Void

    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    var body: some View {
        HStack(spacing: 12) {
            // 参考图是一行铺满、不滚动的药丸。
            // 但分类数量可由用户自定义，数量多时一行放不下会溢出，
            // 因此用 ViewThatFits 做两态：优先单行铺满，放不下才退回横向滚动。
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    chipRow
                    Spacer(minLength: 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        chipRow
                    }
                }
            }

            // 卡片区右上角：排序 + 显示方式（网格 / 列表）
            CardAreaControls()
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var chipRow: some View {
        ForEach(config.categories) { category in
            let isSelected = selectedCategory?.id == category.id

            Button {
                onSelect(category)
            } label: {
                Text(category.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .cyan.opacity(0.5), radius: 8, x: 0, y: 2)
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                    }
                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
            }
            .buttonStyle(.plain)
        }

        // 添加分类（mac 原生风格按钮）
        Button(action: onOpenSettings) {
            Label(L("添加分类", "Add Category"), systemImage: "plus")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .fixedSize()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(L("添加 / 管理自定义分类", "Add / manage custom categories"))
    }
}
