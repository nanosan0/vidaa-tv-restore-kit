# 常见问题

## 重启后停在聚好看，按 Home 回不来

**现象**：开机后 `dumpsys activity activities | grep mResumedActivity` 是
`com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity`，按 Home 键**画面没有任何变化**。

**根因**（2026-10-31 用 `logcat -b system` 定位，三层叠加）：

### 1. 海信在 AMS 里做了「开机首启白名单」，首屏被写死为聚好看

开机瞬间的系统日志（时钟还没同步，所以时间戳是 `01-01 08:00:15`）：

```
initAppWhiteList, read list from [/data/local/misc/app_start_when_boot_whitelist.txt]
initAppWhiteList, App first white list for booting: com.jamdeo.tv.vod
getHomes:com.jamdeo.tv.vod
START u0 {act=android.intent.action.MAIN cat=[android.intent.category.HOME] flg=0x10000100
          cmp=com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity} from uid 0
startProcessLocked, [com.jamdeo.tv.vod] is in app first white list, can start directly, currentPhase:600
```

`initAppWhiteList` / `getHomes:` 都不是 AOSP 原生日志，是海信加的。关键在 `getHomes:com.jamdeo.tv.vod` ——
开机时系统的 home 候选列表里**只有聚好看一个**，然后由 uid 0（system）用 HOME 意图把它拉起。

也就是说：`cmd package set-home-activity` 记下的用户偏好，在「开机首屏」这一步不参与竞争。
它只在开机之后重新解析 Home 时才生效。

### 2. 聚好看的 LauncherActivity 同时声明了 LAUNCHER 和 HOME

```
306c1aa com.jamdeo.tv.vod/com.ju.main.launcher.LauncherActivity filter 5929cce
  Action:    "android.intent.action.MAIN"
  Category:  "android.intent.category.DEFAULT"
  Category:  "android.intent.category.LAUNCHER"
  Category:  "android.intent.category.HOME"      ← 它本身就是合法桌面
```

所以它一被拉起就占据 home task，不是「普通应用跑到前台」，Home 键因此变成空操作。

### 3. 刚开机那几分钟，WMS 还在丢弃 HOME 键

```
PhoneWindowManager: Not starting activity because user setup is in progress:
  Intent { act=android.intent.action.MAIN cat=[android.intent.category.HOME] flg=0x10200000 }
```

`mUserSetupComplete` 尚未置 1 时，HOME 键被 WindowManager 直接吞掉。所以开机后那几分钟**按键完全无效**，
不是「按了但被聚好看吃掉」。

### 为什么 `am force-stop` 有效

结束当前占据 home task 的应用后，AMS 被迫**重新解析** Home，这次走正常路径，用户偏好生效：

```
START u0 {act=... cat=[android.intent.category.HOME] cmp=com.gathin.tvhome/.MainActivity} from uid 0
```

```bash
adb shell am force-stop com.jamdeo.tv.vod
```

只需这一条；后面再按 Home 才会进入自制桌面。

### 白名单文件能不能改掉

```bash
ls -ld /data/local/misc                      # drwxrwxrwx shell shell
ls -l  /data/local/misc/app_start_when_boot_whitelist.txt   # -rw------- system system 557
```

目录是 0777（shell 可写），但白名单文件本身 `system:system` + `0600`，**shell 读不出内容也改不了**。
唯一能做的是 `mv` 改名让它读不到 —— 但 AMS 大概率回落到编译进固件的默认名单（推测仍含聚好看），
未验证，会拿开机稳定性做赌注，不建议。

**能用 `pm disable-user` 一劳永逸吗**：不能。聚好看承载遥控器「信号源」键的 HDMI / AV / 直播面板
（见 [device-info.md](device-info.md)），禁掉信号源入口就没了。

### 结论

- 这是**固件行为**，`set-home-activity` 改不掉，不是安装脚本的 bug
- 每次开机后跑一次 `am force-stop com.jamdeo.tv.vod` 即可（零风险，实测有效）
- 开机抢占是竞态：`com.zb.test` 也会用 `AutoStartReceiver` 抢前台，但它不是 HOME 类应用，
  按一次 Home 就能回

## 想看某个应用是不是抢了前台

```bash
adb shell dumpsys activity activities | grep -E "mResumedActivity|mFocusedActivity"
adb shell dumpsys activity activities | grep -A2 "mHomeProcess"
```

`mHomeProcess` 是系统认定的「家」进程 —— 它如果不是 `com.gathin.tvhome`，说明 home task 被别的 HOME 应用占了，
用上面的 `am force-stop` 处理。

## 连不上电视


先按这个顺序排查，90% 是前两条：

