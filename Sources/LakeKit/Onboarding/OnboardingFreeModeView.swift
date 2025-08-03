import SwiftUI
import StoreHelper
import SwiftUtilities

internal struct OnboardingFreeModeView: View {
    let highlightedProduct: PrePurchaseSubscriptionInfo?
    
    @Binding var isPresentingSheet: Bool
    @Binding var isPresentingStoreSheet: Bool
    
    @AppStorage("hasViewedFreeModeUpsell") private var hasViewedFreeModeUpsell = false
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    
    @State private var shouldAnimate = false
    
    private var purchasePrice: String {
        if let highlightedProduct {
            let renewalPeriod = highlightedProduct.subscriptionPeriod
            var renewalString = "per "
            if renewalPeriod.value > 1 {
                renewalString += renewalPeriod.value.formatted() + " "
            }
            if #available(iOS 16, macOS 13, *) {
                renewalString += renewalPeriod.unit.formatted(highlightedProduct.product.subscriptionPeriodUnitFormatStyle).lowercased()
            } else {
                switch renewalPeriod.unit {
                case .day: renewalString += "day"
                case .week: renewalString += "week"
                case .month: renewalString += "month"
                case .year: renewalString += "year"
                }
                if renewalPeriod.value > 1 {
                    renewalString += "s"
                }
            }
            return highlightedProduct.purchasePrice + " " + renewalString
        } else {
            return "[see link for current price]"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack {
                Image("Onboarding - Free Mode Landscape")
                    .resizable()
                    .scaledToFit()
                VStack(alignment: .leading, spacing: 16) {
                    // Intro paragraph with italics
                    (Text("See below for information on Manabi Reader's ")
                     + Text("Free Mode").italic()
                     + Text(" and subsidized pricing options."))
                    
                    // Bold headline
                    Text("Manabi Reader helps you stay motivated while learning faster, for free.")
                        .font(.headline)
                        .bold()
                    
                    // Body paragraphs
                    Text("Read from a library of curated blogs, news feeds, stories and ebooks. Tap words to look them up. Listen to spoken audio as you read.")
                    Text("Immersion is key. Manabi Reader caters to diverse taste and skill levels. Import your own files or browse the web as you like. Reader Mode works on most anything.")
                    Text("Immersion can be a grind too. It's brutal to spend hours reading above your level without being able to feel the progress that you're making. That's why Manabi shows you personalized stats on how familiar you already are with the vocab and kanji you encounter. Collect example sentences automatically. Chart your progress as you read in real-time.")
                    Text("All the above is free.")
                    
                    // Why upgrade section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why upgrade?")
                            .font(.title2)
                            .bold()
                        Text("The subscription personalizes your stats more to help you see what words and kanji you need to learn. Your dictionary syncs with your reading activity to filter by learning status. You get support for saving words to Manabi Flashcards or Anki.")
                        Text("You'll also support ongoing development: Manabi is independently-made and has no external investors. Thousands of paying customers have enabled Manabi development to continue part-time since 2018 and full-time since 2022.")
                    }
                    
                    // Can't afford it section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Can't afford it?")
                            .font(.title2)
                            .bold()
                        Text("Equal access in education is a valuable principle that Manabi aspires toward. If you're a student or if you just can't afford the full price, please consider the discounted plan. It's available for as low as \(purchasePrice) for full access.")
                    }
                    
                    // Editor's Note
                    Text("Editor's Note: Thank you for using Manabi Reader. Whether or not you pay to support its full-time development, rest assured there is more to come for Free Mode. As the subscription tier features improve, more paid features will become free too. Manabi values accessibility for all.")
                        .italic()
                }
                .frame(maxWidth: 850)
                .padding(.horizontal)
                .modifier {
                    if #available(iOS 17, macOS 14, *) {
                        $0.selectionDisabled()
                    } else { $0 }
                }
            }
        }
        .navigationTitle("Subsidized Pricing")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack {
                OnboardingPrimaryButton(title: hasViewedFreeModeUpsell ? "Continue Without Trying Discounts" : "Skip Discounts", systemImage: nil, controlSize: .regular) {
                    hasSeenOnboarding = true
                    hasRespondedToOnboarding = true
                    isPresentingSheet = false
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .modifier {
                    if hasViewedFreeModeUpsell {
                        $0.buttonStyle(.bordered)
                    } else {
                        $0.buttonStyle(.borderless)
                    }
                }
                
                OnboardingPrimaryButton(title: "Check Discount Qualification", systemImage: nil, controlSize: .regular) {
#if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
                    isPresentingStoreSheet.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
            .padding()
            .background(.regularMaterial)
        }
    }
}

#if DEBUG
struct OnboardingFreeModeView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFreeModeView(
            highlightedProduct: nil,
            isPresentingSheet: .constant(false),
            isPresentingStoreSheet: .constant(false)
        )
    }
}
#endif
