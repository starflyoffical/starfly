# StarFly

StarFly 是供你自己的 iPhone 進行定位功能開發與測試的 SwiftUI 工具。

## 功能

- 搜尋地點、輸入經緯度或直接在地圖放置目標。
- 固定位置、步行航線、多點座標匯入與循環。
- 速度滑桿、數值輸入與步行／巡航／快速預設。
- 收藏地點與航線、最近紀錄、變更目的地與安全還原。
- LocalDevVPN 配對與連線診斷。
- 可選的 iOS 捷徑網路流程。
- 動態島步行暫停／繼續與速度調整；結束後可選保留模擬位置或恢復 iPhone 實際位置。
- 不需 StarFly 伺服器、授權碼驗證、管理員上傳路徑或匿名資料回報。

## 安裝與測試

1. 使用 GitHub Actions 產生未簽署 IPA。
2. 以你自己的簽章工具或 Xcode 安裝至受控 iPhone。
3. 完成 StarFly 內的裝置配對與 LocalDevVPN 連線。

詳細資料請見：[安裝說明](Documentation/Installation.md)、[GitHub Actions IPA](Documentation/GitHubActionsIPA.md) 與 [捷徑網路流程](Documentation/StarFly-network-shortcut.md)。

## 資料與網路

StarFly 不連線至自家伺服器，也沒有 App 授權碼或管理員花路下載功能。收藏、歷史紀錄、GPX 匯入路徑與裝置配對資料只保存在 iPhone；App 不會上傳活動統計或背景診斷。地點搜尋由 Apple 地圖提供，iPhone 配對則使用 LocalDevVPN 的本機通道。

重新側載時仍需由 Apple 簽署 App；這與已移除的 StarFly 授權驗證不同。首次裝置配對仍會使用本機六位數配對流程。

僅限於你擁有或獲授權測試的裝置與應用程式使用；測試結束後請還原實際位置。