1. **电视真的在开机状态**（不是待机 / 息屏，待机时 ADB 会被断开）
2. **IP 改了** —— 重新看 设置 → 网络 → 网络信息。DHCP 每次重置都可能换地址
3. **USB 调试 / 网络调试没打开** —— 恢复出厂设置会关掉开发者选项，必须重新连按 7 次版本号
4. 手动连一次看报什么错：

   ```bash
   adb connect 192.168.1.50:5555
   ```

   | 返回 | 含义 | 处理 |
   |---|---|---|
   | `connected to ...` | 通了 | 继续 |
   | `unauthorized` | 电视上有授权弹窗没点 | 遥控器点【允许】，勾「一律允许」 |
   | `failed to connect` / `No route to host` | 端口没开或不同网段 | 确认网络调试已开、电脑和电视同一网段 |
   | `Connection refused` | 5555 没监听 | 电视上关一次再开网络调试 |

5. 还不行就**重启电视**，再重开调试。VIDAA 的 adbd 偶尔会在休眠后卡死
6. 电脑侧兜底：

   ```bash
   adb kill-server && adb start-server
   adb devices          # 应该能看到 192.168.1.50:5555  device
   ```

## Home 键没接管

**先再按一次 Home。** 有些应用（尤其 `com.zb.test` 网络直播）装完会自己抢前台一次。

还不行就手动指定：

```bash
adb shell cmd package set-home-activity com.gathin.tvhome/com.gathin.tvhome.MainActivity
adb shell input keyevent KEYCODE_HOME
```

然后确认到底是谁在前台：

```bash
# 看这个，别看 mCurrentFocus
adb shell dumpsys activity activities | grep mResumedActivity
```

要看到 `com.gathin.tvhome/.MainActivity`。

> **为什么不能用 `mCurrentFocus`**：桌面自己有个播放动画的窗口
> `Tile_Animation_Cover`，它会盖在 Activity 上面，`mCurrentFocus` 显示的是这个窗口名。
> 用它判断会得出「桌面没接管」的错误结论 —— 本次实测就误判过一次。

如果 `mResumedActivity` 是别的应用，说明它在抢：

```bash
adb shell am force-stop <抢前台的包名>
```

如果默认 Home 本身就不对（`cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME`
没有返回 `com.gathin.tvhome`），说明 `set-home-activity` 没生效。检查桌面是否真的装上了：

```bash
adb shell pm list packages | grep gathin
adb shell pm path com.gathin.tvhome
```

## 装的 APK 提示 INSTALL_FAILED_UPDATE_INCOMPATIBLE

签名不同。自制桌面是用 **debug 签名**（`signingConfigs.debug`）打包的，如果你之前装过别人构建的版本、
或者官方版本，两者签名对不上。

```bash
adb shell pm uninstall <包名>
adb install -r <包名>.apk
```

`restore.ps1` 对桌面已经自动处理这种情况（检测到 `UPDATE_INCOMPATIBLE` 会自动卸载重装）。

## 装完「网络直播」它自己跳到播放页

正常现象，不是脚本的问题。`com.zb.test` 在安装完成、或安装后第一次被系统拉起来时，
会自己 return 到播放 Activity。按一次 Home 就回桌面，之后不会反复抢（实测稳定）。

如果它反复抢，说明它在后台被反复拉起：

```bash
adb shell am force-stop com.zb.test
```

## 某个应用想还原成「没装」的状态

```bash
adb shell pm uninstall <包名>
```

## 想把某个厂商包放回来

```bash
adb shell pm enable --user 0 com.hisense.vidaaassistant
```

全部放回来：

```bash
grep -v '^#' state/packages_disabled.txt | grep -v '^$' | while read p; do
  adb shell pm enable --user 0 "$p"
done
```

## 禁完之后遥控器语音键没反应了 / 想用语音

语音助手全家桶被禁了（`docs/debloat-list.md` 第三组），这是设计取舍。想用就整组放回来：

```bash
for p in com.hisense.vidaaassistant com.hisense.tv.aivirtualassistant \
         com.hisense.voicecontrol com.intelligent.speech com.hispeech.ai.area \
         com.speech.enchatroom com.hisense.horizontalassistantmenu \
         com.keylab.speech.core.vidaa com.keylab.speech.view.vidaa; do
  adb shell pm enable --user 0 "$p"
done
```

然后重启电视（语音服务的绑定要重启才生效）。

## 遥控器「信号源」键没反应 / 找不到 HDMI

两种可能：

1. **聚好看（`com.jamdeo.tv.vod`）被禁了** —— 信号源面板在这个包里，不在 `tv_input` 里。
   ```bash
   adb shell pm enable --user 0 com.jamdeo.tv.vod
   ```
