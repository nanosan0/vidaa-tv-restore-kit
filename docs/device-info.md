# 实机信息与探测过程

本仓库所有包名、清单、设置项都来自下面这台机器的实测，不是查资料猜的。

## 1. 硬件与系统

| 项 | 值 | 取值命令 |
|---|---|---|
| 型号 | `VIDAA_TV` | `getprop ro.product.model` |
| 品牌 / 厂商 | `hisense` | `getprop ro.product.brand` |
| 设备代号 | `MTK9632` | `getprop ro.product.device` |
| 芯片平台 | `m7332`（联发科 MT9632 SoC 内部代号） | `getprop ro.board.platform` |
| Android | 9（SDK 28） | `getprop ro.build.version.release` |
| 固件 | `PPR2.180905.006.A1 dev-keys` | `getprop ro.build.display.id` |
| 分辨率 / 密度 | 1920×1080 / 320 dpi | `wm size` / `wm density` |
| 系统 | 海信 JuUI（VIDAA），**无 GMS** | `pm list packages \| grep google` 为空 |
| 网络 | 内置以太网口有线直连（非 USB 网卡） | `dumpsys connectivity` |
| 存储 | `/data` 3.32 GB，可用 1.22 GB（36%） | `df -h /data` |

> `ro.adb.secure=1` 但固件对 RSA 指纹校验不严 —— 这也是最后一定要关网络调试的原因。

## 2. 怎么找到这些包的

```bash
# 全部包 + 安装来源 + 是否系统应用
adb shell pm list packages -f -U
adb shell dumpsys package | grep -E "Package \[|installerPackageName="

# 谁被禁用了（改动前只有固件自带的蓝牙）
adb shell pm list packages -d

# 第三方（-3）→ 13 个，其中 app.orchard.tv 是「助手」静默装的广告应用
adb shell pm list packages -3

# 谁在监听静默安装广播
adb shell dumpsys package com.hisense.service.message | grep -i SCILENT_INSTALL
```

结论：`com.hisense.service.message` 注册了 `com.hisense.appstore.SCILENT_INSTALL`，
`app.orchard.tv` 的 installer 是 `com.hisense.vidaaassistant` —— 两者都在禁用清单里。

## 3. 信号源面板到底属于谁

遥控器「信号源」键对应的面板**不是** `tv_input`：

```bash
adb shell cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER
adb shell dumpsys package com.jamdeo.tv.vod | grep -i panel
```

- `tv_input` 没有注册任何 Activity，直接调它没反应
- 面板在 **`com.jamdeo.tv.vod`（聚好看）** 里
- 真正的切换动作由 `com.jamdeo.tv.livetv/.LiveTvActivity` 携带 `MSG_SYNC_SOURCE <id>` 完成
- `com.jamdeo.tv.policy.PANEL_EVENT` 是**签名级**广播，普通应用发不出去（`SecurityException`）

所以：聚好看**不能禁**，只能从桌面隐藏。这也决定了 `hidden_apps` 的处理方式。

厂商源码 ID（有需要自定义 `input_sources` 时用）：

| 源 | ID |
|---|---|
| DVB-C（有线电视） | 2561 |
| AV | 1025 |
| HDMI1 / HDMI(ARC) | 1281 |
| HDMI2 | 1282 |

## 4. 改动前的原始快照

`state/` 下都是改动前的原始状态，随时可以对照：

| 文件 | 内容 |
|---|---|
| `packages_all.txt` | 179 个包的全量清单 |
| `packages_thirdparty.txt` | 13 个第三方包（含后来的 `app.orchard.tv`） |
| `packages_disabled.txt` | **要禁用的 29 个包**（这份是目标清单，不是原始状态） |
| `settings_global/secure/system.txt` | 三大 settings 命名空间全量 |
| `getprop.txt` | 系统属性全量（25 KB） |
| `home_activity.txt` | 原默认 Home 组件 |
| `usb_net.txt` | 网络接入方式 |
