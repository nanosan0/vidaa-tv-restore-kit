#!/usr/bin/env bash
# 海信 VIDAA_TV (MT9632 / Android 9) 一键恢复脚本 —— macOS / Linux / Git Bash 版
#
# 用法：
#   ./restore.sh                    # 交互式输入电视 IP
#   ./restore.sh 192.168.1.50       # 直接指定 IP
#   SKIP_APPS=1 ./restore.sh <ip>   # 只重做去膨胀
#   SKIP_DEBLOAT=1 ./restore.sh <ip># 只装应用和桌面
#   DRY_RUN=1 ./restore.sh <ip>     # 只体检，不改动电视
#
# 前提：电视已恢复出厂设置并重新打开「开发者选项 > USB 调试 / 网络调试」，与电脑同一局域网。
set -u

DRY="${DRY_RUN:-0}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- 找到 adb ----------
ADB="$ROOT/platform-tools/adb.exe"          # 打包进来的 Windows 版
if [ ! -f "$ADB" ]; then ADB="$ROOT/platform-tools/adb"; fi
if [ ! -x "$ADB" ]; then
  if command -v adb >/dev/null 2>&1; then ADB="$(command -v adb)"; fi
fi
if [ ! -x "$ADB" ]; then
  echo "[错误] 找不到 adb。任选一种方式装上："
  echo "        Debian/Ubuntu: sudo apt install android-tools-adb"
  echo "        macOS:         brew install android-platform-tools"
  echo "        通用:          下载 https://dl.google.com/android/repository/platform-tools-latest-<系统>.zip"
  exit 1
fi
echo "[信息] adb = $ADB"
[ "$DRY" = "1" ] && echo "[信息] DRY_RUN 模式：只体检，不做任何改动"

# ---------- 电视 IP ----------
TV_IP="${1:-}"
if [ -z "$TV_IP" ]; then
  printf '请输入电视的 IP（电视上：设置 > 网络 > 网络信息）\n电视 IP: '
  read -r TV_IP
fi
TV_IP="$(echo "$TV_IP" | tr -d '[:space:]')"
case "$TV_IP" in
  *:*) SERIAL="$TV_IP" ;;
  *)   SERIAL="$TV_IP:5555" ;;
esac

# ---------- 连接并等待授权 ----------
echo
echo "[步骤 1/5] 连接电视 $SERIAL ..."
"$ADB" start-server >/dev/null 2>&1
"$ADB" connect "$SERIAL" >/dev/null 2>&1

STATE=""
for i in $(seq 1 40); do
  OUT="$("$ADB" -s "$SERIAL" get-state 2>&1)"
  if echo "$OUT" | grep -q '^device'; then STATE="device"; break; fi
  if "$ADB" devices 2>/dev/null | grep -q "$SERIAL[[:space:]]*unauthorized"; then
    STATE="unauthorized"
    echo "  电视上正在显示「允许 USB 调试吗？」，请用遥控器点【允许】..."
  fi
  sleep 3
  "$ADB" connect "$SERIAL" >/dev/null 2>&1
done

if [ "$STATE" != "device" ]; then
  echo "[失败] 连不上电视（状态：${STATE:-offline}）。"
  echo "  请检查：电视是否开机、IP 是否正确、开发者选项里的 USB 调试/网络调试是否打开。"
  echo "  也可以先手动执行： $ADB connect $SERIAL"
  exit 1
fi
echo "  已连接。设备：$("$ADB" -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"

# ---------- 已装包清单 ----------
"$ADB" -s "$SERIAL" shell pm list packages 2>/dev/null | sed 's/^package://' | tr -d '\r' | sort > /tmp/_rkit_installed.txt

