import SwiftUI
import StoreHelper
import SwiftUtilities
import NavigationBackport
import Pow
#if os(iOS)
import UIKit
#endif

public struct OnboardingCard: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let color: Color
    public let description: String
    public let imageName: String
    public let breakoutCard: Bool
    public let requiredActionID: String?
    public let requiredActionTitle: String?
    public let requiredActionSystemImage: String?
    public let usesTightVerticalSpacing: Bool
    public let contentUsesFullWidth: Bool

    public init(
        id: String,
        title: String,
        color: Color,
        description: String,
        imageName: String,
        breakoutCard: Bool = false,
        requiredActionID: String? = nil,
        requiredActionTitle: String? = nil,
        requiredActionSystemImage: String? = nil,
        usesTightVerticalSpacing: Bool = false,
        contentUsesFullWidth: Bool = false
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.description = description
        self.imageName = imageName
        self.breakoutCard = breakoutCard
        self.requiredActionID = requiredActionID
        self.requiredActionTitle = requiredActionTitle
        self.requiredActionSystemImage = requiredActionSystemImage
        self.usesTightVerticalSpacing = usesTightVerticalSpacing
        self.contentUsesFullWidth = contentUsesFullWidth
    }
}

internal struct OnboardingPrimaryButton: View {
    let title: String
    let systemImage: String?
    let controlSize: ControlSize?
    let action: () -> Void
    
    init(title: String, systemImage: String?, controlSize: ControlSize? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.controlSize = controlSize
        self.action = action
    }
        
#if os(iOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif
    
    @ViewBuilder private func primaryButtonLabel(title: String, systemImage: String?) -> some View {
        Group {
            if let systemImage = systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
#if os(iOS)
        .modifier {
            if #available(iOS 16.1, macOS 13.1, *) {
                $0
                    .font(.headline)
                    .bold()
            } else {$0 }
        }
        .frame(maxWidth: 850)
#endif
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            primaryButtonLabel(title: title, systemImage: systemImage)
        }
#if os(iOS)
        .font(.headline)
#endif
        .frame(maxWidth: .infinity)
        .modifier {
            if let controlSize = controlSize {
                return $0.controlSize(controlSize)
            } else {
#if os (iOS)
                if verticalSizeClass == .compact {
                    return $0.controlSize(.regular)
                }
#endif
                if #available(iOS 17, macOS 14, *) {
                    return $0.controlSize(.extraLarge)
                } else {
                    return $0.controlSize(.large)
                }
            }
        }
    }
}

private struct OnboardingCategoryPressScaleModifier: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .brightness(isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.05), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

struct OnboardingPrimaryButtons: View {
    let currentCard: OnboardingCard?
    let isFinishedOnboarding: Bool
    let canAdvanceOnboarding: Bool
    let hasCompletedRequiredAction: Bool
    let advanceOnboarding: () -> Void
    let performRequiredAction: (@escaping () -> Void) -> Void
    let skipRequiredAction: () -> Void
    @Binding var isPresentingSheet: Bool
    @Binding var isPresentingStoreSheet: Bool
    @Binding var navigationPath: [String]

    @State private var highlightedProduct: PrePurchaseSubscriptionInfo?
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    @EnvironmentObject private var storeViewModel: StoreViewModel
    @EnvironmentObject private var storeHelper: StoreHelper
    @ObservedObject private var adsViewModel = AdsViewModel.shared
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif

