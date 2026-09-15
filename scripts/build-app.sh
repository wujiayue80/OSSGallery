#!/bin/bash
#
# 把 SPM 编译产物组装成正规的 macOS .app 包。
#
# 为什么需要这一步（实测依据）：
#   本工程是 SPM 的 executable target。从 Xcode ⌘R 或终端直接运行，跑的是**裸二进制**，
#   没有 .app 包。实测对照结果：
#     · 裸二进制：应用拿不到前台焦点 → 键盘输入进不去、下拉菜单弹不开、
#       窗口边缘不显示缩放光标（光标形状只反映最上层窗口）
#     · 正规 .app 包（用 open 启动）：焦点正常，合成键盘输入可正常落入输入框
#   所以「键盘输入不了 / 菜单点不开 / 边缘不能缩放」这三件事是同一个后果，
#   根因是缺 .app 包。
#
# 注意 CFBundleIdentifier 特意设为 OSSGallery：
#   裸进程的 UserDefaults 域按进程名取，就是 "OSSGallery"。保持一致，
#   已有的 Token、窗口位置、语言等设置才能继续读到，无需重新配置。
#
# 用法：
#   ./scripts/build-app.sh            # release 构建
#   ./scripts/build-app.sh debug      # debug 构建
#   ./scripts/build-app.sh release run  # 构建后直接启动

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP="$ROOT/build/OSSGallery.app"
BIN="$ROOT/.build/$CONFIG/OSSGallery"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG" --disable-sandbox

if [ ! -f "$BIN" ]; then
    echo "找不到编译产物：$BIN" >&2
    exit 1
fi

echo "==> 组装 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/OSSGallery"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>OSSGallery</string>
    <key>CFBundleIdentifier</key><string>OSSGallery</string>
    <key>CFBundleName</key><string>OSS Gallery</string>
    <key>CFBundleDisplayName</key><string>OSS Gallery</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

echo "==> 临时签名（避免每次重建都被当作不同的应用）"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "   （签名跳过，不影响运行）"

echo "==> 完成：$APP"

if [ "${2:-}" = "run" ]; then
    echo "==> 启动"
    open "$APP"
fi
