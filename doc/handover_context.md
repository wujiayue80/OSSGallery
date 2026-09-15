# OSS Gallery - 项目开发上下文与交接文档

## 1. 项目概述 (Project Overview)
**OSS Gallery** 是一款为 macOS 原生打造的 GitHub 开源项目探索工具。其核心目的是通过高度视觉化、现代化的“画廊”界面（参考了 Dribbble 上的现代 Dashboard 与 Neon/Glassmorphism 风格），帮助开发者以沉浸式的方式发现、浏览和管理高质量的 GitHub 仓库。

## 2. 技术栈 (Tech Stack)
*   **开发语言**: Swift
*   **UI 框架**: SwiftUI (要求 macOS 14.0+)
*   **架构模式**: MVVM (Model-View-ViewModel)
*   **项目组织形式**: Swift Package Manager (Executable 模式)。没有传统的 `.xcodeproj` 文件，通过双击 `Package.swift` 在 Xcode 中打开和运行。
*   **数据持久化**: `@AppStorage` (UserDefaults) 用于存储用户配置。
*   **网络层**: 原生 `URLSession` 直连 GitHub REST API。

## 3. 核心设计决策 (Design Decisions)
*   **视觉风格**: 强制暗黑模式 (Dark Mode)，大量使用 `.ultraThinMaterial` 毛玻璃材质，卡片带有强烈的青色发光描边、阴影以及基于鼠标悬浮的 3D 旋转特效。
*   **去文本化展示**: 放弃枯燥的文字列表，转而拼接 `https://opengraph.githubassets.com/1/{owner}/{repo}` 抓取 GitHub 自动生成的 Social Preview 图片作为卡片封面，实现极富冲击力的画廊效果。
*   **无服务器架构**: 纯客户端直连 GitHub API，无自建后端服务。
*   **平滑的鉴权降级**: 默认使用 GitHub 匿名接口（每小时 60 次限制），跑通 MVP。用户可在设置中配置 Personal Access Token (PAT) 解锁至每小时 5000 次限制。

## 4. 目录结构与核心组件 (Directory Structure)
整个工程位于 `Sources/OSSGallery/` 目录下：

*   **`OSSGallery.swift`**: 程序的 `@main` 入口点。
*   **`Models/`**
    *   `GitHubRepo.swift`: 映射 GitHub API 的项目数据模型。
    *   `SearchCategory.swift`: 搜索标签/分类的数据模型。
*   **`Services/`**
    *   `GitHubAPI.swift`: 封装对 `api.github.com/search/repositories` 的网络请求。
    *   `ConfigManager.swift`: 单例，管理用户的 API Key 和动态搜索分类规则的本地存取。
*   **`ViewModels/`**
    *   `GalleryViewModel.swift`: 负责发起搜索请求、维护数据列表和 Spotlight 推荐位状态。
*   **`Views/`**
    *   `ContentView.swift`: 主框架布局。
    *   `HeroSectionView.swift`: 顶部仪表盘与带有呼吸灯特效的焦点项目推荐区。
    *   `FilterBarView.swift`: 动态读取 `ConfigManager` 生成的横向滚动分类“药丸”标签。
    *   `ProjectGridView.swift` & `ProjectCardView.swift`: 瀑布流网格及单体卡片（负责处理图片拉取、徽章渲染与 3D Hover 动效）。
    *   `ProjectDetailSheet.swift`: 点击卡片后弹出的原生模态框，展示详细信息及跳转链接。
    *   `SettingsView.swift`: 配置 API Token 与自定义分类规则的控制台面板。

## 5. 当前状态与下一步开发建议 (Next Steps)
目前 **MVP v1.0 版本已经完成**，包含了基础的网络通信、数据持久化和所有的炫酷视觉交互组件。

接手的 Agent 需要注意以下优化点与扩展方向：
1.  **真实的“下载量”指标**: 目前卡片上的热度依靠 Stars 和 Forks 支撑。若需实现用户最初要求的“按下载量排名”，需要针对具体项目调用 GitHub Releases API 遍历求和 `download_count`（注意这极易触发 API 限流，建议采用懒加载或后台低优先级队列）。
2.  **详情页 Markdown 渲染**: 当前 `ProjectDetailSheet` 仅展示简略描述。可引入如 `MarkdownUI` 等三方库，渲染项目的 `README.md`，实现极致的本地沉浸阅读。
3.  **UI 响应式优化**: 虽然解除了主窗口的大小限制，但在极端缩放尺寸下，`HeroSectionView` 的局部排版可能需要进一步的自适应调整 (`ViewThatFits` 或 `GeometryReader`)。
4.  **图片缓存机制**: 频繁切换分类会导致重新请求大量的 OpenGraph 图片。建议在网络层或通过三方库 (如 Nuke / SDWebImageSwiftUI) 加入强大的本地图片缓存机制。
