import SwiftUI

/// 左侧图标栏。
/// 职责边界（与顶栏不重叠）：
///   左栏 = 「看哪一屏」（首页 / 收藏）
///   顶栏 = 「卡片从哪来」（发现 / 关注 / 探索）
/// 参考图里 Explore 同时出现在左栏和顶栏，属于导航冗余，这里没有照抄。
struct SidebarView: View {
    let pane: SidebarPane
    let savedCount: Int
    var onSelect: (SidebarPane) -> Void
    var onOpenSettings: () -> Void

    @AppStorage("app_language") private var appLanguage: String = AppLanguage.system.rawValue

    var body: some View {
        VStack(spacing: 6) {
            ForEach(SidebarPane.allCases) { item in
                paneButton(item)
            }

            Spacer(minLength: 12)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 14)

            settingsButton
        }
        .padding(.vertical, 14)
        .frame(width: 78)
        .background(Color.white.opacity(0.02))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }

    private func paneButton(_ item: SidebarPane) -> some View {
        let isSelected = pane == item

        return Button {
            onSelect(item)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .semibold))

                    // 收藏数量小角标
                    if item == .saved, savedCount > 0 {
                        Text("\(savedCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.cyan)
                            .clipShape(Capsule())
                            .offset(x: 12, y: -6)
                    }
                }
                .frame(height: 20)

                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .cyan : .white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cyan.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .help(item.title)
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            VStack(spacing: 4) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(height: 20)
                Text(L("设置", "Settings"))
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .foregroundColor(.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .help(L("控制台 / 设置", "Console / Settings"))
    }
}
