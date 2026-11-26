#!/usr/bin/env bash
set -Eeuo pipefail

# Infinity quick installer for iPhone, iPad, and macOS.
# The iOS/iPadOS paths intentionally use MobileBuildMCP so device discovery,
# signing, installation, and launch use the same workflow as Xcode.

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PROJECT_PATH="${PROJECT_PATH:-$PROJECT_DIR/Infinity.xcodeproj}"
SCHEME="${SCHEME:-Infinity}"
CONFIGURATION="${CONFIGURATION:-Debug}"
IPHONE_NAME="${IPHONE_NAME:-御坂美琴的iPhone 17 Pro}"
IPAD_NAME="${IPAD_NAME:-御坂美琴的iPad Pro 2021}"
IOS_DERIVED_DATA="${IOS_DERIVED_DATA:-/tmp/InfinityDeviceDerivedData}"
MAC_DERIVED_DATA="${MAC_DERIVED_DATA:-/tmp/InfinityMacDerivedData}"
APP_NAME="Infinity.app"

usage() {
  cat <<USAGE
用法：$(basename "$0") {iphone|ipad|mac}

  iphone    编译、安装并启动到 ${IPHONE_NAME}
  ipad      编译、安装并启动到 ${IPAD_NAME}
  mac       编译、安装并启动到本机 /Applications

可选环境变量：
  PROJECT_DIR=/path/to/Infinity
  IPHONE_NAME='设备名称'  IPAD_NAME='设备名称'
  CONFIGURATION=Debug|Release

示例：
  ./install.sh iphone
  IPAD_NAME='我的 iPad' ./install.sh ipad
  CONFIGURATION=Release ./install.sh mac
USAGE
}

log() { printf '\n==> %s\n' "$*"; }
fail() { printf '错误：%s\n' "$*" >&2; exit 1; }

[[ $# -eq 1 ]] || { usage >&2; exit 2; }
case "$1" in
  iphone) TARGET_NAME="$IPHONE_NAME"; PLATFORM="iOS" ;;
  ipad) TARGET_NAME="$IPAD_NAME"; PLATFORM="iPadOS" ;;
  mac) PLATFORM="macOS" ;;
  -h|--help|help) usage; exit 0 ;;
  *) usage >&2; fail "未知目标：$1" ;;
esac

command -v mobilebuildmcp >/dev/null || fail "找不到 mobilebuildmcp。请先安装 MobileBuildMCP。"
[[ -d "$PROJECT_DIR" ]] || fail "项目目录不存在：$PROJECT_DIR"
[[ -d "$PROJECT_PATH" ]] || fail "Xcode 项目不存在：$PROJECT_PATH"
cd "$PROJECT_DIR"

if [[ "$PLATFORM" == "iOS" || "$PLATFORM" == "iPadOS" ]]; then
  command -v jq >/dev/null || fail "找不到 jq，无法解析 MobileBuildMCP 的设备列表。"

  log "查找设备：$TARGET_NAME"
  DEVICES_JSON=$(mobilebuildmcp device list --output json)
  DEVICE_ID=$(printf '%s\n' "$DEVICES_JSON" | jq -r --arg name "$TARGET_NAME" \
    '.data.devices[] | select(.name == $name and .platform == "'"$PLATFORM"'" and .isAvailable == true) | .deviceId' | head -n 1)
  [[ -n "$DEVICE_ID" && "$DEVICE_ID" != "null" ]] || fail "未发现可用的${PLATFORM}设备：$TARGET_NAME。请确认设备已连接、解锁并启用开发者模式。"

  log "使用设备：$TARGET_NAME ($DEVICE_ID)"
  mobilebuildmcp device build-and-run \
    --project-path "$PROJECT_PATH" \
    --scheme "$SCHEME" \
    --device-id "$DEVICE_ID" \
    --configuration "$CONFIGURATION" \
    --derived-data-path "$IOS_DERIVED_DATA" \
    --prefer-xcodebuild true
  log "安装并启动完成：$TARGET_NAME"
else
  log "编译原生 macOS App"
  mobilebuildmcp macos build \
    --project-path "$PROJECT_PATH" \
    --scheme "$SCHEME" \
    --configuration "$CONFIGURATION" \
    --derived-data-path "$MAC_DERIVED_DATA" \
    --prefer-xcodebuild true

  APP_PATH="$MAC_DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME"
  [[ -d "$APP_PATH" ]] || fail "编译成功，但找不到 App：$APP_PATH"
  DESTINATION="/Applications/$APP_NAME"
  log "安装到：$DESTINATION"
  ditto "$APP_PATH" "$DESTINATION" || fail "安装失败。请检查 /Applications 写入权限。"
  open "$DESTINATION"
  log "安装并启动完成：$DESTINATION"
fi
