#!/bin/bash
# 跨平台编译 Caddy 脚本
# 包含 forwardproxy naive 插件

set -e

VERSION="${1:-$(date +%Y%m%d)}"
OUTPUT_DIR="dist"
REPO="github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive"

# 清理并创建输出目录
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 定义目标平台
PLATFORMS=(
    "linux/amd64"
    "linux/arm64"
    "linux/arm"
    "darwin/amd64"
    "darwin/arm64"
    "windows/amd64"
    "windows/arm64"
)

echo "开始编译 Caddy (版本: $VERSION)"
echo "插件: $REPO"
echo "========================================"

for PLATFORM in "${PLATFORMS[@]}"; do
    IFS='/' read -r GOOS GOARCH <<< "$PLATFORM"

    OUTPUT_NAME="caddy"
    if [ "$GOOS" = "windows" ]; then
        OUTPUT_NAME="caddy.exe"
    fi

    # 添加平台后缀
    OUTPUT_FILE="${OUTPUT_DIR}/caddy-${GOOS}-${GOARCH}"
    [ "$GOOS" = "windows" ] && OUTPUT_FILE="${OUTPUT_FILE}.exe"

    echo "编译: $GOOS/$GOARCH"

    CGO_ENABLED=0 GOOS="$GOOS" GOARCH="$GOARCH" \
        xcaddy build --with "$REPO" --output "$OUTPUT_FILE"

    echo "  -> $OUTPUT_FILE"
done

echo "========================================"
echo "编译完成！输出目录: $OUTPUT_DIR"
echo ""

# 显示文件大小
echo "文件列表:"
ls -lh "$OUTPUT_DIR"