2. 面板起来了但切不过去 —— 走直播电视：

   ```bash
   adb shell am start -n com.jamdeo.tv.livetv/.LiveTvActivity
   ```

   > `com.jamdeo.tv.policy.PANEL_EVENT` 是签名级广播，第三方应用发不出去（`SecurityException`），
   > 别指望用 `am broadcast` 唤起面板。

## 电视黑屏 / 卡在开机动画 / 遥控器失灵

**先别慌，也别拔电源。** 按顺序试：

1. **等 3 分钟** —— 禁用包之后首次开机要重建 PackageManager 缓存，比平时慢
2. **遥控器拨电源键 5 秒强关，再开** —— 大多数情况这一步就恢复了
3. **盲操放回包** —— 只要能连上 ADB（电视黑屏但 adbd 还活着）：

   ```bash
   adb connect 192.168.1.50:5555
   for p in com.hisense.vidaaassistant com.hisense.service.ad com.jamdeo.screensaver; do
     adb shell pm enable --user 0 "$p"
   done
   adb reboot
   ```

4. **换一个 Home** —— 如果怀疑是桌面本身起不来：

   ```bash
   adb shell cmd package set-home-activity com.jamdeo.tv.vod/com.jamdeo.tv.vod.MainActivity
   adb shell input keyevent KEYCODE_HOME
   ```

5. **最后手段：恢复出厂设置** —— 设置 → 系统 → 恢复出厂设置。
   电视背面按钮组合（多数 VIDAA：音量- 和 电源 同时长按 10 秒）也能强制重置。

> 核心包保护名单（`systemui` / `settings` / `permissioncontroller` / `packageinstaller` / `providers` /
> `overlay.modules` / `android`）在脚本里是硬编码跳过的，即使误写进清单也不会被禁 —— 所以正常操作
> **不该出现刷成砖的情况**。

## 桌面装上去了，但应用库是空的

应用库的预置清单在 `config/config.xml` 的 `library_apps`。这个仓库里的 APK 已经预置了 7 个应用
（底栏 3 个 + 直播电视 + TVBox + 投屏 + 网络直播）。

如果你换了别的版本，或者装的应用包名不同，网格当然空：

1. 点顶栏的**应用库**按钮 → 选「添加应用」手动加
2. 或者改 `config/config.xml` 重新构建，见 [build-launcher.md](build-launcher.md)

> 应用的显示名和图标由系统按包名解析，装的应用不在、名字就会显示成包名或空白。

## 改了 packages_disabled.txt，某个包没生效

检查文件是不是**纯 ASCII**。Windows PowerShell 5.1 读不带 BOM 的 UTF-8 会按 GBK 解码，
中文注释的字节序列可能吞掉换行，把下一行的包名并进注释里 —— 本次实测踩过一次：
`app.orchard.tv` 因此漏禁，但脚本仍报「已禁用 29 个」。

```powershell
# 检查是否含非 ASCII
Get-Content .\state\packages_disabled.txt -Encoding Byte | Where-Object { $_ -gt 127 }
# 没有输出 = 纯 ASCII，安全
```

跑 `-DryRun` 可以确认脚本实际读到了几行。

## 恢复脚本会不会把我的电视刷成砖

不会，前提是别手改清单瞎加包。脚本只做四件事：

- `adb install -r -d`（普通安装，可卸载）
- `pm disable-user --user 0`（**用户级**禁用，不是系统级卸载，随时 `pm enable` 回来）
- `cmd package set-home-activity`（改默认 Home）
- `settings put secure screensaver_enabled 0`

**不 root、不刷机、不改分区、不解锁 Bootloader**。所有改动都在 `/data` 的用户配置层，
恢复出厂设置就全部消失 —— 这也正是本包存在的意义。

## 关掉调试以后还能找回电视吗

不能远程了，只能本地操作。所以：

1. 全部确认正常后**再**关
2. 关了之后不要删这个仓库（含 `apks/`），下次重置还要用
3. 电视 IP 会变，下次重开调试后重新看 设置 → 网络

## macOS 上 `restore.sh` 提示找不到 adb

```bash
brew install android-platform-tools
```

或者下载 Google 官方包解压后把 `platform-tools` 放到仓库根目录。

## 脚本报 `syntax error near unexpected token` 之类的错

Windows 上如果你用记事本另存过脚本，行尾可能变成 CRLF。本仓库 `.gitattributes` 已固定
`*.sh` 为 LF；如果手动改过，修一下：

```bash
sed -i 's/\r$//' restore.sh
```
