# 手指合拢手势 (PinchSnap)

越狱插件（iOS 16，Dopamine rootless，SpringBoard 注入）。

## 功能

- **三指合拢**：在屏幕上三指合拢，打开 Snapper3 **标准模式**。
- **四指合拢**：在屏幕上四指合拢，开启屏幕录制；再合拢一次，停止录制。
- 两个手势在**锁屏时不触发**，解锁后任意界面（桌面、App 内）都可用。

## 设置

设置 App 里有“手指合拢手势”入口，两个开关：

- 三指合拢（默认开）
- 四指合拢（默认开）

## 实现

- 手势：自定义 `UIGestureRecognizer`，只认指定手指数的向内合拢（张开、平移、手指数不对都会失败，不挡 App 自己的手势）；挂在各进程的 keyWindow 上，`cancelsTouchesInView = NO`。
- Snapper3：发 Snapper3 官方文档的 Darwin 通知 `com.jontelang.snapper3.force.open`（标准模式）。
- 录屏：SpringBoard 的 `SBScreenRecordingController` 开/关；App 进程里触发时发 Darwin 通知请 SpringBoard 代劳。
- 锁屏判断：SpringBoard 里查 `SBLockScreenManager isUILocked`（兜底 `SBUIController isLocked`）。

## 构建

推到 GitHub 后 Actions（macos-15 + Theos）编译出 `.deb`，Sileo/Zebra 安装。
