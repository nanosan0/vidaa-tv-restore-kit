# apks/ —— 第三方应用放这里

这个目录默认是空的，`.gitignore` 忽略了所有 `*.apk`。

原因：GitHub 单文件上限 100 MB，而 `com.ugreen.nasprotv.apk`（绿联云）就有 124 MB，
`git push` 会直接被拒。所以 6 个第三方 APK 打包成 `apks.zip` 放在 **Releases** 里。

## 怎么用

1. 打开仓库的 **Releases** 页面
2. 下载最新版本的 `apks.zip`（约 240 MB）
3. 解压到**本目录**（不要多套一层文件夹）

```
apks/
├─ com.hisen.android.tv.apk            魔法影视        42 MB
├─ com.github.tvbox.osc.tk.apk         TVBox           26 MB
├─ com.zb.test.apk                     网络直播        13 MB
├─ com.xiaodianshi.tv.yst.apk          云视听小电视    28 MB
├─ com.ugreen.nasprotv.apk             绿联云         124 MB
└─ com.gitv.dvb.live.shaanxi.apk       陕西广电直播    22 MB
```

4. 跑 `restore.ps1` / `restore.sh`，脚本会按文件名排序逐个 `adb install -r -d`

## 没有这个包也能用

`apks/` 为空时脚本只会提示一句，然后照常做去膨胀 + 装桌面。**核心功能（干净桌面 + 29 个包禁用）
完全不依赖这些 APK。**

## 自己的 APK

直接丢进来就行，脚本装 `apks/*.apk` 里的全部文件，不校验包名。
文件名建议用 `<包名>.apk`，出了安装失败好认是哪个。

## 版权

这里的 APK 版权归各自作者所有，本仓库不收录、不改包、不分发。Release 里的 `apks.zip`
只是本机安装包的归档备份，方便重置后一次性装回。

装之前请确认你有权使用这些应用（会员、授权码等由你自己提供）。
