<#
  海信 VIDAA_TV (MT9632 / Android 9) 一键恢复脚本 —— Windows PowerShell 版
  用途：电视恢复出厂设置后，把去膨胀设置、自制桌面、常用应用一次性装回去。

  用法（在仓库根目录打开 PowerShell）：
      powershell -ExecutionPolicy Bypass -File .\restore.ps1
      powershell -ExecutionPolicy Bypass -File .\restore.ps1 -TvIp 192.168.1.50
      powershell -ExecutionPolicy Bypass -File .\restore.ps1 -SkipApps      # 只重做去膨胀
      powershell -ExecutionPolicy Bypass -File .\restore.ps1 -SkipDebloat   # 只装应用和桌面
      powershell -ExecutionPolicy Bypass -File .\restore.ps1 -DryRun        # 只体检，不改动电视

  前提：电视已恢复出厂设置并重新打开了「开发者选项 > USB 调试 / 网络调试」，电视与电脑在同一局域网。
  本脚本只做三件事：装 APK、按清单禁用厂商包、把自制桌面设为默认 Home。全部可逆。
#>

param(
    [string]$TvIp = "",
    [switch]$SkipApps,
    [switch]$SkipDebloat,
    [switch]$DryRun
)

# 中文输出：Windows PowerShell 5.1 的控制台默认代码页是 936，不切到 UTF-8 会显示乱码。
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { [Console]::InputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { chcp 65001 > $null } catch { }

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ---------- 找到 adb ----------
# 顺序：仓库自带 platform-tools > 系统 PATH > 自动下载官方 platform-tools
function Resolve-Adb {
    $local = Join-Path $Root "platform-tools\adb.exe"
    if (Test-Path $local) { return $local }

    $found = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }

    Write-Host "[信息] 本机没有找到 adb。" -ForegroundColor Yellow
    Write-Host "       可以从 Google 官方下载 platform-tools（约 6 MB）：" -ForegroundColor Yellow
    Write-Host "       https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -ForegroundColor DarkGray
    $ans = Read-Host "现在自动下载并解压到 .\platform-tools 吗？(Y/n)"
    if ($ans -match '^[nN]') {
        Write-Host "[错误] 没有 adb，无法继续。" -ForegroundColor Red
        exit 1
    }

    $zip = Join-Path $env:TEMP "platform-tools-latest-windows.zip"
    $unz = Join-Path $env:TEMP "platform-tools-unzip"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "  下载中 ..." -NoNewline
        Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zip -UseBasicParsing
        Write-Host " 完成" -ForegroundColor Green
        if (Test-Path $unz) { Remove-Item $unz -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $unz -Force
        $src = Join-Path $unz "platform-tools"
        $dst = Join-Path $Root "platform-tools"
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        Move-Item $src $dst
        Write-Host "  已解压到 $dst" -ForegroundColor Green
    } catch {
        Write-Host "[错误] 自动下载失败：$($_.Exception.Message)" -ForegroundColor Red
        Write-Host "       请手动下载解压到 .\platform-tools 后重跑。" -ForegroundColor Red
        exit 1
    } finally {
        if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $unz) { Remove-Item $unz -Recurse -Force -ErrorAction SilentlyContinue }
    }
    return (Join-Path $Root "platform-tools\adb.exe")
}

$Adb = Resolve-Adb
if (-not (Test-Path $Adb)) {
    Write-Host "[错误] 找不到 adb。请保留 platform-tools 文件夹，或自行安装 Android platform-tools。" -ForegroundColor Red
    exit 1
}
Write-Host "[信息] adb = $Adb"
if ($DryRun) { Write-Host "[信息] DryRun 模式：只体检，不做任何改动" -ForegroundColor Yellow }

# ---------- 确认电视 IP ----------
if ([string]::IsNullOrWhiteSpace($TvIp)) {
    Write-Host ""
    Write-Host "请输入电视的 IP（电视上：设置 > 网络 > 网络信息）" -ForegroundColor Cyan
    $TvIp = Read-Host "电视 IP"
}
$TvIp = $TvIp.Trim()
if ($TvIp -notmatch ':') { $Serial = "$TvIp`:5555" } else { $Serial = $TvIp }

# ---------- 连接并等待授权 ----------
Write-Host ""
Write-Host "[步骤 1/5] 连接电视 $Serial ..." -ForegroundColor Cyan
& $Adb start-server 2>&1 | Out-Null
& $Adb connect $Serial 2>&1 | Out-Null

function Get-DeviceState {
    $out = & $Adb -s $Serial get-state 2>&1
    if ($out -match 'device') { return "device" }
    $raw = (& $Adb devices 2>&1) -join "`n"
    if ($raw -match [regex]::Escape($Serial) + '\s+unauthorized') { return "unauthorized" }
    return "offline"
}

