import Foundation
import SwiftUI

/// 轻量国际化：直接在调用点给出中英两个版本，避免维护 .strings 表。
/// 语言来源：ConfigManager.shared.appLanguage（system / zh / en）。
///
/// 用法：Text(L("暂无项目描述", "No description provided."))
/// 视图里声明 `@AppStorage("app_language") private var appLanguage: String = ...`
/// 以便语言切换时自动刷新文案。
func L(_ zh: String, _ en: String) -> String {
    ConfigManager.shared.appLanguage.effectiveCode == "zh" ? zh : en
}
