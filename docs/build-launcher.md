# 自己改桌面，重新构建 APK

仓库里的 `launcher/tvhome-launcher.apk`（v2.7，2 MB，debug 签名）就是用下面这套流程构建的。
底层源码是 [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv)，MIT 协议。

---

## 1. 环境

实测可用的组合（这套组合在 Windows 上跑通，Linux/macOS 同理）：

| 组件 | 版本 | 说明 |
|---|---|---|
| JDK | **17**（Temurin 17.0.20.1+1） | Gradle 8.9 不认 JDK 21+（`Unsupported class file major version`） |
| Gradle | 8.9 | 用仓库自带 `gradlew` 即可，不用另装 |
| AGP | 8.5.2 | 项目已配好 |
| Android SDK Platform | **34** | `compileSdk 34` |
| Build-Tools | 34.0.0 | aapt2 打资源要用 |
| minSdk | 26 | 电视是 SDK 28，够 |

`launcher/app/build.gradle` 关键项：

```gradle
namespace 'com.gathin.tvhome'
applicationId 'com.gathin.tvhome'      // 可用 -PlauncherApplicationId 覆盖
minSdk 26
targetSdk 34
versionCode 8
versionName '2.7'
// release 用的是 debug 签名
signingConfig signingConfigs.debug
```

> 因为是 **debug 签名**，换一个构建环境打出来的 APK 签名可能不同，覆盖安装会报
> `INSTALL_FAILED_UPDATE_INCOMPATIBLE`。自用没问题，先 `adb uninstall com.gathin.tvhome` 即可。

## 2. 拉源码

```bash
git clone --depth 1 https://github.com/Gathin23/cleanyourtv.git
cd cleanyourtv/launcher
```

## 3. 改配置：`app/src/main/res/values/config.xml`

所有可见变化都在这个文件里，不用改 Java/Kotlin。

### 底栏（dock）

```xml
<!-- 最多等于 dock 列数；少于列数时，空位会从 library_apps / 已装应用里自动补 -->
<string-array name="dock_apps">
    <item>com.hisen.android.tv</item>        <!-- 魔法影视 -->
    <item>com.jamdeo.tv.mediacenter</item>   <!-- 媒体中心 -->
    <item>com.android.tv.settings</item>     <!-- 设置 -->
</string-array>
```

本次实测：底栏第 4 个槽位自动补上了 `com.hisense.multiscreen.screenhelper`（投屏）。

### 应用库（网格）

```xml
<bool name="app_library">true</bool>   <!-- 应用库模式开着，别关 -->

<!-- 首次启动预置进网格的应用；中国区电视如果没有这一段，新桌面网格会是空的 -->
<string-array name="library_apps">
    <item>com.hisen.android.tv</item>
    <item>com.jamdeo.tv.mediacenter</item>
    <item>com.android.tv.settings</item>
    <item>com.jamdeo.tv.livetv</item>
    <item>com.github.tvbox.osc.tk</item>
    <item>com.hisense.multiscreen.screenhelper</item>
    <item>com.zb.test</item>
</string-array>
```

### 从桌面隐藏（不卸载、不禁用）

```xml
<string-array name="hidden_apps">
    <item>com.jamdeo.tv.vod</item>            <!-- 聚好看：信号源面板在它里面，只能藏不能禁 -->
    <item>com.mediatek.wwtv.tvcenter</item>
    <item>com.mitv.gallery</item>
    <item>com.android.camera2</item>
    <item>com.android.wechathci</item>
    <item>com.hisense.systeminfo</item>
</string-array>
```

### 改显示名

```xml
<string-array name="app_labels">
    <item>com.zb.test=网络直播</item>     <!-- 原名「直播电视」，容易和 livetv 混 -->
</string-array>
```

### 直播电视入口

```xml
<string name="live_tv_package" translatable="false">com.jamdeo.tv.livetv</string>
```

### 性能开关（MT9632 这种中端芯片建议开）

```xml
<bool name="reduced_motion">true</bool>   <!-- 动画降到 90ms 内、少画帧；卡顿就开 -->
<bool name="focus_overshoot">false</bool> <!-- 关掉聚焦回弹 -->
<bool name="module_cards">false</bool>    <!-- 不找应用自带的卡片 -->
```

> 本文交付的 APK 里这三个仍是默认值（`false / true / true`），因为 MT9632 跑满动画**不卡**。
> 只有你换到 MT5895 + Android 10 的机型才需要打开 `reduced_motion`。

## 4. 构建

### 命令行

```bash
export JAVA_HOME=/path/to/jdk-17
export ANDROID_HOME=/path/to/android-sdk     # 需要 platforms/android-34 + build-tools/34.0.0

./gradlew :app:assembleRelease
# 产物：app/build/outputs/apk/release/app-release.apk
```

首次构建 Gradle 会下载 AGP 和依赖，约 300 MB，国内建议挂镜像。

### IDE

用 Android Studio 打开 `launcher/` 目录，选 app → Build → Generate Signed Bundle / APK →
APK → debug（或自己的签名），Build Variant 选 `release`。

### 上游自带的脚本

`launcher/build-and-install.sh` / `.ps1` 会自己找 JDK、检查电视 SDK 版本、构建、推送到电视并设为 Home：

```bash
TV_HOST=192.168.1.50 ./build-and-install.sh
```

它依赖 `tools/venv` 里的 Python 环境（`python3 -m venv tools/venv && pip install -r tools/requirements.txt`），
第一次用要装一下。

## 5. 装到电视

```bash
adb connect 192.168.1.50:5555
adb install -r app/build/outputs/apk/release/app-release.apk
adb shell cmd package set-home-activity com.gathin.tvhome/com.gathin.tvhome.MainActivity
adb shell input keyevent KEYCODE_HOME
adb shell dumpsys activity activities | grep mResumedActivity   # 应为 com.gathin.tvhome
```

签名冲突（`INSTALL_FAILED_UPDATE_INCOMPATIBLE`）就先卸再装：

```bash
adb uninstall com.gathin.tvhome
adb install -r app/build/outputs/apk/release/app-release.apk
```

## 6. Windows 上可能会踩的坑

| 现象 | 原因 / 处理 |
|---|---|
| `Unsupported class file major version 68` | JDK 版本太高（21/24）。换 JDK 17 |
| `SDK location not found` | 在 `launcher/local.properties` 写 `sdk.dir=C\:\\path\\to\\sdk`（反斜杠要转义） |
| `aapt2 ... failed` | 缺 build-tools 34.0.0，或路径含中文/空格 |
| Git Bash 里 `adb pull /sdcard/x` 报 `No such file` | MSYS 把 `/sdcard` 转成了 Windows 路径。加 `MSYS_NO_PATHCONV=1`、`MSYS2_ARG_CONV_EXCL="*"` |
| `adb exec-out screencap -p > x.png` 得到非 PNG | 流里混了别的字节。改成设备端截图再 pull：`adb shell screencap -p /sdcard/_s.png && adb pull /sdcard/_s.png` |
| Gradle 下载卡死 | 换腾讯云镜像：`https://mirrors.cloud.tencent.com/gradle/` |

## 7. 想再往深改

上游仓库的 `docs/` 里有主题系统（`themes/`）、卡片协议（`docs/specs/card.md`）、
输入源定义（`input_sources`）、按键映射（`app_keys`）的说明书。
本仓库只动了 `config.xml`，没有改任何代码。
