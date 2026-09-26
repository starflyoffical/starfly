import SwiftUI

struct SavedPlacesView: View {
    private enum ClearTarget: String, Identifiable {
        case favourites
        case routes
        case history

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var favouriteBeingRenamed: LocationTarget?
    @State private var favouriteName = ""
    @State private var clearTarget: ClearTarget?
    @State private var editMode: EditMode = .inactive

    let favourites: [LocationTarget]
    let routes: [SavedRoute]
    let history: [LocationTarget]
    let shouldShowFavouriteReorderHint: Bool
    let isFavourite: (LocationTarget) -> Bool
    let onSelect: (LocationTarget) -> Void
    let onToggleFavourite: (LocationTarget) -> Void
    let onDeleteFavourite: (LocationTarget) -> Void
    let onMoveFavourites: (IndexSet, Int) -> Void
    let onDismissFavouriteReorderHint: () -> Void
    let onRenameFavourite: (LocationTarget, String) -> Void
    let onDeleteHistory: (LocationTarget) -> Void
    let onClearFavourites: () -> Void
    let onSelectRoute: (SavedRoute) -> Void
    let onDeleteRoute: (SavedRoute) -> Void
    let onClearRoutes: () -> Void
    let onClearHistory: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if favourites.isEmpty {
                        EmptySavedPlacesRow(
                            symbol: "heart",
                            message: "點選選取地點上的愛心即可儲存。"
                        )
                    } else {
                        ForEach(favourites) { location in
                            SavedPlaceRow(
                                location: location,
                                symbol: "heart.fill",
                                isFavourite: true,
                                onSelect: { select(location) },
                                onToggleFavourite: { onToggleFavourite(location) }
                            )
                            .padding(.vertical, 4)
                            .starFlyGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteFavourite(location)
                                } label: {
                                    Label("刪除", systemImage: "trash")
                                }

                                Button {
                                    beginRenaming(location)
                                } label: {
                                    Label("重新命名", systemImage: "pencil")
                                }
                                .tint(.gray)
                            }
                        }
                        .onMove(perform: onMoveFavourites)
                    }
                } header: {
                    HStack {
                        Text("最愛")
                        Spacer()
                        if !favourites.isEmpty {
                            Button("清除") {
                                clearTarget = .favourites
                            }
                            .textCase(nil)
                        }
                    }
                } footer: {
                    if shouldShowFavouriteReorderHint && favourites.count >= 2 {
                        Text("點選「編輯」重新排列最愛。")
                    }
                }

                Section {
                    if routes.isEmpty {
                        EmptySavedPlacesRow(
                            symbol: "point.3.connected.trianglepath.dotted",
                            message: "收藏的路徑會顯示在這裡。"
                        )
                    } else {
                        ForEach(routes) { route in
                            SavedRouteRow(route: route, onSelect: { select(route) })
                                .padding(.vertical, 4)
                                .starFlyGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        onDeleteRoute(route)
                                    } label: {
                                        Label("刪除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                } header: {
                    HStack {
                        Text("收藏路徑")
                        Spacer()
                        if !routes.isEmpty {
                            Button("清除") {
                                clearTarget = .routes
                            }
                            .textCase(nil)
                        }
                    }
                }

                Section {
                    if history.isEmpty {
                        EmptySavedPlacesRow(
                            symbol: "clock",
                            message: "你使用過的位置會顯示在這裡。"
                        )
                    } else {
                        ForEach(history) { location in
                            SavedPlaceRow(
                                location: location,
                                symbol: "clock.fill",
                                isFavourite: isFavourite(location),
                                onSelect: { select(location) },
                                onToggleFavourite: { onToggleFavourite(location) }
                            )
                            .padding(.vertical, 4)
                            .starFlyGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteHistory(location)
                                } label: {
                                    Label("刪除", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("歷史紀錄")
                        Spacer()
                        if !history.isEmpty {
                            Button("清除") {
                                clearTarget = .history
                            }
                                .textCase(nil)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.16), .gray.opacity(0.10), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .environment(\.editMode, $editMode)
            .navigationTitle("已儲存的位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !favourites.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(editMode.isEditing ? "完成" : "編輯") {
                            if !editMode.isEditing {
                                onDismissFavouriteReorderHint()
                            }
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                            .accessibilityLabel("重新排列最愛")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert(
                "重新命名最愛",
                isPresented: Binding(
                    get: { favouriteBeingRenamed != nil },
                    set: { if !$0 { favouriteBeingRenamed = nil } }
                )
            ) {
                TextField("最愛名稱", text: $favouriteName)
                Button("取消", role: .cancel) {
                    favouriteBeingRenamed = nil
                }
                Button("儲存") {
                    guard let favouriteBeingRenamed else { return }
                    onRenameFavourite(favouriteBeingRenamed, favouriteName)
                    self.favouriteBeingRenamed = nil
                }
                .disabled(favouriteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("為這個已儲存的地點取一個容易辨識的名稱。")
            }
            .confirmationDialog(
                LocalizedStringKey(clearConfirmationTitle),
                isPresented: Binding(
                    get: { clearTarget != nil },
                    set: { if !$0 { clearTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(LocalizedStringKey(clearConfirmationButton), role: .destructive) {
                    performClear()
                }
                Button("取消", role: .cancel) {
                    clearTarget = nil
                }
            } message: {
                Text(LocalizedStringKey(clearConfirmationMessage))
            }
        }
    }

    private func select(_ location: LocationTarget) {
        onSelect(location)
        dismiss()
    }

    private func select(_ route: SavedRoute) {
        onSelectRoute(route)
        dismiss()
    }

    private func beginRenaming(_ location: LocationTarget) {
        favouriteName = location.name
        favouriteBeingRenamed = location
    }

    private var clearConfirmationTitle: String {
        switch clearTarget {
        case .favourites: "要清除所有最愛嗎？"
        case .routes: "要清除所有收藏路徑嗎？"
        case .history: "要清除位置歷史紀錄嗎？"
        case nil: "要清除已儲存的位置嗎？"
        }
    }

    private var clearConfirmationButton: String {
        switch clearTarget {
        case .favourites: "清除最愛"
        case .routes: "清除收藏路徑"
        case .history: "清除歷史紀錄"
        case nil: "清除"
        }
    }

    private var clearConfirmationMessage: String {
        switch clearTarget {
        case .favourites: "所有最愛都會被移除，但歷史紀錄會保留。"
        case .routes: "所有收藏路徑都會被移除。"
        case .history: "所有最近使用的位置都會被移除，但最愛會保留。"
        case nil: "此操作無法復原。"
        }
    }

    private func performClear() {
        switch clearTarget {
        case .favourites:
            onClearFavourites()
        case .routes:
            onClearRoutes()
        case .history:
            onClearHistory()
        case nil:
            break
        }
        clearTarget = nil
    }
}

private struct SavedPlaceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let location: LocationTarget
    let symbol: String
    let isFavourite: Bool
    let onSelect: () -> Void
    let onToggleFavourite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(.primary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(location.name)
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        Text(location.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(StarFlyPressStyle())
            .accessibilityLabel(locationAccessibilityLabel)
            .accessibilityHint("選取此位置")

            Button(action: onToggleFavourite) {
                Image(systemName: isFavourite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavourite ? .primary : .secondary)
                    .frame(width: 44, height: 44)
                    .symbolEffect(.bounce, value: isFavourite)
            }
            .buttonStyle(StarFlyPressStyle())
            .accessibilityLabel(isFavourite ? "從最愛移除" : "加入最愛")
        }
    }

    private var locationAccessibilityLabel: String {
        guard !location.subtitle.isEmpty else { return location.name }
        return "\(location.name), \(location.subtitle)"
    }
}

private struct SavedRouteRow: View {
    @AppStorage("starfly.interfaceLanguage") private var interfaceLanguage = "zh-Hant"
    let route: SavedRoute
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(route.name)
                        .foregroundStyle(.primary)
                    Text(routeDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StarFlyPressStyle())
        .accessibilityLabel("\(route.name)，\(routeDetail)")
        .accessibilityHint("載入此路徑")
    }

    private var routeDetail: String {
        if interfaceLanguage == "en" {
            let loops = route.repeatsIndefinitely ? "Infinite loops" : "\(route.loopCount) loops"
            return "\(route.points.count) points · \(loops)"
        }
        let loops = route.repeatsIndefinitely ? "無限循環" : "\(route.loopCount) 圈"
        return "\(route.points.count) 個座標點 · \(loops)"
    }
}

private struct EmptySavedPlacesRow: View {
    let symbol: String
    let message: String

    var body: some View {
        Label(LocalizedStringKey(message), systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
}
