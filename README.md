# 海信 VIDAA 电视去膨胀 + Apple TV 风格桌面 · 一键恢复包

> 给海信 VIDAA（MT9632 / Android 9）电视用的**离线恢复包**：
> 恢复出厂设置之后，一条命令把「干净桌面 + 去膨胀 + 常用应用」全部装回去。

- 桌面换成自制的 Apple TV 4K 风格启动器（`com.gathin.tvhome`），遥控器 Home 键直接接管
- 禁用 **29 个**厂商包：开屏广告、静默安装、语音助手、零售演示、屏保、遥测日志
- 装回 6 个常用应用（TVBox / 魔法影视 / 网络直播 / 云视听小电视 / 绿联云 / 陕西广电直播）
- 全部改动**可逆**，没有任何一步会刷机、root 或改分区

配套的桌面源码来自 [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv)（MIT）。

---

## ⚠️ 先读这一段

1. **只在这台机器上验证过**：`hisense VIDAA_TV` / `MTK9632 (m7332)` / Android 9 (SDK 28) / 1920×1080 @ 320dpi。
   同款 VIDAA 大概率可用；**不同型号、不同固件不要直接照搬包名清单**，先跑 `-DryRun` 看要禁用哪些。
2. `pm disable-user` 禁错核心包会让电视开不了机 / 遥控器失灵。脚本内置保护名单（systemui、settings、
   permission controller、providers 等），但**清单仍然值得你自己看一眼**：`state/packages_disabled.txt`。
3. 全部操作只依赖 ADB，**不需要 root**，也不解锁 Bootloader，不触发保修条款和 OTA。
4. 出问题第一招：`pm enable --user 0 <包名>`；第二招：恢复出厂设置（这也是本包存在的原因）。

---

## 一、3 步装完

### 第 0 步：拿到文件

```bash
git clone https://github.com/nanosan0/vidaa-tv-restore-kit.git
cd vidaa-tv-restore-kit
```