    private var headlineText: String {
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
                @unknown default: renewalString += "period"
                }
                if renewalPeriod.value > 1 {
                    renewalString += "s"
                }
            }
            return "As low as " + highlightedProduct.purchasePrice + " " + renewalString
        }
        return ""
    }

    private var shouldOfferFreeModePath: Bool {
#if DEBUG
        return !canAdvanceOnboarding
#else
        return !canAdvanceOnboarding && adsViewModel.showAds
#endif
    }

    private var isWaitingForRequiredAction: Bool {
        currentCard?.requiredActionID != nil && !hasCompletedRequiredAction
    }

    @ViewBuilder
    private func subscriptionButton() -> some View {
        Button {
            isPresentingStoreSheet.toggle()
        } label: {
            VStack {
                Text(headlineText)
                    .font(.footnote)
                    .bold()
                    .task { @MainActor in
                        highlightedProduct = await storeViewModel.productSubscriptionInfo(productID: storeViewModel.highlightedProductID, storeHelper: storeHelper)
                    }
                Text("With qualifying discounts")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .controlSize(.large)
        .padding(.horizontal)
#if os(iOS)
        .padding(.vertical, (horizontalSizeClass == .compact ? 0: 5) as CGFloat?)
#endif
    }
    
    @ViewBuilder
    private func requiredActionButton() -> some View {
        OnboardingPrimaryButton(
            title: currentCard?.requiredActionTitle ?? "Continue",
            systemImage: currentCard?.requiredActionSystemImage
        ) {
#if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
            performRequiredAction {}
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .modifier(OnboardingCategoryPressScaleModifier())
    }

    @ViewBuilder
    private func skipRequiredActionButton() -> some View {
        Button {
#if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
            skipRequiredAction()
        } label: {
            Text("Skip")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
        }
        .controlSize(.regular)
        .modifier { button in
            if #available(iOS 26, macOS 26, *) {
                button.buttonStyle(.glass(.clear))
            } else {
                button.buttonStyle(.bordered)
            }
        }
        .buttonBorderShape(.capsule)
    }

    @ViewBuilder
    private func continueButton() -> some View {
        OnboardingPrimaryButton(title: "Continue", systemImage: nil) {
#if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
            if canAdvanceOnboarding {
                advanceOnboarding()
            } else {
                hasSeenOnboarding = true
                hasRespondedToOnboarding = true
#if DEBUG
                isPresentingStoreSheet = true
#else
                if adsViewModel.showAds {
                    isPresentingStoreSheet = true
                } else {
                    isPresentingSheet = false
                }
#endif
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .modifier(OnboardingCategoryPressScaleModifier())
        .conditionalEffect(
            .repeat(
                .shine.delay(0.75),
                every: 4
            ),
            condition: isFinishedOnboarding
        )
    }

    @ViewBuilder
    private func subsidizedOptionsButton() -> some View {
        OnboardingPrimaryButton(
            title: "Skip Upgrades",
            systemImage: nil
        ) {
            navigationPath.removeLast(navigationPath.count)
            navigationPath.append("free-mode")
        }
        .modifier { button in
            if #available(iOS 26, macOS 26, *) {
                button.buttonStyle(.glass(.clear))
            } else {
                button.buttonStyle(.bordered)
            }
        }
        .background {
            Color.white.opacity(0.0000000001)
                .edgesIgnoringSafeArea(.all)
        }
    }
    
    @ViewBuilder
    private func buttonsStack() -> some View {
#if os(iOS)
        if verticalSizeClass == .compact {
            HStack {
                if isWaitingForRequiredAction {
                    requiredActionButton()
                } else {
                    continueButton()
                }
            }
        } else {
            VStack {
                if isWaitingForRequiredAction {
                    requiredActionButton()
                } else {
                    continueButton()
                }
            }
        }
#else
        VStack {
            if isWaitingForRequiredAction {
                requiredActionButton()
            } else {
                continueButton()
            }
        }
#endif
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if isWaitingForRequiredAction {
                skipRequiredActionButton()
            } else if shouldOfferFreeModePath {
                subsidizedOptionsButton()
            }
            buttonsStack()
        }
    }
}

struct OnboardingCardsView<CardContent: View, RequiredActionContent: View>: View {
    let cards: [OnboardingCard]
    @Binding var isPresentingSheet: Bool
    @Binding var isFinished: Bool
    @Binding var navigationPath: [String]
    @Binding var isPresentingStoreSheet: Bool
    let onSkipOnboarding: () -> Void
    let onRequiredAction: (OnboardingCard, @escaping () -> Void) -> Void
    @ViewBuilder let requiredActionContent: (OnboardingCard) -> RequiredActionContent
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent
    
    @State private var scrolledID: String?
    @State private var completedRequiredActionIDs: Set<String> = []
    @State private var presentedRequiredActionCard: OnboardingCard?
    @State private var pendingRequiredActionID: String?

    private var appName: String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
        
    private var currentCard: OnboardingCard? {
        guard let scrolledID = scrolledID else { return nil }
        return cards.first(where: { $0.id == scrolledID })
    }
    
    @Environment(\.colorScheme) private var colorScheme
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.userInterfaceIdiom) private var userInterfaceIdiom
#endif
    @ScaledMetric(relativeTo: .body) private var maxCardWidth: CGFloat = 500

    private var isPortrait: Bool {
#if os(iOS)
        return (horizontalSizeClass == .compact && verticalSizeClass == .regular) || userInterfaceIdiom != .phone
#elseif os(macOS)
        return true
#endif
    }

    private var isPhone: Bool {
#if os(iOS)
        return userInterfaceIdiom == .phone
#elseif os(macOS)
        return false
#endif
    }
    
    @ViewBuilder private func scrollViewHeader() -> some View {
        Group {
            if let appName = appName {
                Text(
            """
            Welcome to
            \(Text(appName).foregroundColor(.accentColor))
            """
                )
            }
        }
        .font(.largeTitle.weight(.heavy))
        .multilineTextAlignment(.center)
        .padding()
    }
    
    @ViewBuilder private func scrollViewInner(geometry: GeometryProxy) -> some View {
        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
            let frameHeight = cardFrameHeight(for: geometry.size)
            VStack {
                OnboardingCardView(card: card, isFinished: $isFinished, isTopVisible: scrolledID == card.id, cardContent: cardContent)
                    .frame(height: frameHeight)
                    .frame(maxWidth: maxCardWidth)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: geometry.size.height)
            .onSwipe { direction in
                guard let currentIndex = cards.firstIndex(where: { $0.id == scrolledID }) else { return }
                withAnimation {
                    switch direction {
                    case .left:
                        guard currentIndex < (cards.count - 1) else { return }
                        scrolledID = cards[currentIndex + 1].id
                    case .right:
                        guard currentIndex > 0 else { return }
                        scrolledID = cards[currentIndex - 1].id
                    default: break
                    }
                }
            }
//            .id(card.id)
        }
    }
        
