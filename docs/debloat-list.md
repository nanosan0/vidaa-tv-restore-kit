# 去膨胀清单：逐包说明

`state/packages_disabled.txt` 里的 29 个包，逐个说明「它是什么 / 禁了会失去什么 / 风险等级」。

风险等级：

- 🟢 **安全** —— 纯广告、遥测、零售演示，禁掉没有任何功能损失
- 🟡 **可接受** —— 有明确功能，但基本用不上；想留就注释掉
- 🟠 **确认后再禁** —— 可能有人真的在用，按自己习惯决定

> 恢复单包：`adb shell pm enable --user 0 <包名>`

---

## 遥测 / 日志（3）

| 包 | 说明 | 风险 |
|---|---|---|
| `com.hisense.hitv.das` | 埋点与行为上报（DAS = Data Analytics Service），持续收集遥控器操作、应用使用时长 | 🟢 |
| `com.hisense.logupload` | 日志回传，后台有常驻上传任务 | 🟢 |
| `com.hisense.service.hproxy` | 海信服务代理，负责把设备信息转发给云端 | 🟢 |

## 广告 / 推送 / 静默安装（5）

| 包 | 说明 | 风险 |
|---|---|---|
| `com.hisense.service.ad` | 开屏广告与桌面广告位服务 | 🟢 |
| `com.hisense.business.ad` | 广告业务 SDK（与上一条配合，成对出现） | 🟢 |
| `com.hisense.service.message` | 推送中心，注册了 `com.hisense.appstore.SCILENT_INSTALL` —— **静默装应用的入口** | 🟢 |
| `app.orchard.tv` | 现成的静默安装产物：一个没有图标、没有启动器的广告应用，installer 是语音助手 | 🟢 |
| `com.hisense.prism` | 海信预装 / 推荐位框架，负责往桌面塞游戏和应用推荐 | 🟢 |

> 这一组是「电视越用越卡」的主因。禁掉之后不会再莫名其妙多出应用。

## 语音助手全家桶（9）

| 包 | 说明 | 风险 |
|---|---|---|
| `com.hisense.vidaaassistant` | VIDAA 语音助手主程序（也负责静默安装） | 🟡 |
| `com.hisense.tv.aivirtualassistant` | AI 虚拟人助手，占内存大户 | 🟢 |
| `com.hisense.voicecontrol` | 语音控制服务 | 🟡 |
| `com.intelligent.speech` | 语音识别服务 | 🟡 |
| `com.hispeech.ai.area` | 海信语音 AI 区域服务 | 🟡 |
| `com.speech.enchatroom` | 语音闲聊 / 语音房间 | 🟢 |
| `com.hisense.horizontalassistantmenu` | 横向助手菜单（语音唤起的那层 UI） | 🟢 |
| `com.keylab.speech.core.vidaa` | 语音 SDK 内核 | 🟡 |
| `com.keylab.speech.view.vidaa` | 语音 SDK 视图层 | 🟡 |

> **如果你还在用遥控器语音键**，把这一组全部 `pm enable` 回来，然后只禁前三组的广告包。
> 本文的取舍是：语音识别在中文电视上准确率一般，用不上，换内存和静音。

## 零售 / 演示 / 屏保（5）

| 包 | 说明 | 风险 |
|---|---|---|
| `com.hisense.demonstrate` | 商场演示模式（自动轮播宣传片） | 🟢 |
| `com.hisense.autotest` | 产线自检程序 | 🟢 |
| `com.hisense.hotelmenu` | 酒店模式菜单（开机会顶掉你的设置） | 🟢 |
| `com.hisense.electronictutorial` | 电子说明书 / 新手引导 | 🟢 |
| `com.jamdeo.screensaver` | 厂商屏保（会插播推荐内容）。另外用 `settings put secure screensaver_enabled 0` 双保险 | 🟢 |

## 内容 / 生活（6）

| 包 | 说明 | 风险 |
|---|---|---|
| `com.bajintech.karaok` | 全民K歌 TV 版 | 🟢 |
| `com.hisense.smartimages` | 智能图片 / 壁纸推荐 | 🟢 |
| `com.hisense.tv.familyalbum` | 家庭相册（云端同步） | 🟢 |
| `com.hisense.tv.videochat` | 电视视频通话（要外接摄像头） | 🟢 |
| `com.hisense.childlock` | 儿童锁 / 儿童模式 | 🟠 有小孩就留着 |
| `com.jamdeo.android.avatarresources` | 虚拟人形象资源包 | 🟢 |

## AOSP 冗余（1）

| 包 | 说明 | 风险 |
|---|---|---|
| `com.android.printspooler` | 打印服务，电视上没有打印机驱动 | 🟢 |

---

## 刻意没有进清单的

| 包 | 原因 |
|---|---|
| `com.jamdeo.tv.vod`（聚好看） | 信号源面板（HDMI / AV / 直播）在它里面，禁掉遥控器「信号源」键就废了。**只从桌面隐藏** |
| `com.jamdeo.tv.livetv` | 频道扫描、切源（`MSG_SYNC_SOURCE`）的唯一入口 |
| `com.kookong.tvplus`、`com.ms.weshare`、`com.multiscreen.airplay`、`com.hisense.wifidisplay`、`com.hisense.multiscreen.screenhelper` | 手机投屏 5 件套，禁了投屏就没了 |
| `com.jamdeo.updateservice`、`com.hisense.usbupgrade` | OTA 与 U 盘升级通道，保留出问题的后路 |
| `com.android.bluetooth` | 固件出厂就禁用，`pm disable-user` 会抛 `SecurityException`，shell 无权改。所以它不在清单里，但 `pm list packages -d` 仍会算上它 |
| `com.hisense.systeminfo` | 在 `hidden_apps` 里只做桌面隐藏（系统信息页），组件仍可被设置调用 |

---

## 自己改清单

编辑 `state/packages_disabled.txt`，一行一个包名，`#` 开头是注释。

**这个文件必须保持纯 ASCII。** 原因：Windows PowerShell 5.1 的 `Get-Content` 读不带 BOM 的 UTF-8 时
会按 GBK 解码，中文的字节序列可能把后面的换行吃掉，导致下一行包名被并进注释 —— 本次实测踩过一次，
`app.orchard.tv` 因此没被禁用，而脚本仍报「已禁用 29 个」。中文说明一律写在本文件里，不写进清单。

改完先体检：

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1 -TvIp 192.168.1.50 -DryRun
```