> 不想装 git 也行：去 [Releases](https://github.com/nanosan0/vidaa-tv-restore-kit/releases)
> 下载 `TV-Restore-Kit-VIDAA-20261026.zip`（完整离线包，自带 adb），解压双击 `恢复.bat` 即可。

然后到仓库的 **Releases** 页面下载 `apks.zip`（约 240 MB，6 个第三方应用），解压到仓库的 `apks/` 目录：

```
vidaa-tv-restore-kit/
└─ apks/
   ├─ com.hisen.android.tv.apk            魔法影视
   ├─ com.github.tvbox.osc.tk.apk         TVBox
   ├─ com.zb.test.apk                     网络直播
   ├─ com.xiaodianshi.tv.yst.apk          云视听小电视（B 站）
   ├─ com.ugreen.nasprotv.apk             绿联云
   └─ com.gitv.dvb.live.shaanxi.apk       陕西广电直播
```

> 为什么 APK 不放仓库：GitHub 单文件 100 MB 上限，`com.ugreen.nasprotv.apk` 就有 124 MB。
> **没有这些 APK 也能用**，脚本会跳过安装，只做去膨胀 + 桌面。

### 第 1 步：电视上打开调试

恢复出厂设置会关掉开发者选项，必须重开：

1. 设置 → 关于 / 本机信息 → 找到「版本号」，用遥控器连按 **7 次**，提示「已进入开发者模式」
2. 返回上一级 → **开发者选项**
3. 打开 **USB 调试**；如果有 **网络调试 / ADB 调试** 开关，一并打开
4. 同一页面 → **撤销 USB 调试授权**（清掉历史授权，避免连上就 unauthorized）

> 这台机器是**内置网口有线连接**，开调试不会断网，可以全程远程操作，不用 USB 线。

### 第 2 步：记下电视 IP

电视上：设置 → 网络 → 网络信息 → **IP 地址**（形如 `192.168.1.50`）。

> IP 是路由器 DHCP 分配的，重置后**大概率会变**，别照抄别人文章里的地址。

### 第 3 步：跑脚本

**Windows —— 双击 `恢复.bat`**，按提示输入电视 IP，全程无脑下一步。

或者命令行（想先体检就加 `-DryRun`）：

```powershell
# 只看不改：列出将要禁用哪些包、将装哪些 APK
powershell -ExecutionPolicy Bypass -File .\restore.ps1 -TvIp 192.168.1.50 -DryRun

# 正式执行
powershell -ExecutionPolicy Bypass -File .\restore.ps1 -TvIp 192.168.1.50

# 只做去膨胀（不装 APK），或只装 APK（不去膨胀）
powershell -ExecutionPolicy Bypass -File .\restore.ps1 -TvIp 192.168.1.50 -SkipApps
powershell -ExecutionPolicy Bypass -File .\restore.ps1 -TvIp 192.168.1.50 -SkipDebloat
```

**macOS / Linux / Git Bash**：

```bash
chmod +x restore.sh
./restore.sh 192.168.1.50                 # 正式执行
DRY_RUN=1 ./restore.sh 192.168.1.50       # 只看不改
SKIP_APPS=1 ./restore.sh 192.168.1.50     # 只去膨胀
```

脚本会自动找 adb：优先用仓库里的 `platform-tools/`，其次系统 PATH，都没有就提示从 Google 官方下载
（`platform-tools-latest-windows.zip`，约 6 MB）。

跑的过程中电视**会弹「允许 USB 调试吗？」**，用遥控器点【允许】，建议勾选「一律允许」。

预期输出：

```
[步骤 1/5] 连接电视 192.168.1.50:5555 ...
  已连接。设备：VIDAA_TV
[步骤 2/5] 安装应用 ...
  安装 com.github.tvbox.osc.tk.apk ... 成功
  ...
  安装自制桌面 ... 成功
[步骤 3/5] 按清单禁用厂商包 ...
  已禁用 29 个，跳过 0 个（不存在或受保护），失败 0 个
[步骤 4/5] 把自制桌面设为默认 Home ...
  桌面已接管 Home。
[步骤 5/5] 恢复系统设置 ...
  系统屏保已关闭（screensaver_enabled=0）
================ 恢复完成 ================
```

跑完**别忘了最后一步**：电视上 开发者选项 → 关掉 USB 调试 / 网络调试。
端口 5555 是明文协议，同一个局域网里任何设备都能拿到 shell。

---

## 二、不用脚本，纯手工版

只想要干净桌面、不想跑别人写的脚本，照抄这 8 条：

```bash
TV=192.168.1.50:5555
adb connect $TV

# 1. 装桌面
adb -s $TV install -r launcher/tvhome-launcher.apk

# 2. 桌面设为默认 Home
adb -s $TV shell cmd package set-home-activity com.gathin.tvhome/com.gathin.tvhome.MainActivity
adb -s $TV shell input keyevent KEYCODE_HOME

# 3. 装常用应用（把 apks/*.apk 换成你的文件）
adb -s $TV install -r apks/com.github.tvbox.osc.tk.apk

# 4. 去膨胀：一行一个，逐条执行
adb -s $TV shell pm disable-user --user 0 com.hisense.hitv.das
adb -s $TV shell pm disable-user --user 0 com.hisense.service.message
# …… 完整清单见 state/packages_disabled.txt

# 5. 关掉系统屏保（不关的话空闲会跳厂商屏保）
adb -s $TV shell settings put secure screensaver_enabled 0

# 6. 验收
adb -s $TV shell dumpsys activity activities | grep mResumedActivity   # 应为 com.gathin.tvhome
adb -s $TV shell pm list packages -d | wc -l                          # 应为 30（29 + 固件自带蓝牙）
```

> 判断前台是谁要用 `mResumedActivity`，别用 `mCurrentFocus`：桌面自己有个动画窗口
> （`Tile_Animation_Cover`）会盖在上面，看窗口名会误判成「没接管」。

---

## 三、脚本具体动了什么

| 步骤 | 动作 | 是否可逆 |
|---|---|---|
| 1 | `adb connect` 并等待授权 | — |
| 2 | `adb install -r -d` 安装 `apks/*.apk` + 自制桌面 | `adb uninstall <包名>` |
| 3 | 按 `state/packages_disabled.txt` 执行 `pm disable-user --user 0` | `pm enable --user 0 <包名>` |
| 4 | `cmd package set-home-activity` 指向自制桌面 | 指定回聚好看即可 |
| 5 | `settings put secure screensaver_enabled 0` | 改回 1 |

第 4 步会连按最多 3 次 Home 并检查 `mResumedActivity` —— 因为 `com.zb.test`（网络直播）装完会自己抢前台，
一次判定容易误报。若某个应用反复抢回来：

```bash
adb -s $TV shell am force-stop com.zb.test
```

---

## 四、恢复出来是什么样

### 装回去的 7 个应用

| 应用 | 包名 | 大小 | 来源 |
|---|---|---|---|
| 自制桌面（Apple TV 风格） | `com.gathin.tvhome` | 2 MB | 本仓库 `launcher/` |
| 魔法影视 | `com.hisen.android.tv` | 42 MB | Releases |
| TVBox | `com.github.tvbox.osc.tk` | 26 MB | Releases |
| 网络直播（原「直播电视」） | `com.zb.test` | 13 MB | Releases |
| 云视听小电视（B 站） | `com.xiaodianshi.tv.yst` | 28 MB | Releases |
| 绿联云 | `com.ugreen.nasprotv` | 124 MB | Releases |
| 陕西广电直播 | `com.gitv.dvb.live.shaanxi` | 22 MB | Releases |

### 桌面布局

| 位置 | 内容 |
|---|---|
| 底栏（dock） | 魔法影视 · 媒体中心 · 设置，剩余槽位自动补「投屏」 |
| 应用库（网格） | 上面 3 个 + 直播电视、TVBox、投屏、网络直播（`config/config.xml` 的 `library_apps` 预置） |
| 顶栏 | 应用库按钮 + 设置 |
| 应用库模式 | **保留**（`app_library=true`），装新应用后按顶栏按钮就能加进网格 |
| 桌面隐藏 | 聚好看（`com.jamdeo.tv.vod`）、MediaTek TV Center、相册、相机、微信互联 |

### 重新禁用的 29 个包

| 类别 | 包 |
|---|---|
| 遥测 / 日志 | `com.hisense.hitv.das`、`com.hisense.logupload`、`com.hisense.service.hproxy` |
| 广告 / 推送 / 静默安装 | `com.hisense.service.ad`、`com.hisense.business.ad`、`com.hisense.service.message`、`app.orchard.tv`、`com.hisense.prism` |
| 语音助手全家桶 | `com.hisense.vidaaassistant`、`com.hisense.tv.aivirtualassistant`、`com.hisense.voicecontrol`、`com.intelligent.speech`、`com.hispeech.ai.area`、`com.speech.enchatroom`、`com.hisense.horizontalassistantmenu`、`com.keylab.speech.core.vidaa`、`com.keylab.speech.view.vidaa` |
| 零售 / 演示 / 屏保 | `com.hisense.demonstrate`、`com.hisense.autotest`、`com.hisense.hotelmenu`、`com.hisense.electronictutorial`、`com.jamdeo.screensaver` |
| 内容 / 生活 | `com.bajintech.karaok`、`com.hisense.smartimages`、`com.hisense.tv.familyalbum`、`com.hisense.tv.videochat`、`com.hisense.childlock`、`com.jamdeo.android.avatarresources` |
| AOSP 冗余 | `com.android.printspooler` |

加上固件出厂就禁用的 `com.android.bluetooth`（shell 无权改它），恢复完成后 `pm list packages -d` 显示 **30** 个。
逐包说明见 **[docs/debloat-list.md](docs/debloat-list.md)**。

### 故意**不动**的

| 组件 | 为什么保留 |
|---|---|
| 聚好看 `com.jamdeo.tv.vod` | 它同时提供遥控器「信号源」键的 HDMI / AV / 直播电视面板，禁掉就没有信号源入口。**只从桌面隐藏，不卸载不禁用** |
| 投屏 5 件套 | `com.kookong.tvplus`、`com.ms.weshare`、`com.multiscreen.airplay`、`com.hisense.wifidisplay`、`com.hisense.multiscreen.screenhelper` —— 手机投屏靠它们 |
| OTA 与 U 盘升级 | `com.jamdeo.updateservice`、`com.hisense.usbupgrade` |
| 直播电视 `com.jamdeo.tv.livetv` | 频道扫描和 HDMI 切换的唯一入口（`MSG_SYNC_SOURCE`） |

---

## 五、恢复不了的东西（必须你自己重做）

电视没 root，`/data/data` 读不到，**APK 能装回去，应用数据不行**：

| 需要重做 | 说明 |
|---|---|
| 各应用登录 | 绿联云、云视听小电视、魔法影视会员 |
| TVBox 接口地址 | 重装后配置为空，要把订阅 URL 重新填进去 |
| 网络直播授权码 | 首次启动要输的那串码，请自己留档 |
| Wi-Fi / 有线网络 | 出厂重置清空网络配置 |
| Google 账号 | 这台是 JuUI 中国版，无 GMS，本来就没有 |

> 建议现在就把 **TVBox 接口地址** 和 **网络直播授权码** 记到手机备忘录里。

---

## 六、回滚

```bash
TV=192.168.1.50:5555

# 单个包放回来，比如语音助手
adb -s $TV shell pm enable --user 0 com.hisense.vidaaassistant

# 全部放回来
grep -v '^#' state/packages_disabled.txt | grep -v '^$' | while read p; do
  adb -s $TV shell pm enable --user 0 "$p"
done

# 不想用自制桌面了，换回聚好看
adb -s $TV shell cmd package set-home-activity com.jamdeo.tv.vod/.MainActivity
adb -s $TV shell input keyevent KEYCODE_HOME

# 彻底卸载桌面 / 某个应用
adb -s $TV uninstall com.gathin.tvhome
```

最彻底的还原：电视上恢复出厂设置 —— 也正因为如此才需要这个包。

---

## 七、目录结构

```
vidaa-tv-restore-kit/
├─ 恢复.bat                     Windows 双击即用
├─ restore.ps1                  Windows 主脚本（支持 -DryRun / -SkipApps / -SkipDebloat）
├─ restore.sh                   macOS / Linux / Git Bash
├─ apks/                        第三方 APK 放这里（.gitignore，从 Releases 下载）
├─ launcher/
│  └─ tvhome-launcher.apk       自制桌面，2 MB
├─ config/
│  ├─ config.xml                桌面完整配置（底栏、网格、隐藏应用、标签）
│  ├─ library_apps.txt          桌面运行时的应用库快照
│  └─ launcher_settings.xml     桌面 SharedPreferences 快照（仅参考）
├─ state/
│  ├─ packages_disabled.txt     ★ 要禁用的 29 个包，可自行增删
│  ├─ packages_all.txt          改动前完整包清单（179 个）
│  ├─ packages_thirdparty.txt   改动前第三方清单
│  ├─ settings_{global,secure,system}.txt   系统设置全量快照
│  ├─ getprop.txt               系统属性全量快照
│  ├─ display.txt               分辨率 / 密度
│  ├─ home_activity.txt         默认 Home 组件
│  └─ usb_net.txt               网络接入方式
└─ docs/
   ├─ device-info.md            实机信息与探测过程
   ├─ debloat-list.md           逐包说明与风险分级
   ├─ faq.md                    常见问题（连不上 / Home 没接管 / 装不上 / 黑屏急救）
   └─ build-launcher.md         自己改桌面并重新构建 APK
```

---

## 八、常见问题速查

| 现象 | 去哪看 |
|---|---|
| `device not found` / 连接超时 | [docs/faq.md#连不上电视](docs/faq.md) |
| 按 Home 还是回聚好看 | [docs/faq.md#home-键没接管](docs/faq.md) |
| 重启后停在聚好看、按 Home 没反应 | [docs/faq.md#重启后停在聚好看按-home-回不来](docs/faq.md)（固件开机白名单所致，`am force-stop com.jamdeo.tv.vod` 即可） |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 签名不同，先 `adb uninstall <包名>` 再装 |
| 装完网络直播自己跳到播放页 | 正常，按一次 Home 就回桌面 |
| 想改底栏 / 网格里的应用 | 改 `config/config.xml` 后重新构建：[docs/build-launcher.md](docs/build-launcher.md) |
| 想自己加禁用的包 | 编辑 `state/packages_disabled.txt`，一行一个，`#` 注释 |
| 改清单后某个包没生效 | 该文件**必须保持纯 ASCII**，中文注释会被 PowerShell 5.1 误读并吞掉下一行 |

---

## 九、致谢

- 桌面：[Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv)（MIT）—— Apple TV 4K 风格 TV 启动器
- ADB 逻辑参考：[android/platform-tools](https://developer.android.com/tools/releases/platform-tools)
- 包名与信号源调查：本机 `dumpsys` / `cmd package` 实测

## License

MIT，见 [LICENSE](LICENSE)。`apks/` 下的第三方应用版权归各自作者所有，本仓库不分发。
