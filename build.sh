#!/bin/bash
# 跨平台编译 Caddy 脚本
# 包含 forwardproxy naive 插件

set -euo pipefail

VERSION="${1:-$(date +%Y%m%d)}"
OUTPUT_DIR="dist"
FORWARDPROXY_REF="${FORWARDPROXY_REF:-github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive}"

if ! command -v xcaddy &>/dev/null; then
    echo "未找到 xcaddy，请先执行：go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest" >&2
    exit 1
fi

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
)

echo "开始编译 Caddy (版本: $VERSION)"
echo "插件: $FORWARDPROXY_REF"
echo "========================================"

for PLATFORM in "${PLATFORMS[@]}"; do
    IFS='/' read -r GOOS GOARCH <<< "$PLATFORM"

    OUTPUT_FILE="${OUTPUT_DIR}/caddy-${GOOS}-${GOARCH}"

    echo "编译: $GOOS/$GOARCH"

    if [ "$GOARCH" = "arm" ]; then
        CGO_ENABLED=0 GOOS="$GOOS" GOARCH="$GOARCH" GOARM=7 \
            xcaddy build --with "$FORWARDPROXY_REF" --output "$OUTPUT_FILE"
    else
        CGO_ENABLED=0 GOOS="$GOOS" GOARCH="$GOARCH" \
            xcaddy build --with "$FORWARDPROXY_REF" --output "$OUTPUT_FILE"
    fi

    echo "  -> $OUTPUT_FILE"
done

echo "========================================"
echo "编译完成！输出目录: $OUTPUT_DIR"
echo ""

if command -v sha256sum &>/dev/null; then
    (
        cd "$OUTPUT_DIR"
        sha256sum caddy-* > checksums.txt
    )
    echo "校验文件: $OUTPUT_DIR/checksums.txt"
elif command -v shasum &>/dev/null; then
    (
        cd "$OUTPUT_DIR"
        shasum -a 256 caddy-* > checksums.txt
    )
    echo "校验文件: $OUTPUT_DIR/checksums.txt"
else
    echo "未找到 sha256sum/shasum，跳过生成校验文件"
fi

# 显示文件大小
echo "文件列表:"
ls -lh "$OUTPUT_DIR"
