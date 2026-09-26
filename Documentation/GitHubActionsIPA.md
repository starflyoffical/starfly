# 使用 GitHub Actions 建置 IPA

此專案的 GitHub Actions 工作流程會建立**未簽署 IPA**，內含 StarFly 主程式與靈動島用的 `StarFlyLiveActivity.appex`。這是刻意的：Apple 簽章憑證與個人帳號不應直接放進 repository。

## 取得測試 IPA

1. 將此資料夾推送到你自己的 GitHub repository。
2. 在 GitHub 專案頁面開啟 **Actions**。
3. 選擇「建置未簽署 IPA」，按 **Run workflow**。
4. 工作完成後，在該次執行頁面下載 `StarFly-unsigned-IPA` artifact。
5. 用 SideStore、AltStore 或 Xcode 以你自己的 Apple 帳號簽署並安裝 `StarFly-unsigned.ipa`。

簽署工具必須一併簽署 `com.starfly.app` 與 `com.starfly.app.liveactivity` 兩個 Bundle ID。若你的證書工具要求移除 App Extension，該版本即不會顯示靈動島；請改用支援嵌入式 extension 的簽署方式，或接受該相容版本沒有 Live Activity。Workflow 會檢查 IPA 內的 extension、Bundle ID 與 Live Activities 設定，避免上傳缺件的包。

免費 Apple 帳號的側載 App 通常需要定期重新簽署。請只在你擁有並控制的裝置上測試，且完成後還原實際位置。

## 工作流程觸發時機

`.github/workflows/build-ipa.yml` 可從 Actions 頁面手動執行，也會在推送至 `main` 或 `master` 分支後自動執行。