//    @ViewBuilder private func scrollViewFooter(wheelGeometry: GeometryProxy) -> some View {
//        Color.clear.frame(height: max(0, cardHeightFactor * wheelGeometry.size.height  - wheelGeometry.safeAreaInsets.top - wheelGeometry.safeAreaInsets.bottom))
//    }

    private func cardFrameHeight(for size: CGSize) -> CGFloat {
        let verticalInset: CGFloat = 30
        let minimumHeight = min(360, max(220, size.height - verticalInset * 2))
        return max(minimumHeight, size.height - verticalInset * 2).rounded()
    }
    
    @ViewBuilder private var scrollViewContent: some View {
        ZStack {
            ZStack {
                ForEach(cards, id: \.id) { card in
                    Group {
                        if #available(iOS 16, macOS 13, *) {
                            Rectangle()
                                .fill(card.color.gradient.opacity(0.75))
                                .overlay {
                                    Rectangle()
                                        .fill(Color.black.gradient.opacity(0.2))
                                }
                        } else {
                            card.color
                        }
                    }
                    .opacity(scrolledID == card.id ? 1 : 0)
                    .animation(.easeIn, value: scrolledID)
                }
            }
            .ignoresSafeArea()
            
            if #available(iOS 17, macOS 14, *) {
                GeometryReader { wheelGeometry in
                    WheelScroll(axis: .vertical, contentSpacing: 40) {
                        scrollViewInner(geometry: wheelGeometry)
                    }
                    .scrollPosition(id: $scrolledID)
//                    .scrollClipDisabled()
                    .modifier { content in
                        if scrolledID == nil {
                            content
                        } else {
                            content.scrollTargetBehavior(.viewAligned(limitBehavior: .always)) // always needed for top alignment for some reason
                        }
                    }
                    .onAppear {
                        scrolledID = cards.first?.id
                    }
                    .onChange(of: scrolledID) { scrolledID in
                        isFinished = scrolledID == cards.last?.id
                    }
                }
            } else {
                GeometryReader { wheelGeometry in
                    ScrollView {
                        VStack {
                            scrollViewInner(geometry: wheelGeometry)
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var topChrome: some View {
        if #available(iOS 17, macOS 14, *) {
            ZStack(alignment: .leading) {
                PageNavigator(scrolledID: $scrolledID, cards: cards)
                    .frame(maxWidth: .infinity)

                if isPhone && scrolledID == cards.first?.id {
                    Button {
                        onSkipOnboarding()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Dismiss onboarding")
                    .buttonStyle(.borderless)
                    .tint(.primary)
                    .background(.regularMaterial, in: Circle())
                    .padding(.leading, 16)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder private var scrollView: some View {
        if #available(iOS 26, macOS 26, *) {
            scrollViewContent
                .safeAreaBar(edge: .top, spacing: 0) {
                    topChrome
                }
        } else {
            scrollViewContent
                .safeAreaInset(edge: .top, spacing: 0) {
                    topChrome
                }
        }
    }
    
    @ViewBuilder private var callToActionView: some View {
        VStack {
            OnboardingPrimaryButtons(
                currentCard: currentCard,
                isFinishedOnboarding: scrolledID == cards.last?.id,
                canAdvanceOnboarding: canAdvanceOnboarding,
                hasCompletedRequiredAction: hasCompletedRequiredAction,
                advanceOnboarding: advanceOnboarding,
                performRequiredAction: performRequiredAction,
                skipRequiredAction: skipRequiredAction,
                isPresentingSheet: $isPresentingSheet,
                isPresentingStoreSheet: $isPresentingStoreSheet,
                navigationPath: $navigationPath
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
    var body: some View {
        ZStack {
            if let currentColor = currentCard?.color {
                Group {
                    if #available(iOS 16, macOS 13, *) {
                        Rectangle()
                            .fill(currentColor.gradient)
                    } else {
                        currentColor
                    }
                }
                .ignoresSafeArea()
            }
            
#if os(macOS)
            if #available(macOS 26, *) {
                scrollView
                    .safeAreaBar(edge: .bottom, spacing: 0) {
                        callToActionView
                    }
            } else {
                scrollView
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        callToActionView
                    }
            }
#elseif os(iOS)
            if #available(iOS 26, *) {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        if !isPortrait {
                            callToActionView
                                .frame(maxHeight: .infinity)
                        }
                        scrollView
                            .frame(width: !isPortrait ? 0.666 * geometry.insetAdjustedSize.width : nil)
                    }
                }
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    if isPortrait {
                        callToActionView
                    }
                }
            } else {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        if !isPortrait {
                            callToActionView
                                .frame(maxHeight: .infinity)
                        }
                        scrollView
                            .frame(width: !isPortrait ? 0.666 * geometry.insetAdjustedSize.width : nil)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isPortrait {
                        callToActionView
                    }
                }
            }
#endif
        }
        .onAppear {
            scrolledID = "welcome"
        }
        .sheet(item: $presentedRequiredActionCard, onDismiss: completePresentedRequiredAction) { card in
            requiredActionContent(card)
        }
    }

    private var currentIndex: Int? {
        guard let scrolledID else { return nil }
        return cards.firstIndex(where: { $0.id == scrolledID })
    }

    private var canAdvanceOnboarding: Bool {
        guard let currentIndex else { return false }
        return currentIndex < cards.count - 1
    }

    private var hasCompletedRequiredAction: Bool {
        guard let requiredActionID = currentCard?.requiredActionID else { return true }
        return completedRequiredActionIDs.contains(requiredActionID)
    }

    private func advanceOnboarding() {
        guard let currentIndex, currentIndex < cards.count - 1 else { return }
        withAnimation {
            scrolledID = cards[currentIndex + 1].id
        }
    }

    private func performRequiredAction(_ fallbackCompletion: @escaping () -> Void) {
        guard let currentCard, let requiredActionID = currentCard.requiredActionID else {
            fallbackCompletion()
            return
        }
        onRequiredAction(currentCard) {
            pendingRequiredActionID = requiredActionID
            presentedRequiredActionCard = currentCard
            fallbackCompletion()
        }
    }

    private func completePresentedRequiredAction() {
        if let pendingRequiredActionID {
            completedRequiredActionIDs.insert(pendingRequiredActionID)
            self.pendingRequiredActionID = nil
        }
    }

    private func skipRequiredAction() {
        if let requiredActionID = currentCard?.requiredActionID {
            completedRequiredActionIDs.insert(requiredActionID)
        }
        advanceOnboarding()
    }
    
    init(
        cards: [OnboardingCard],
        isPresentingSheet: Binding<Bool>,
        isFinished: Binding<Bool>,
        isPresentingStoreSheet: Binding<Bool>,
        navigationPath: Binding<[String]>,
        onSkipOnboarding: @escaping () -> Void,
        onRequiredAction: @escaping (OnboardingCard, @escaping () -> Void) -> Void,
        requiredActionContent: @escaping (OnboardingCard) -> RequiredActionContent,
        cardContent: @escaping (OnboardingCard, Binding<Bool>, Bool) -> CardContent
    ) {
        self.cards = cards
        _isPresentingSheet = isPresentingSheet
        _isFinished = isFinished
        _isPresentingStoreSheet = isPresentingStoreSheet
        _navigationPath = navigationPath
        self.onSkipOnboarding = onSkipOnboarding
        self.onRequiredAction = onRequiredAction
        self.requiredActionContent = requiredActionContent
        self.cardContent = cardContent
    }
}


