#!/usr/bin/env bash
# Refresh README screenshots from a connected Boox.
# Captures the Today and Adherence tabs into docs/screenshots/.
# Safe no-op when no device is connected (so commits never break offline).
set -uo pipefail

ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
PKG="com.boox.dailytodo"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
mkdir -p "$OUT"

if [ ! -x "$ADB" ]; then
    echo "adb not found at $ADB — skipping screenshot refresh"
    exit 0
fi

SERIAL="$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
if [ -z "${SERIAL:-}" ]; then
    echo "No Boox connected — skipping screenshot refresh"
    exit 0
fi
echo "Capturing screenshots from device $SERIAL"

# Unfreeze (Boox may have frozen it) and bring to foreground.
"$ADB" -s "$SERIAL" shell pm enable "$PKG" >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell sleep 4

# Boox firmware prints "capture from screenshot!" to stdout, which corrupts
# `exec-out screencap`; capture to a file on the device and pull it instead.
cap() {
    "$ADB" -s "$SERIAL" shell screencap -p /sdcard/_cap.png >/dev/null 2>&1
    "$ADB" -s "$SERIAL" pull /sdcard/_cap.png "$1" >/dev/null 2>&1
    "$ADB" -s "$SERIAL" shell rm -f /sdcard/_cap.png >/dev/null 2>&1 || true
}

# Tab coordinates assume the Note X3 Plus portrait resolution (1404 x 1872).
"$ADB" -s "$SERIAL" shell input tap 350 160 >/dev/null 2>&1 || true   # Today tab
"$ADB" -s "$SERIAL" shell sleep 1
cap "$OUT/today.png"

"$ADB" -s "$SERIAL" shell input tap 1050 160 >/dev/null 2>&1 || true  # Adherence tab
"$ADB" -s "$SERIAL" shell sleep 1
cap "$OUT/stats.png"

echo "Saved: $OUT/today.png, $OUT/stats.png"
