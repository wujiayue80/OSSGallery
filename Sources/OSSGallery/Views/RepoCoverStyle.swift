import SwiftUI

extension GitHubRepo {
    /// 封面底色：由仓库全名派生的**稳定**色相。
    ///
    /// 刻意不用 `hashValue` —— Swift 的哈希每个进程都会重新加盐，
    /// 用它会导至同一张卡片的颜色每次启动都不一样。
    var coverTint: Color {
        var hash: UInt64 = 5381
        for scalar in fullName.unicodeScalars {
            hash = (hash &* 33) &+ UInt64(scalar.value)
        }
        let hue = Double(hash % 360) / 360.0
        // 亮度 / 饱和度：参考图的色块比纯暗色明快，但暗黑主题下又不能太亮，折中取 0.58 / 0.42。
        return Color(hue: hue, saturation: 0.58, brightness: 0.42)
    }
}

/// 数字缩写。中文习惯用「万 / k」，英文用「M / k」。
enum RepoFormat {
    static func count(_ n: Int) -> String {
        let isZh = ConfigManager.shared.appLanguage.effectiveCode == "zh"
        if isZh {
            if n >= 10000 { return String(format: "%.1f万", Double(n) / 10000.0) }
            if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000.0) }
            return "\(n)"
        } else {
            if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000.0) }
            if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000.0) }
            return "\(n)"
        }
    }
}