struct OnboardingView<CardContent: View, RequiredActionContent: View>: View {
    let cards: [OnboardingCard]
    @Binding var isPresentingSheet: Bool
    @Binding var isFinished: Bool
    @Binding var isPresentingStoreSheet: Bool
    let onSkipOnboarding: () -> Void
    let onRequiredAction: (OnboardingCard, @escaping () -> Void) -> Void
    @ViewBuilder let requiredActionContent: (OnboardingCard) -> RequiredActionContent
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent
    
    @EnvironmentObject private var storeViewModel: StoreViewModel
    @EnvironmentObject private var storeHelper: StoreHelper

    @State private var navigationPath = [String]()
    @State private var highlightedProduct: PrePurchaseSubscriptionInfo?

    @ViewBuilder private var onboardingCardsView: some View {
        OnboardingCardsView(
            cards: cards,
            isPresentingSheet: $isPresentingSheet,
            isFinished: $isFinished,
            isPresentingStoreSheet: $isPresentingStoreSheet,
            navigationPath: $navigationPath,
            onSkipOnboarding: onSkipOnboarding,
            onRequiredAction: onRequiredAction,
            requiredActionContent: requiredActionContent,
            cardContent: cardContent
        )
        .modifier {
            if #available(iOS 16, macOS 13, *) {
                $0.navigationDestination(
                    for: String.self,
                    destination: { dest in
                        switch dest {
                        case "free-mode":
                            OnboardingFreeModeView(
                                highlightedProduct: highlightedProduct,
                                isPresentingSheet: $isPresentingSheet,
                                isPresentingStoreSheet: $isPresentingStoreSheet
                            )
                    default: EmptyView()
                    }
                })
            } else {
                $0.nbNavigationDestination(
                    for: String.self,
                    destination: { dest in
                        switch dest {
                        case "free-mode":
                            OnboardingFreeModeView(
                                highlightedProduct: highlightedProduct,
                                isPresentingSheet: $isPresentingSheet,
                                isPresentingStoreSheet: $isPresentingStoreSheet
                            )
                    default: EmptyView()
                    }
                })
            }
        }
#if os(iOS)
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task { @MainActor in
            highlightedProduct = await storeViewModel.productSubscriptionInfo(productID: storeViewModel.highlightedProductID, storeHelper: storeHelper)
        }
    }
    
    var body: some View {
        if #available(iOS 16, macOS 13, *) {
            NavigationStack(path: $navigationPath) {
                onboardingCardsView
            }
        } else {
            NBNavigationStack(path: $navigationPath) {
                onboardingCardsView
            }
        }
    }
    
    init(
        cards: [OnboardingCard],
        isPresentingSheet: Binding<Bool>,
        isFinished: Binding<Bool>,
        isPresentingStoreSheet: Binding<Bool>,
        onSkipOnboarding: @escaping () -> Void,
        onRequiredAction: @escaping (OnboardingCard, @escaping () -> Void) -> Void,
        requiredActionContent: @escaping (OnboardingCard) -> RequiredActionContent,
        cardContent: @escaping (OnboardingCard, Binding<Bool>, Bool) -> CardContent
    ) {
        self.cards = cards
        _isPresentingSheet = isPresentingSheet
        _isFinished = isFinished
        _isPresentingStoreSheet = isPresentingStoreSheet
        self.onSkipOnboarding = onSkipOnboarding
        self.onRequiredAction = onRequiredAction
        self.requiredActionContent = requiredActionContent
        self.cardContent = cardContent
    }
}