# ---------- 第 2 步：安装 APK ----------
if [ "${SKIP_APPS:-0}" != "1" ]; then
  echo
  echo "[步骤 2/5] 安装应用 ..."
  if ! ls "$ROOT"/apks/*.apk >/dev/null 2>&1; then
    if [ -z "${SKIP_APPS:-}" ]; then
      echo "  [提示] apks/ 里没有 APK。第三方应用的 APK 体积较大未入库，"
      echo "         请到仓库 Releases 页面下载 apks.zip 解压到 apks/ 后重跑。"
    fi
  fi
  for f in "$ROOT/apks"/*.apk; do
    [ -e "$f" ] || continue
    if [ "$DRY" = "1" ]; then echo "  [DRY_RUN] 将安装 $(basename "$f")"; continue; fi
    printf '  安装 %s ...' "$(basename "$f")"
    O="$("$ADB" -s "$SERIAL" install -r -d "$f" 2>&1)"
    if echo "$O" | grep -q 'Success'; then echo " 成功"
    elif echo "$O" | grep -q 'ALREADY_EXISTS'; then echo " 已存在，跳过"
    else echo " 失败：$(echo "$O" | tr '\n' ' ')"; fi
  done

  LAPK="$ROOT/launcher/tvhome-launcher.apk"
  if [ -f "$LAPK" ]; then
    if [ "$DRY" = "1" ]; then
      echo "  [DRY_RUN] 将安装自制桌面"
    else
    printf '  安装自制桌面 ...'
    O="$("$ADB" -s "$SERIAL" install -r "$LAPK" 2>&1)"
    if echo "$O" | grep -q 'Success'; then echo " 成功"
    elif echo "$O" | grep -q 'UPDATE_INCOMPATIBLE'; then
      echo " 签名不一致，先卸载再装"
      "$ADB" -s "$SERIAL" uninstall com.gathin.tvhome >/dev/null 2>&1
      O="$("$ADB" -s "$SERIAL" install -r "$LAPK" 2>&1)"
      if echo "$O" | grep -q 'Success'; then echo "  重装成功"; else echo "  重装失败：$(echo "$O" | tr '\n' ' ')"; fi
    else echo " 失败：$(echo "$O" | tr '\n' ' ')"; fi
    fi
  else
    echo "  [跳过] 没有找到桌面 APK：$LAPK"
  fi
else
  echo
  echo "[步骤 2/5] 已按参数跳过安装。"
fi

# ---------- 第 3 步：去膨胀 ----------
# 绝不触摸这些核心包：禁掉后电视可能无法开机或无法操作。
is_protected() {
  case "$1" in
    android|com.android.systemui|com.android.shell|com.android.phone|com.android.settings|com.android.tv.settings) return 0 ;;
    com.android.permissioncontroller|com.google.android.permissioncontroller) return 0 ;;
    com.android.packageinstaller|com.google.android.packageinstaller) return 0 ;;
    com.android.ext.services|com.android.ext.shared|com.google.android.ext.services|com.google.android.ext.shared) return 0 ;;
    com.android.modulemetadata|com.google.android.modulemetadata|com.gathin.tvhome) return 0 ;;
    com.android.providers.*|com.google.android.providers.*) return 0 ;;
    com.google.android.overlay.modules*) return 0 ;;
  esac
  return 1
}

LIST="$ROOT/state/packages_disabled.txt"
if [ "${SKIP_DEBLOAT:-0}" != "1" ] && [ -f "$LIST" ]; then
  echo
  echo "[步骤 3/5] 按清单禁用厂商包 ..."
  OK=0; SKIP=0; FAIL=0
  while IFS= read -r pkg; do
    pkg="$(echo "$pkg" | tr -d '\r' | sed 's/[[:space:]]//g')"
    [ -z "$pkg" ] && continue
    case "$pkg" in \#*) continue ;; esac
    if is_protected "$pkg"; then
      echo "  [保护] $pkg 属于系统核心，跳过"; SKIP=$((SKIP+1)); continue
    fi
    if ! grep -qx "$pkg" /tmp/_rkit_installed.txt; then
      SKIP=$((SKIP+1)); continue
    fi
    if [ "$DRY" = "1" ]; then echo "  [DRY_RUN] 将禁用 $pkg"; OK=$((OK+1)); continue; fi
    # 一次 shell 只发一条 pm 命令：链式命令会在第一条后静默中断。
    O="$("$ADB" -s "$SERIAL" shell "pm disable-user --user 0 $pkg" 2>&1)"
    if echo "$O" | grep -qE 'disabled-user|new state'; then OK=$((OK+1))
    else FAIL=$((FAIL+1)); echo "  [失败] $pkg -> $(echo "$O" | tr '\n' ' ')"; fi
  done < "$LIST"
  echo "  已禁用 $OK 个，跳过 $SKIP 个（不存在或受保护），失败 $FAIL 个"
else
  echo
  echo "[步骤 3/5] 已按参数跳过去膨胀。"
fi

# ---------- 第 4 步：自制桌面设为默认 Home ----------
echo
echo "[步骤 4/5] 把自制桌面设为默认 Home ..."
if [ "$DRY" = "1" ]; then
  echo "  [DRY_RUN] 将执行 set-home-activity com.gathin.tvhome/...MainActivity"
elif grep -qx "com.gathin.tvhome" /tmp/_rkit_installed.txt; then
  "$ADB" -s "$SERIAL" shell "cmd package set-home-activity com.gathin.tvhome/com.gathin.tvhome.MainActivity" >/dev/null 2>&1
  # 有的直播类应用（例如 com.zb.test）在安装或后台恢复后会自己抢回前台，
  # 所以按 Home 多试几次再判定；判据用 mResumedActivity，窗口名不可靠。
  HOME_OK=0
  RESUMED=""
  for k in 1 2 3; do
    "$ADB" -s "$SERIAL" shell "input keyevent KEYCODE_HOME" >/dev/null 2>&1
    sleep 2
    RESUMED="$("$ADB" -s "$SERIAL" shell "dumpsys activity activities | grep mResumedActivity" 2>&1 | tr -d '\r')"
    if echo "$RESUMED" | grep -q 'com.gathin.tvhome'; then HOME_OK=1; break; fi
  done

  if [ "$HOME_OK" = "1" ]; then
    echo "  桌面已接管 Home。"
  else
    FOCUS="$("$ADB" -s "$SERIAL" shell "dumpsys window | grep mCurrentFocus" 2>&1 | tr -d '\r')"
    DEFHOME="$("$ADB" -s "$SERIAL" shell "cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME" 2>&1 | tr -d '\r')"
    echo "  [注意] 按 Home 后前台还不是自制桌面："
    echo "    resumed: $RESUMED"
    echo "    focus  : $FOCUS"
    if echo "$DEFHOME" | grep -q 'com.gathin.tvhome'; then
      echo "  但默认 Home 已正确指向自制桌面，多数是有应用在抢前台。"
      echo "  再按一次 Home 即可；若某个应用反复抢回，先结束它："
      echo "    $ADB -s $SERIAL shell \"am force-stop <包名>\""
    else
      echo "  默认 Home 没有指向自制桌面，见 docs/faq.md 的「Home 键没接管」一节。"
    fi
  fi
else
  echo "  [跳过] 自制桌面未安装。"
fi

# ---------- 第 5 步：系统设置 ----------
echo
echo "[步骤 5/5] 恢复系统设置 ..."
if [ "$DRY" = "1" ]; then
  echo "  [DRY_RUN] 将关闭系统屏保（screensaver_enabled=0）"
else
  "$ADB" -s "$SERIAL" shell "settings put secure screensaver_enabled 0" >/dev/null 2>&1
  echo "  系统屏保已关闭（screensaver_enabled=$("$ADB" -s "$SERIAL" shell "settings get secure screensaver_enabled" | tr -d '\r')）"
fi

rm -f /tmp/_rkit_installed.txt

echo
echo "================ 恢复完成 ================"
echo "  第三方应用：$("$ADB" -s "$SERIAL" shell "pm list packages -3" 2>/dev/null | wc -l | tr -d ' ') 个"
echo "  当前禁用包：$("$ADB" -s "$SERIAL" shell "pm list packages -d" 2>/dev/null | wc -l | tr -d ' ') 个"
echo
echo "  还需你自己做的事："
echo "   1. 电视上重新登录各应用（绿联云、云视听小电视、TVBox 的接口地址）"
echo "   2. 用遥控器逐个按一遍 Home、信号源、音量键，确认正常"
echo "   3. 全部正常后，关掉电视的 USB 调试 / 网络调试"
echo