$state = ""
for ($i = 1; $i -le 40; $i++) {
    $state = Get-DeviceState
    if ($state -eq "device") { break }
    if ($state -eq "unauthorized") {
        Write-Host "  电视上正在显示「允许 USB 调试吗？」，请用遥控器点【允许】..." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 3
    & $Adb connect $Serial 2>&1 | Out-Null
}

if ($state -ne "device") {
    Write-Host "[失败] 连不上电视（状态：$state）。" -ForegroundColor Red
    Write-Host "  请检查：电视是否开机、IP 是否正确、开发者选项里的 USB 调试/网络调试是否打开。" -ForegroundColor Red
    Write-Host "  也可以先手动执行： $Adb connect $Serial" -ForegroundColor Red
    exit 1
}
Write-Host "  已连接。" -ForegroundColor Green

$model = (& $Adb -s $Serial shell getprop ro.product.model 2>&1) -join ""
Write-Host "  设备：$($model.Trim())"

# ---------- 已装包清单（用于跳过不存在的包） ----------
function Get-InstalledPackages {
    $set = @{}
    foreach ($line in (& $Adb -s $Serial shell pm list packages 2>&1)) {
        $t = ($line -replace "`r", "").Trim()
        if ($t -like "package:*") { $set[$t.Substring(8)] = $true }
    }
    return $set
}

# ---------- 第 2 步：安装 APK ----------
if (-not $SkipApps) {
    Write-Host ""
    Write-Host "[步骤 2/5] 安装应用 ..." -ForegroundColor Cyan
    $apkDir = Join-Path $Root "apks"
    $launcherApk = Join-Path $Root "launcher\tvhome-launcher.apk"

    $files = @()
    if (Test-Path $apkDir) { $files += Get-ChildItem $apkDir -Filter *.apk | Sort-Object Name }

    if ($files.Count -eq 0) {
        Write-Host "  [提示] apks\ 里没有 APK。第三方应用的 APK 因为体积较大没有放进仓库，" -ForegroundColor Yellow
        Write-Host "         请到仓库的 Releases 页面下载 apks.zip 并解压到 apks\ 后再跑一次。" -ForegroundColor Yellow
    }

    foreach ($f in $files) {
        if ($DryRun) { Write-Host ("  [DryRun] 将安装 {0}" -f $f.Name); continue }
        Write-Host ("  安装 {0} ..." -f $f.Name) -NoNewline
        $o = (& $Adb -s $Serial install -r -d $f.FullName 2>&1) -join " "
        if ($o -match 'Success') {
            Write-Host " 成功" -ForegroundColor Green
        } elseif ($o -match 'INSTALL_FAILED_ALREADY_EXISTS') {
            Write-Host " 已存在，跳过" -ForegroundColor Yellow
        } else {
            Write-Host " 失败：$($o.Trim())" -ForegroundColor Red
        }
    }

    if (Test-Path $launcherApk) {
        if ($DryRun) {
            Write-Host "  [DryRun] 将安装自制桌面"
        } else {
            Write-Host "  安装自制桌面 ..." -NoNewline
            $o = (& $Adb -s $Serial install -r $launcherApk 2>&1) -join " "
            if ($o -match 'Success') {
                Write-Host " 成功" -ForegroundColor Green
            } elseif ($o -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
                Write-Host " 签名不一致（旧版残留），先卸载再装" -ForegroundColor Yellow
                & $Adb -s $Serial uninstall com.gathin.tvhome 2>&1 | Out-Null
                $o = (& $Adb -s $Serial install -r $launcherApk 2>&1) -join " "
                if ($o -match 'Success') { Write-Host "  重装成功" -ForegroundColor Green }
                else { Write-Host "  重装失败：$($o.Trim())" -ForegroundColor Red }
            } else {
                Write-Host " 失败：$($o.Trim())" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  [跳过] 没有找到桌面 APK：$launcherApk" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "[步骤 2/5] 已按参数跳过安装。" -ForegroundColor DarkGray
}

# ---------- 第 3 步：去膨胀（按清单禁用） ----------
# 绝不触摸这些核心包：禁掉后电视可能无法开机或无法操作。
$ProtectedExact = @(
    "android",
    "com.android.systemui",
    "com.android.shell",
    "com.android.phone",
    "com.android.settings",
    "com.android.tv.settings",
    "com.android.permissioncontroller",
    "com.google.android.permissioncontroller",
    "com.android.packageinstaller",
    "com.google.android.packageinstaller",
    "com.android.ext.services",
    "com.android.ext.shared",
    "com.google.android.ext.services",
    "com.google.android.ext.shared",
    "com.android.modulemetadata",
    "com.google.android.modulemetadata",
    "com.gathin.tvhome"
)

function Test-Protected([string]$pkg) {
    if ($ProtectedExact -contains $pkg) { return $true }
    if ($pkg -match '^com\.(android|google\.android)\.providers\.') { return $true }
    if ($pkg -match '^com\.google\.android\.overlay\.modules') { return $true }
    return $false
}

$disableList = Join-Path $Root "state\packages_disabled.txt"

if ((-not $SkipDebloat) -and (Test-Path $disableList)) {
    Write-Host ""
    Write-Host "[步骤 3/5] 按清单禁用厂商包 ..." -ForegroundColor Cyan
    $installed = Get-InstalledPackages
    $targets = Get-Content $disableList | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and -not $_.StartsWith("#") }

    $ok = 0; $skipped = 0; $failed = 0
    foreach ($pkg in $targets) {
        if (Test-Protected $pkg) {
            Write-Host ("  [保护] {0} 属于系统核心，跳过" -f $pkg) -ForegroundColor Yellow
            $skipped++
            continue
        }
        if (-not $installed.ContainsKey($pkg)) {
            $skipped++
            continue
        }
        if ($DryRun) {
            Write-Host ("  [DryRun] 将禁用 {0}" -f $pkg)
            $ok++
            continue
        }
        # 一次 shell 只发一条 pm 命令：链式命令会在第一条后静默中断。
        $o = (& $Adb -s $Serial shell "pm disable-user --user 0 $pkg" 2>&1) -join " "
        if ($o -match 'disabled-user' -or $o -match 'new state') { $ok++ }
        else { $failed++; Write-Host ("  [失败] {0} -> {1}" -f $pkg, $o.Trim()) -ForegroundColor Red }
    }
    Write-Host ("  已禁用 {0} 个，跳过 {1} 个（不存在或受保护），失败 {2} 个" -f $ok, $skipped, $failed) -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[步骤 3/5] 已按参数跳过去膨胀。" -ForegroundColor DarkGray
}

# ---------- 第 4 步：自制桌面设为默认 Home ----------
Write-Host ""
Write-Host "[步骤 4/5] 把自制桌面设为默认 Home ..." -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  [DryRun] 将执行 set-home-activity com.gathin.tvhome/...MainActivity"
} else {
    $installed = Get-InstalledPackages
    if ($installed.ContainsKey("com.gathin.tvhome")) {
        & $Adb -s $Serial shell "cmd package set-home-activity com.gathin.tvhome/com.gathin.tvhome.MainActivity" 2>&1 | Out-Null
        # 有的直播类应用（例如 com.zb.test）在安装或后台恢复后会自己抢回前台，
        # 所以按 Home 多试几次再判定；判据用 mResumedActivity，窗口名不可靠。
        $resumed = ""
        $homeOk = $false
        for ($k = 1; $k -le 3; $k++) {
            & $Adb -s $Serial shell "input keyevent KEYCODE_HOME" 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            $resumed = (& $Adb -s $Serial shell "dumpsys activity activities | grep mResumedActivity" 2>&1) -join " "
            if ($resumed -match "com\.gathin\.tvhome") { $homeOk = $true; break }
        }
        if ($homeOk) {
            Write-Host "  桌面已接管 Home。" -ForegroundColor Green
        } else {
            $focus = (& $Adb -s $Serial shell "dumpsys window | grep mCurrentFocus" 2>&1) -join " "
            $defHome = (& $Adb -s $Serial shell "cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME" 2>&1) -join " "
            Write-Host "  [注意] 按 Home 后前台还不是自制桌面：" -ForegroundColor Yellow
            Write-Host "    resumed: $($resumed.Trim())" -ForegroundColor Yellow
            Write-Host "    focus  : $($focus.Trim())" -ForegroundColor Yellow
            if ($defHome -match "com\.gathin\.tvhome") {
                Write-Host "  但默认 Home 已正确指向自制桌面，多数是有应用在抢前台。" -ForegroundColor Yellow
                Write-Host "  再按一次 Home 即可；若某个应用反复抢回，先结束它：" -ForegroundColor Yellow
                Write-Host "    & .\platform-tools\adb.exe -s $Serial shell `"am force-stop <包名>`"" -ForegroundColor Yellow
            } else {
                Write-Host "  默认 Home 没有指向自制桌面，见 docs/faq.md 的「Home 键没接管」一节。" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  [跳过] 自制桌面未安装。" -ForegroundColor Yellow
    }
}

# ---------- 第 5 步：系统设置 ----------
Write-Host ""
Write-Host "[步骤 5/5] 恢复系统设置 ..." -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  [DryRun] 将关闭系统屏保（screensaver_enabled=0）"
} else {
    & $Adb -s $Serial shell "settings put secure screensaver_enabled 0" 2>&1 | Out-Null
    $ss = (& $Adb -s $Serial shell "settings get secure screensaver_enabled" 2>&1) -join ""
    Write-Host "  系统屏保已关闭（screensaver_enabled=$($ss.Trim())）"
}

# ---------- 汇总 ----------
Write-Host ""
Write-Host "================ 恢复完成 ================" -ForegroundColor Cyan
$third = (& $Adb -s $Serial shell "pm list packages -3" 2>&1 | Measure-Object -Line).Lines
$disabled = (& $Adb -s $Serial shell "pm list packages -d" 2>&1 | Measure-Object -Line).Lines
Write-Host "  第三方应用：$third 个"
Write-Host "  当前禁用包：$disabled 个"
Write-Host ""
Write-Host "  还需你自己做的事：" -ForegroundColor Yellow
Write-Host "   1. 电视设置里重新登录各应用（绿联云、云视听小电视、TVBox 的接口地址）"
Write-Host "   2. 用遥控器逐个按一遍 Home、信号源、音量键，确认正常"
Write-Host "   3. 全部正常后，关掉电视的 USB 调试 / 网络调试"
Write-Host ""