struct OnboardingCardView<CardContent: View>: View {
    let card: OnboardingCard
    @Binding var isFinished: Bool
    let isTopVisible: Bool
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent

    @Environment(\.colorScheme) private var colorScheme
#if os(iOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif
    
    private var useVStack: Bool {
#if os(iOS)
        return verticalSizeClass == .regular
#else
        return true
#endif
    }

    @ViewBuilder private var headlineText: some View {
        Text(card.title)
            .font(.headline)
            .lineLimit(9001)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder private var headlineView: some View {
        if card.breakoutCard {
            GroupBox {
                headlineText
//                    .padding(.horizontal)
            }
        } else {
            headlineText
        }
    }

    @ViewBuilder private var cardContentView: some View {
        cardContent(card, $isFinished, isTopVisible)
    }
    
    @ViewBuilder private var subheadlineView: some View {
        if !card.description.isEmpty {
            Text(card.description)
                .font(.subheadline)
                .lineLimit(9001)
                .fixedSize(horizontal: false, vertical: true)
            //                    .foregroundStyle(.secondary)
//                .padding(.horizontal)
        }
    }
    
    @ViewBuilder private var innerView: some View {
        Group {
            if useVStack {
                if card.usesTightVerticalSpacing {
                    VStack(spacing: 8) {
                        headlineView
                        cardContentView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        subheadlineView
                    }
                } else {
                    VStack(spacing: 16) {
                        headlineView
                        Spacer(minLength: 8)
                        cardContentView
                        Spacer(minLength: 8)
                        subheadlineView
                    }
                }
            } else {
                HStack(spacing: 16) {
                    VStack(spacing: 16) {
                        headlineView
                        Spacer(minLength: 8)
                        subheadlineView
                    }
                    cardContentView
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(card.breakoutCard ? 0 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        Group {
            if card.breakoutCard {
                innerView
            } else {
                innerView
                    .background {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.secondarySystemBackground,
                                            Color.secondarySystemBackground.opacity(0.86),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.systemBackground.opacity(0.9),
                                            Color.systemBackground.opacity(0.76),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .cornerRadius(16)
                    .scaleEffect(isTopVisible ? 1 : 0.92)
                    .shadow(radius: isTopVisible ? 16 : 8)
                    .animation(.easeInOut, value: isTopVisible)
            }
        }
    }
}

//@available(iOS 15, macOS 14, *)
fileprivate struct PageNavigator: View {
    @Binding var scrolledID: String?
    let cards: [OnboardingCard]
    
    @ScaledMetric(relativeTo: .body) private var pageButtonIconFontSize = 15
#if os(iOS)
    @ScaledMetric(relativeTo: .body) private var pageButtonMinHeight = 22
#elseif os(macOS)
    @ScaledMetric(relativeTo: .body) private var pageButtonMinHeight = 26
#endif

    private var currentIndex: Int? {
        guard let scrolledID = scrolledID else { return nil }
        return cards.firstIndex(where: { $0.id == scrolledID })
    }
    
    private var canGoPrevious: Bool {
        return (currentIndex ?? -1) > 0
    }
    
    private func scrollTo(index: Int) {
        guard cards.indices.contains(index) else {
            scrolledID = nil
            return
        }
        withAnimation {
            scrolledID = cards[index].id
        }
    }
    
    @ViewBuilder private func pageTurnButton(title: String, systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: pageButtonIconFontSize, weight: .bold))
                .modifier {
                    if #available(iOS 16.1, macOS 13.1, *) {
                        $0.fontDesign(.rounded)
                    } else {
                        $0
                    }
                }
                .accessibilityLabel(title)
#if os(macOS)
            .padding(6)
#endif
            .frame(minWidth: pageButtonMinHeight, minHeight: pageButtonMinHeight)
#if os(iOS)
            .padding(12)
#endif
        }
        .buttonStyle(.borderless)
        .tint(.primary)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.0001)
        .allowsHitTesting(isEnabled)
    }

    @ViewBuilder private var indicatorView: some View {
        HStack(spacing: 0) {
            ForEach(0..<cards.count, id: \.self) { index in
                Circle()
                    .fill(.primary)
                    .opacity(index == currentIndex ? 1 : 0.4)
                    .frame(width: 7, height: 7)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 4)
                    .background(.white.opacity(0.00000000001))
                    .onTapGesture {
                        scrollTo(index: index)
                    }
            }
        }
        .padding(.horizontal, 5)
        .background(.regularMaterial)
        .clipShape(.capsule)
    }
    
