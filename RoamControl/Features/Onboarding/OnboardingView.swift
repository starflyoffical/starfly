import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage = 0

    let isReplay: Bool
    private let pages = OnboardingPage.pages

    init(isReplay: Bool = false) {
        self.isReplay = isReplay
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.14),
                    Color.gray.opacity(0.08),
                    Color(uiColor: .systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    HStack(spacing: 7) {
                        Image("StarFlyBrand")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 21, height: 21)
                            .clipShape(Circle())
                        Text("STARFLY")
                            .font(.caption.weight(.bold))
                            .tracking(2.2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    if isReplay {
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(StarFlyPressStyle())
                            .accessibilityLabel("關閉介紹")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 22) {
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == selectedPage ? Color.primary : Color.secondary.opacity(0.25))
                                .frame(width: index == selectedPage ? 24 : 8, height: 8)
                                .animation(
                                    reduceMotion ? nil : .spring(response: 0.3),
                                    value: selectedPage
                                )
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("第 \(selectedPage + 1) 頁，共 \(pages.count) 頁")

                    Button {
                        advance()
                    } label: {
                        HStack {
                            Text(finalButtonTitle)
                            Image(systemName: finalButtonSymbol)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private var isLastPage: Bool {
        selectedPage == pages.count - 1
    }

    private func advance() {
        if isLastPage {
            if isReplay {
                dismiss()
            } else {
                appModel.completeOnboarding()
            }
        } else {
            if reduceMotion {
                selectedPage += 1
            } else {
                withAnimation {
                    selectedPage += 1
                }
            }
        }
    }

    private var finalButtonTitle: String {
        if !isLastPage { return "繼續" }
        return isReplay ? "完成" : "設定此 iPhone"
    }

    private var finalButtonSymbol: String {
        if !isLastPage { return "arrow.right" }
        return isReplay ? "checkmark" : "iphone.and.arrow.forward"
    }
}

private struct OnboardingPageView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let page: OnboardingPage

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 30) {
                    Spacer(minLength: 20)

                    Image(systemName: page.symbol)
                        .font(.system(
                            size: dynamicTypeSize.isAccessibilitySize ? 46 : 64,
                            weight: .semibold
                        ))
                        .foregroundStyle(.primary)
                        .frame(
                            width: dynamicTypeSize.isAccessibilitySize ? 96 : 132,
                            height: dynamicTypeSize.isAccessibilitySize ? 96 : 132
                        )
                        .starFlyGlass(
                            in: RoundedRectangle(
                                cornerRadius: dynamicTypeSize.isAccessibilitySize ? 26 : 34,
                                style: .continuous
                            )
                        )
                        .accessibilityHidden(true)

                    VStack(spacing: 14) {
                        Text(LocalizedStringKey(page.title))
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(LocalizedStringKey(page.message))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                .accessibilityElement(children: .combine)
            }
        }
    }

}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let message: String

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "location.viewfinder",
            title: "準備起飛",
            message: "搜尋、貼入座標，或在地圖放置目標。"
        ),
        OnboardingPage(
            symbol: "map.fill",
            title: "建立航線",
            message: "設定速度、循環與收藏，隨時再次啟用。"
        ),
        OnboardingPage(
            symbol: "iphone.and.arrow.forward",
            title: "連線一次即可",
            message: "完成此 iPhone 的配對後，即可開始測試。"
        )
    ]
}

#Preview {
    OnboardingView()
        .environment(AppModel())
}
