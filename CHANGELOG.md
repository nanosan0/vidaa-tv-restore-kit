# 更新记录

## v1.0.1 — 2026-10-31

文档补充，脚本与配置无改动。

- 新增 FAQ「重启后停在聚好看，按 Home 回不来」：聚好看同为 HOME 类应用，开机自启后会占据
  home task，此时 Home 键是空操作。默认 Home 设置仍是 `com.gathin.tvhome`，
  `am force-stop com.jamdeo.tv.vod` 后按一次 Home 即恢复
- 记录开机抢占的竞态规律：同一天两次重启，一次被 `com.zb.test` 抢前台（按 Home 即回），
  一次被聚好看占 home task（需 force-stop）。两者都不影响 Home 设置本身
- 新增「想看某个应用是不是抢了前台」排查段（`mHomeProcess` 判据）

## v1.0.0 — 2026-10-26

首个版本，基于一台实机 `hisense VIDAA_TV`（MTK9632 / Android 9 / SDK 28）从零做完的完整备份。

### 内容

- `launcher/tvhome-launcher.apk` — 基于 cleanyourtv v2.7 重新配置构建（debug 签名，2 MB）
  - 底栏：魔法影视 / 媒体中心 / 设置（第 4 位自动补投屏）
  - 应用库：保留，预置 7 个应用
  - 桌面隐藏：聚好看、MediaTek TV Center、相册、相机、微信互联、系统信息
  - `com.zb.test` 显示名改为「网络直播」
- `state/packages_disabled.txt` — 29 个厂商包清单（遥测 3 / 广告 5 / 语音 9 / 零售 5 / 内容 6 / AOSP 1）
- `state/*` — 改动前全量快照：179 个包、三大 settings、getprop、显示参数、Home 组件
- `config/config.xml` — 桌面完整配置与运行时快照
- `restore.ps1` / `restore.sh` / `恢复.bat` — 一键恢复脚本，自带核心包保护名单
- `docs/` — 实机信息、逐包说明、FAQ、桌面构建指南

### 修复（都是在真机上跑出来的）

- **`com.android.bluetooth` 从禁用清单移除** —— 固件出厂就禁用，`pm disable-user` 抛
  `SecurityException`。留在清单里会让脚本报「失败 1 个」，实际无事可做
- **Home 判定改用 `mResumedActivity`** —— 原来用 `mCurrentFocus` 会把桌面的动画窗口
  `Tile_Animation_Cover` 当结论，误报「没接管」。现在连按最多 3 次 Home 再判定，
  以应对 `com.zb.test` 装完自己抢前台
- **`packages_disabled.txt` 改为纯 ASCII** —— 之前中文注释被 PowerShell 5.1 按 GBK 误读，
  吞掉了换行，`app.orchard.tv` 被并进注释而漏禁，脚本却仍报「29 个成功」

### 已知限制

- 应用内数据无法备份（无 root，读不到 `/data/data`）：需重做登录、TVBox 接口地址、网络直播授权码
- 第三方 APK 因体积原因不进仓库，放在 Releases 的 `apks.zip`
- 只在上面那一台机器上验证过；不同型号请先 `-DryRun`