    var body: some View {
        ZStack {
            if currentIndex != nil {
                indicatorView
            }

            let canGoPrevious = canGoPrevious
            HStack {
                pageTurnButton(title: "Back", systemImage: "chevron.left", isEnabled: canGoPrevious) {
                    guard let currentIndex = currentIndex else { return }
                    scrollTo(index: currentIndex - 1)
                }
                .foregroundStyle(.primary)
                .clipShape(.circle)

                Spacer()

                Color.clear
                    .frame(width: pageButtonMinHeight, height: pageButtonMinHeight)
#if os(iOS)
                    .padding(12)
#endif
            }
        }
        .padding(.horizontal)
    }
}

public struct OnboardingSheet<CardContent: View, RequiredActionContent: View>: ViewModifier {
    let isActive: Bool
    @State var isPresentingStoreSheet = false
    let cards: [OnboardingCard]
    let onRequiredAction: (OnboardingCard, @escaping () -> Void) -> Void
    @ViewBuilder let requiredActionContent: (OnboardingCard) -> RequiredActionContent
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent

    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    @State private var isPresented = false
    @State private var isFinished = false
    @State private var didSkipOnboardingThisSession = false
#if os(iOS)
    @Environment(\.userInterfaceIdiom) private var userInterfaceIdiom
#endif

