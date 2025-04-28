import SwiftUI

public struct ConditionalUnfinishedOnboardingReminder: View {
    public init() { }
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @AppStorage("hasRespondedToOnboarding") private var hasRespondedToOnboarding = false
    @ObservedObject private var adsViewModel = AdsViewModel.shared

    @ViewBuilder var upgradeShortestText: some View {
        Text("\(Image(systemName: "chevron.right"))").foregroundColor(Color.accentColor)
    }
    
    @ViewBuilder var upgradeShortText: some View {
        Text("Upgrades \(Image(systemName: "chevron.right"))").foregroundColor(Color.accentColor)
    }
    
    @ViewBuilder var upgradeText: some View {
        Text("Get Discounts \(Image(systemName: "chevron.right"))").foregroundColor(Color.accentColor)
    }
    
    public var body: some View {
        if !hasRespondedToOnboarding && hasSeenOnboarding && adsViewModel.showAds {
            Button {
                hasSeenOnboarding = false
            } label: {
                GroupBox {
                    HStack {
                        Label {
                            Text("Subsidized Pricing")
                                .bold()
                        } icon: {
                            Image(systemName: "info.circle.fill").foregroundColor(.accentColor)
                        }.tint(.primary)
                        Spacer()
                        if #available(iOS 16, macOS 13, *) {
                            ViewThatFits {
                                upgradeText
                                    .fixedSize()
                                upgradeShortText
                                    .fixedSize()
                                upgradeShortestText
                                    .fixedSize()
                            }
                        } else {
                            upgradeShortText
                                .fixedSize()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                //                .backgroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
            }
            .buttonStyle(.borderless)
        }
    }
}