    @ViewBuilder
    private var onboardingPresentationContent: some View {
        OnboardingView(
            cards: cards,
            isPresentingSheet: $isPresented,
            isFinished: $isFinished,
            isPresentingStoreSheet: $isPresentingStoreSheet,
            onSkipOnboarding: skipOnboarding,
            onRequiredAction: onRequiredAction,
            requiredActionContent: requiredActionContent,
            cardContent: cardContent
        )
#if os(macOS)
        .frame(idealWidth: 450, idealHeight: 600)
#endif
        .modifier {
            if #available(iOS 18, macOS 15, *) {
                $0
                    .presentationSizing(.page)
            } else { $0 }
        }
        .storeSheet(isPresented: $isPresentingStoreSheet)
    }

    public func body(content: Content) -> some View {
        content
            .modifier { content in
#if os(iOS)
                if userInterfaceIdiom == .phone {
                    content.fullScreenCover(isPresented: $isPresented.gatedBy(isActive)) {
                        onboardingPresentationContent
                            .interactiveDismissDisabled()
                    }
                } else {
                    content.sheet(isPresented: $isPresented.gatedBy(isActive)) {
                        onboardingPresentationContent
                    }
                }
#elseif os(macOS)
                content.sheet(isPresented: $isPresented.gatedBy(isActive)) {
                    onboardingPresentationContent
                }
#endif
            }
            .onAppear {
                refresh()
            }
            .onChange(of: hasSeenOnboarding) { hasSeenOnboarding in
                refresh(hasSeenOnboarding: hasSeenOnboarding)
            }
            .onChange(of: hasRespondedToOnboarding) { hasRespondedToOnboarding in
                refresh(hasRespondedToOnboarding: hasRespondedToOnboarding)
            }
            .onChange(of: isPresented) { isPresented in
                if !isPresented && !hasRespondedToOnboarding {
                    hasSeenOnboarding = true
                }
            }
    }
    
    private func refresh(hasRespondedToOnboarding: Bool? = nil, hasSeenOnboarding: Bool? = nil) {
        let hasRespondedToOnboarding = hasRespondedToOnboarding ?? self.hasRespondedToOnboarding
        let hasSeenOnboarding = hasSeenOnboarding ?? self.hasSeenOnboarding
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard isActive else {
                didSkipOnboardingThisSession = false
                isPresented = false
                return
            }
#if DEBUG
            isPresented = !didSkipOnboardingThisSession
#else
            isPresented = !(hasRespondedToOnboarding || hasSeenOnboarding)
#endif
        }
    }

    private func skipOnboarding() {
        didSkipOnboardingThisSession = true
        hasSeenOnboarding = true
        hasRespondedToOnboarding = true
        isPresented = false
    }
}

public extension View {
    func onboardingSheet(
        isActive: Bool,
        cards: [OnboardingCard],
        onRequiredAction: @escaping (OnboardingCard, @escaping () -> Void) -> Void,
        requiredActionContent: @escaping (OnboardingCard) -> some View,
        cardContent: @escaping (OnboardingCard, Binding<Bool>, Bool) -> some View
    ) -> some View {
        self.modifier(
            OnboardingSheet(
                isActive: isActive,
                cards: cards,
                onRequiredAction: onRequiredAction,
                requiredActionContent: requiredActionContent,
                cardContent: cardContent
            )
        )
    }

    func onboardingSheet(
        isActive: Bool,
        cards: [OnboardingCard],
        cardContent: @escaping (OnboardingCard, Binding<Bool>, Bool) -> some View
    ) -> some View {
        onboardingSheet(
            isActive: isActive,
            cards: cards,
            onRequiredAction: { _, complete in complete() },
            requiredActionContent: { _ in EmptyView() },
            cardContent: cardContent
        )
    }
}

// From: https://stackoverflow.com/questions/60885532/how-to-detect-swiping-up-down-left-and-right-with-swiftui-on-a-view
fileprivate typealias SwipeDirectionAction = (SwipeDirection) -> Void

fileprivate extension View {
    /// Adds an action to perform when swipe end.
    /// - Parameters:
    ///   - action: The action to perform when this swipe ends.
    ///   - minimumDistance: The minimum dragging distance for the gesture to succeed.
    func onSwipe(action: @escaping SwipeDirectionAction, minimumDistance: Double = 20) -> some View {
        self
            .gesture(DragGesture(minimumDistance: minimumDistance, coordinateSpace: .global)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    if abs(horizontalAmount) > abs(verticalAmount) {
                        horizontalAmount < 0 ? action(.left) : action(.right)
                    } else {
                        verticalAmount < 0 ? action(.up) : action(.bottom)
                    }
                })
    }
}

fileprivate enum SwipeDirection {
    case up, bottom, left, right
}
