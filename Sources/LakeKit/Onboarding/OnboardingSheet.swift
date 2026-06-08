import Foundation
import SwiftUI
import StoreHelper
import SwiftUtilities
import NavigationBackport
import Pow
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import CoreGraphics

public struct OnboardingIntroFeature: Identifiable, Hashable {
    public let systemImage: String
    public let headline: String
    public let subheadline: String

    public var id: String {
        systemImage + "|" + headline
    }

    public init(systemImage: String, headline: String, subheadline: String) {
        self.systemImage = systemImage
        self.headline = headline
        self.subheadline = subheadline
    }
}

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
    public let contentFillsCard: Bool
    public let isFullScreenIntro: Bool
    public let primaryActionTitle: String?
    public let introFeatures: [OnboardingIntroFeature]
    public let introHeroImageName: String?
    public let cardVerticalInset: CGFloat?
    public let forcedColorScheme: ColorScheme?

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
        contentUsesFullWidth: Bool = false,
        contentFillsCard: Bool = false,
        isFullScreenIntro: Bool = false,
        primaryActionTitle: String? = nil,
        introFeatures: [OnboardingIntroFeature] = [],
        introHeroImageName: String? = nil,
        cardVerticalInset: CGFloat? = nil,
        forcedColorScheme: ColorScheme? = nil
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
        self.contentFillsCard = contentFillsCard
        self.isFullScreenIntro = isFullScreenIntro
        self.primaryActionTitle = primaryActionTitle
        self.introFeatures = introFeatures
        self.introHeroImageName = introHeroImageName
        self.cardVerticalInset = cardVerticalInset
        self.forcedColorScheme = forcedColorScheme
    }
}

private struct OnboardingGrainOverlay: View {
    private static let grainImage: CGImage? = makeGrainImage(size: 160)

    @Environment(\.colorScheme) private var colorScheme

    private var opacity: Double {
        colorScheme == .dark ? 0.18 : 0.24
    }

    var body: some View {
        if let grainImage = Self.grainImage {
            Image(decorative: grainImage, scale: 1)
                .resizable(resizingMode: .tile)
                .blendMode(.softLight)
                .opacity(opacity)
                .allowsHitTesting(false)
        }
    }

    private static func makeGrainImage(size: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = size * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: size * bytesPerRow)

        for y in 0..<size {
            for x in 0..<size {
                let coordsX = Double(x) / Double(size)
                let coordsY = Double(y) / Double(size)
                let source = (coordsX + 4) * (coordsY + 4) * 10
                let grain = (fmod((fmod(source, 13) + 1) * (fmod(source, 123) + 1), 0.01) - 0.005) * 16
                let alpha = UInt8(min(max(abs(grain) * 860, 0), 42))
                let value: UInt8 = grain >= 0 ? 255 : 0
                let premultipliedValue = UInt8((Int(value) * Int(alpha) + 127) / 255)
                let index = (y * bytesPerRow) + (x * bytesPerPixel)

                pixels[index] = premultipliedValue
                pixels[index + 1] = premultipliedValue
                pixels[index + 2] = premultipliedValue
                pixels[index + 3] = alpha
            }
        }

        let data = Data(pixels)
        guard let dataProvider = CGDataProvider(data: data as CFData) else { return nil }

        return CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
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
    var glows = false
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .brightness(isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.05), value: isPressed)
            .conditionalEffect(.repeat(.glow(color: .accentColor, radius: 50), every: 2.25), condition: glows && !isPressed)
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
    var glowsPrimaryAction = false
    var showsPrimaryAction = true
    var primaryActionTransition: AnyTransition = .move(edge: .bottom).combined(with: .opacity)

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

    private var isCompletedWidgetRequiredAction: Bool {
        currentCard?.requiredActionID == "add-widget" && hasCompletedRequiredAction
    }

    private var shouldShowRequiredActionSkip: Bool {
        isWaitingForRequiredAction || isCompletedWidgetRequiredAction
    }

    private var continueButtonTitle: String {
        currentCard?.primaryActionTitle ?? "Continue"
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
    private func completedWidgetRequiredActionButton() -> some View {
        OnboardingPrimaryButton(title: "Finished Adding Widget", systemImage: nil) {
#if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
            advanceOnboarding()
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .modifier(OnboardingCategoryPressScaleModifier(glows: glowsPrimaryAction))
        .shadow(color: .black.opacity(0.26), radius: 18, x: 0, y: 10)
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
                .foregroundStyle(.secondary)
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
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func continueButton() -> some View {
        OnboardingPrimaryButton(title: continueButtonTitle, systemImage: nil) {
#if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
            if canAdvanceOnboarding {
                advanceOnboarding()
            } else {
#if DEBUG
                isPresentingStoreSheet = true
#else
                if adsViewModel.showAds {
                    isPresentingStoreSheet = true
                } else {
                    hasSeenOnboarding = true
                    hasRespondedToOnboarding = true
                    isPresentingSheet = false
                }
#endif
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .modifier(OnboardingCategoryPressScaleModifier(glows: glowsPrimaryAction))
        .shadow(color: .black.opacity(0.26), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private func subsidizedOptionsButton() -> some View {
        Button {
            navigationPath.removeLast(navigationPath.count)
            navigationPath.append("free-mode")
        } label: {
            Text("Skip Upgrades")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
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
        .environment(\.colorScheme, .dark)
    }
    
    @ViewBuilder
    private func buttonsStack() -> some View {
#if os(iOS)
        if verticalSizeClass == .compact {
            HStack {
                if isWaitingForRequiredAction {
                    requiredActionButton()
                } else if isCompletedWidgetRequiredAction {
                    completedWidgetRequiredActionButton()
                } else {
                    continueButton()
                }
            }
        } else {
            VStack {
                if isWaitingForRequiredAction {
                    requiredActionButton()
                } else if isCompletedWidgetRequiredAction {
                    completedWidgetRequiredActionButton()
                } else {
                    continueButton()
                }
            }
        }
#else
        VStack {
            if isWaitingForRequiredAction {
                requiredActionButton()
            } else if isCompletedWidgetRequiredAction {
                completedWidgetRequiredActionButton()
            } else {
                continueButton()
            }
        }
#endif
    }
    
    var body: some View {
        let shouldReserveRequiredActionSkip = currentCard?.requiredActionID != nil

        VStack(spacing: 13) {
            if shouldReserveRequiredActionSkip {
                skipRequiredActionButton()
                    .opacity(shouldShowRequiredActionSkip ? 1 : 0)
                    .accessibilityHidden(!shouldShowRequiredActionSkip)
                    .allowsHitTesting(shouldShowRequiredActionSkip)
            } else if shouldOfferFreeModePath {
                subsidizedOptionsButton()
            }
            if showsPrimaryAction {
                buttonsStack()
                    .transition(primaryActionTransition)
            }
        }
    }
}

private struct OnboardingCardPageTransitionModifier: ViewModifier {
    let offsetY: CGFloat
    let opacity: Double
    let tiltDegrees: Double
    let scale: CGFloat
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(tiltDegrees),
                axis: (x: 1, y: 0, z: 0),
                anchor: offsetY >= 0 ? .top : .bottom,
                perspective: offsetY >= 0 ? -0.3 : 0.3
            )
            .scaleEffect(scale)
            .blur(radius: blurRadius)
            .opacity(opacity)
            .offset(y: offsetY)
    }
}

private struct IntroFeatureRowWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension Notification.Name {
    static let onboardingFullScreenIntroVideoReady = Notification.Name("ManabiReaderOnboardingIntroVideoReady")
}

struct OnboardingCardsView<CardContent: View, RequiredActionContent: View>: View {
    let cards: [OnboardingCard]
    @Binding var isPresentingSheet: Bool
    @Binding var isFinished: Bool
    @Binding var navigationPath: [String]
    @Binding var isPresentingStoreSheet: Bool
    @Binding var scrolledID: String?
    let onSkipOnboarding: () -> Void
    let onRequiredAction: (OnboardingCard, @escaping () -> Void) -> Void
    @ViewBuilder let requiredActionContent: (OnboardingCard) -> RequiredActionContent
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent
    
    @State private var transitionDirection: Double = 1
    @State private var completedRequiredActionIDs: Set<String> = []
    @State private var presentedRequiredActionCard: OnboardingCard?
    @State private var pendingRequiredActionID: String?
    @State private var isConfirmingSkipPersonalization = false
    @State private var isPresentingWidgetSkipAlert = false
    @State private var introFeatureRowWidth: CGFloat = 0
    @State private var isFullScreenIntroVideoReady = false
    @State private var visibleIntroFeatureCount = 0
    @State private var isIntroHeroHeaderVisible = false
    @State private var isIntroDescriptionVisible = false
    @State private var isIntroPrimaryButtonVisible = false
    @State private var isIntroPrimaryButtonGlowing = false
    @State private var introTitleShineCount = 0
    @State private var hasPlayedFullScreenIntroAnimation = false
    @State private var introFeatureAnimationTask: Task<Void, Never>?

    private var currentCard: OnboardingCard? {
        guard let scrolledID = scrolledID else { return nil }
        return cards.first(where: { $0.id == scrolledID })
    }

    private var wheelCards: [OnboardingCard] {
        cards.filter { !$0.isFullScreenIntro }
    }

    private var isShowingFullScreenIntro: Bool {
        currentCard?.isFullScreenIntro == true
    }

    private var shouldGateFullScreenIntro: Bool {
        isShowingFullScreenIntro && !isFullScreenIntroVideoReady
    }

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

    private var shouldCenterIntroDescription: Bool {
#if os(iOS)
        horizontalSizeClass == .regular
#elseif os(macOS)
        false
#endif
    }
    
    @ViewBuilder private func cardPageView(geometry: GeometryProxy) -> some View {
        if #available(iOS 17, macOS 14, *) {
            cardScrollPageView(geometry: geometry)
        } else {
            fallbackCardPageView(geometry: geometry)
        }
    }

    @available(iOS 17, macOS 14, *)
    @ViewBuilder private func cardScrollPageView(geometry: GeometryProxy) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(wheelCards, id: \.id) { card in
                    let frameHeight = cardFrameHeight(for: geometry.size, card: card)
                    let isCurrentPage = scrolledID == card.id

                    OnboardingCardView(
                        card: card,
                        isFinished: $isFinished,
                        isTopVisible: isCurrentPage,
                        cardContent: cardContent
                    )
                    .frame(height: frameHeight)
                    .frame(maxWidth: maxCardWidth)
                    .padding(.horizontal, 12)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id(card.id)
                    .scrollTransition(.interactive(timingCurve: .easeInOut), axis: .vertical) { content, phase in
                        cardScrollTransition(content, phase: phase)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolledID)
        .scrollIndicators(.hidden)
        .scrollDisabled(true)
        .onSwipe { direction in
            switch direction {
            case .left:
                advanceOnboarding()
            case .right:
                selectPreviousCard()
            default:
                break
            }
        }
    }

    @available(iOS 17, macOS 14, *)
    nonisolated private func cardScrollTransition(_ content: EmptyVisualEffect, phase: ScrollTransitionPhase) -> some VisualEffect {
        let progress = min(abs(phase.value), 1)
        let scale = 1 + (0.075 * progress)
        let fadeInProgress = max(0, (0.82 - progress) / 0.82)
        let opacity = fadeInProgress * fadeInProgress
        let blur = 0.75 * progress
        let tilt = -8 * phase.value
        let exitOffset = phase.value * 160 * progress

        return content
            .rotation3DEffect(
                .degrees(tilt),
                axis: (x: 1, y: 0, z: 0),
                anchor: phase.value >= 0 ? .top : .bottom,
                perspective: phase.value >= 0 ? -0.25 : 0.25
            )
            .scaleEffect(scale)
            .blur(radius: blur)
            .offset(y: exitOffset)
            .opacity(opacity)
    }

    @ViewBuilder private func fallbackCardPageView(geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(currentCard.map { [$0] } ?? [], id: \.id) { currentCard in
                let frameHeight = cardFrameHeight(for: geometry.size, card: currentCard)

                OnboardingCardView(
                    card: currentCard,
                    isFinished: $isFinished,
                    isTopVisible: true,
                    cardContent: cardContent
                )
                .frame(height: frameHeight)
                .frame(maxWidth: maxCardWidth)
                .padding(.horizontal, 12)
                .id(currentCard.id)
                .transition(cardPageTransition(for: geometry.size))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onSwipe { direction in
            switch direction {
            case .left:
                advanceOnboarding()
            case .right:
                selectPreviousCard()
            default:
                break
            }
        }
    }

    private func cardPageTransition(for size: CGSize) -> AnyTransition {
        let travel = max(300, size.height * 0.86)
        let insertionOffset = transitionDirection >= 0 ? travel : -travel
        let removalOffset = transitionDirection >= 0 ? -travel : travel
        let insertionScale: CGFloat = 1.075
        let insertionTilt = transitionDirection >= 0 ? -8.0 : 8.0
        let removalScale: CGFloat = 0.92
        let removalTilt = transitionDirection >= 0 ? 12.0 : -12.0

        return .asymmetric(
            insertion: .modifier(
                active: OnboardingCardPageTransitionModifier(
                    offsetY: insertionOffset,
                    opacity: 0.82,
                    tiltDegrees: insertionTilt,
                    scale: insertionScale,
                    blurRadius: 0
                ),
                identity: OnboardingCardPageTransitionModifier(
                    offsetY: 0,
                    opacity: 1,
                    tiltDegrees: 0,
                    scale: 1,
                    blurRadius: 0
                )
            ),
            removal: .modifier(
                active: OnboardingCardPageTransitionModifier(
                    offsetY: removalOffset,
                    opacity: 0,
                    tiltDegrees: removalTilt,
                    scale: removalScale,
                    blurRadius: 0.6
                ),
                identity: OnboardingCardPageTransitionModifier(
                    offsetY: 0,
                    opacity: 1,
                    tiltDegrees: 0,
                    scale: 1,
                    blurRadius: 0
                )
            )
        )
    }

    private func cardFrameHeight(for size: CGSize, card: OnboardingCard) -> CGFloat {
        let verticalInset = card.cardVerticalInset ?? 22
        let minimumHeight = min(360, max(220, size.height - verticalInset * 2))
        return max(minimumHeight, size.height - verticalInset * 2).rounded()
    }

    @ViewBuilder private func backgroundLayer(for color: Color) -> some View {
        if #available(iOS 16, macOS 13, *) {
            Rectangle()
                .fill(color.gradient.opacity(0.75))
                .saturation(0.9)
                .overlay {
                    Rectangle()
                        .fill(Color.black.gradient.opacity(0.55))
                }
                .overlay {
                    OnboardingGrainOverlay()
                }
        } else {
            color
                .saturation(0.9)
                .overlay {
                    Color.black.opacity(0.4)
                }
        }
    }
    
    @ViewBuilder private var pagerContent: some View {
        ZStack {
            if isShowingFullScreenIntro, let currentCard {
                if shouldGateFullScreenIntro {
                    cardContent(currentCard, $isFinished, true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .opacity(0)
                        .allowsHitTesting(false)

                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                } else {
                    cardContent(currentCard, $isFinished, true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()

                    GeometryReader { geometry in
                        let topBoundary = geometry.safeAreaInsets.top + 50
                        let bottomBoundary = geometry.safeAreaInsets.bottom + 176
                        let centeredY = topBoundary + max(0, geometry.size.height - topBoundary - bottomBoundary) / 2

                        introHeroContent
                            .position(x: geometry.size.width / 2, y: centeredY)
                    }
                    .ignoresSafeArea()
                }
            } else {
                ZStack {
                    ForEach(cards, id: \.id) { card in
                        backgroundLayer(for: card.color)
                        .compositingGroup()
                        .opacity(scrolledID == card.id ? 1 : 0)
                        .animation(.easeIn, value: scrolledID)
                    }
                }
                .ignoresSafeArea()

                GeometryReader { wheelGeometry in
                    cardPageView(geometry: wheelGeometry)
                }
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: scrolledID) { scrolledID in
            isFinished = scrolledID == cards.last?.id
        }
    }

    @ViewBuilder private var topChrome: some View {
        if shouldGateFullScreenIntro {
            EmptyView()
        } else if isShowingFullScreenIntro {
            introTopChrome
        } else if #available(iOS 17, macOS 14, *) {
            ZStack(alignment: .leading) {
                PageNavigator(scrolledID: $scrolledID, cards: cards) { id in
                    selectCard(id)
                }
                .frame(maxWidth: .infinity)

                if isPhone && scrolledID == cards.first?.id {
                    Button {
                        isConfirmingSkipPersonalization = true
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
        }
    }

    private var introTopChrome: some View {
        ZStack(alignment: .leading) {
            Button {
                isConfirmingSkipPersonalization = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Dismiss onboarding")
            .buttonStyle(.borderless)
            .tint(.white)
            .background(.black.opacity(0.34), in: Circle())
            .opacity(isIntroDescriptionVisible ? 1 : 0)
            .animation(.easeInOut(duration: 1.4), value: isIntroDescriptionVisible)
            .accessibilityHidden(!isIntroDescriptionVisible)
            .allowsHitTesting(isIntroDescriptionVisible)
            .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var introHeroContent: some View {
        VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading, spacing: 10) {
                if let imageName = currentCard?.introHeroImageName {
                    introHeroIcon(imageName: imageName)
                        .opacity(isIntroHeroHeaderVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 1.0), value: isIntroHeroHeaderVisible)
                }

                Text(currentCard?.title ?? "")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(-8)
                    .shadow(color: .black.opacity(1), radius: 26, y: 6)
                    .shadow(color: .black.opacity(0.72), radius: 6, y: 3)
                    .changeEffect(.shine, value: introTitleShineCount)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: IntroFeatureRowWidthPreferenceKey.self,
                                value: geometry.size.width
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isIntroHeroHeaderVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 1.0), value: isIntroHeroHeaderVisible)
            }

            if !(currentCard?.introFeatures ?? []).isEmpty {
                introFeatureList
                    .shadow(color: .black.opacity(0.74), radius: 18, y: 5)
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var introFeatureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(currentIntroFeatures.enumerated()), id: \.element.id) { index, feature in
                if index < visibleIntroFeatureCount {
                    HStack(alignment: .center, spacing: 12) {
                        introFeatureIcon(systemImage: feature.systemImage)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.headline)
                                .font(.callout.weight(.bold))

                            Text(feature.subheadline)
                                .font(.footnote.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(
                        minWidth: introFeatureRowWidth > 0 ? introFeatureRowWidth : nil,
                        alignment: .leading
                    )
                    .modifier { row in
                        if #available(iOS 26, macOS 26, *) {
                            row.glassEffect(.regular.tint(Color(white: 0.3)), in: Capsule())
                        } else {
                            row.background(.regularMaterial, in: Capsule())
                        }
                    }
                    .transition(.movingParts.glare)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.movingParts.easeInExponential(duration: 0.64), value: visibleIntroFeatureCount)
        .onPreferenceChange(IntroFeatureRowWidthPreferenceKey.self) { width in
            introFeatureRowWidth = min(width.rounded(.up), 560)
        }
        .animation(.movingParts.easeInExponential(duration: 0.64), value: visibleIntroFeatureCount)
        .frame(maxWidth: 560, alignment: .leading)
    }

    private func introFeatureIcon(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.body.weight(.bold))
            .imageScale(.large)
            .foregroundStyle(Color.accentColor)
            .frame(width: 28, height: 28)
            .padding(6)
            .shadow(color: .black.opacity(0.46), radius: 8, x: 0, y: 4)
            .shadow(color: Color.accentColor.opacity(0.34), radius: 10, x: 0, y: 0)
    }

    private func introHeroIcon(imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 70, height: 70)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.48), radius: 18, x: 0, y: 10)
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
    }

    @ViewBuilder private var pagerView: some View {
        if #available(iOS 26, macOS 26, *) {
            pagerContent
                .safeAreaBar(edge: .top, spacing: 0) {
                    topChrome
                }
        } else {
            pagerContent
                .safeAreaInset(edge: .top, spacing: 0) {
                    topChrome
                }
        }
    }

    private var currentIntroFeatures: [OnboardingIntroFeature] {
        currentCard?.introFeatures ?? []
    }

    @ViewBuilder
    private func primaryButtonsView(
        primaryActionTransition: AnyTransition,
        showsPrimaryAction: Bool = true
    ) -> some View {
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
            navigationPath: $navigationPath,
            glowsPrimaryAction: isShowingFullScreenIntro && isIntroPrimaryButtonGlowing,
            showsPrimaryAction: showsPrimaryAction,
            primaryActionTransition: primaryActionTransition
        )
    }
    
    @ViewBuilder private var callToActionView: some View {
        if shouldGateFullScreenIntro {
            EmptyView()
        } else {
            let introRevealTransition = AnyTransition
                .offset(y: 15)
                .combined(with: .opacity)

            VStack(alignment: .center, spacing: isShowingFullScreenIntro ? 10 : 0) {
                if isShowingFullScreenIntro,
                   let description = currentCard?.description,
                   !description.isEmpty,
                   isIntroDescriptionVisible {
                    Text(description)
                        .frame(maxWidth: 560, alignment: shouldCenterIntroDescription ? .center : .leading)
                        .padding(.horizontal, 8)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(shouldCenterIntroDescription ? .center : .leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.88), radius: 20, y: 5)
                        .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
                        .transition(introRevealTransition)
                }

                if isShowingFullScreenIntro {
                    primaryButtonsView(primaryActionTransition: .identity)
                        .compositingGroup()
                        .opacity(isIntroPrimaryButtonVisible ? 1 : 0)
                        .offset(y: isIntroPrimaryButtonVisible ? 0 : 15)
                        .allowsHitTesting(isIntroPrimaryButtonVisible)
                        .accessibilityHidden(!isIntroPrimaryButtonVisible)
                } else {
                    primaryButtonsView(primaryActionTransition: .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) {
                if isShowingFullScreenIntro && isIntroDescriptionVisible {
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.58),
                            .black.opacity(0.74),
                            .black.opacity(0.88),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 240)
                    .padding(.horizontal, -1000)
                    .padding(.bottom, -80)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 1.4), value: isIntroDescriptionVisible)
            .animation(.easeInOut(duration: 1.4), value: isIntroPrimaryButtonVisible)
        }
    }
    var body: some View {
        ZStack {
            if let currentColor = currentCard?.color {
                backgroundLayer(for: currentColor)
                    .ignoresSafeArea()
            }
            
#if os(macOS)
            if #available(macOS 26, *) {
                pagerView
                    .safeAreaBar(edge: .bottom, spacing: 0) {
                        callToActionView
                    }
            } else {
                pagerView
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        callToActionView
                    }
            }
#elseif os(iOS)
            if #available(iOS 26, *) {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        if !isPortrait && !isShowingFullScreenIntro {
                            callToActionView
                                .frame(maxHeight: .infinity)
                        }
                        pagerView
                            .frame(width: (!isPortrait && !isShowingFullScreenIntro) ? 0.666 * geometry.insetAdjustedSize.width : nil)
                    }
                }
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    if isPortrait || isShowingFullScreenIntro {
                        callToActionView
                    }
                }
            } else {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        if !isPortrait && !isShowingFullScreenIntro {
                            callToActionView
                                .frame(maxHeight: .infinity)
                        }
                        pagerView
                            .frame(width: (!isPortrait && !isShowingFullScreenIntro) ? 0.666 * geometry.insetAdjustedSize.width : nil)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isPortrait || isShowingFullScreenIntro {
                        callToActionView
                    }
                }
            }
#endif
        }
        .onAppear {
            ensureInitialScrolledID()
            scheduleIntroFeatureAnimationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingFullScreenIntroVideoReady)) { _ in
            isFullScreenIntroVideoReady = true
            withAnimation(.easeInOut(duration: 1.0)) {
                isIntroHeroHeaderVisible = true
            }
            scheduleIntroFeatureAnimationIfNeeded()
        }
        .onChange(of: currentCard?.id) { _ in
            introFeatureAnimationTask?.cancel()
            introFeatureAnimationTask = nil
            hasPlayedFullScreenIntroAnimation = false
            isIntroHeroHeaderVisible = !isShowingFullScreenIntro
            isIntroDescriptionVisible = false
            isIntroPrimaryButtonVisible = false
            isIntroPrimaryButtonGlowing = false
            introTitleShineCount = 0
            visibleIntroFeatureCount = isShowingFullScreenIntro ? 0 : currentIntroFeatures.count
            isFullScreenIntroVideoReady = !isShowingFullScreenIntro
            scheduleIntroFeatureAnimationIfNeeded()
        }
        .onDisappear {
            introFeatureAnimationTask?.cancel()
            introFeatureAnimationTask = nil
        }
        .sheet(item: $presentedRequiredActionCard, onDismiss: completePresentedRequiredAction) { card in
            requiredActionContent(card)
        }
        .alert("Skip Personalization?", isPresented: $isConfirmingSkipPersonalization) {
            Button("Cancel", role: .cancel) {}
            Button("Skip", role: .destructive) {
                onSkipOnboarding()
            }
        }
        .alert("Adding Widgets Later", isPresented: $isPresentingWidgetSkipAlert) {
            if #available(iOS 26, macOS 26, *) {
                Button(role: .confirm) {
                    completeSkippedRequiredAction()
                } label: {
                    Text("Got It")
                }
            } else {
                Button("Got It") {
                    completeSkippedRequiredAction()
                }
            }
        } message: {
            Text("You can view the widget gallery and instructions for adding widgets in the in-app Reader Settings.")
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

    private func ensureInitialScrolledID() {
        if let scrolledID, cards.contains(where: { $0.id == scrolledID }) {
            isFinished = scrolledID == cards.last?.id
            return
        }

        scrolledID = cards.first?.id
        isFinished = scrolledID == cards.last?.id
    }

    private func scheduleIntroFeatureAnimationIfNeeded() {
        let featureCount = currentIntroFeatures.count
        guard isShowingFullScreenIntro else {
            introFeatureAnimationTask?.cancel()
            introFeatureAnimationTask = nil
            visibleIntroFeatureCount = featureCount
            isIntroHeroHeaderVisible = true
            isIntroDescriptionVisible = false
            isIntroPrimaryButtonVisible = true
            isIntroPrimaryButtonGlowing = false
            introTitleShineCount = 0
            return
        }

        guard isFullScreenIntroVideoReady else {
            introFeatureAnimationTask?.cancel()
            introFeatureAnimationTask = nil
            visibleIntroFeatureCount = 0
            isIntroHeroHeaderVisible = false
            isIntroDescriptionVisible = false
            isIntroPrimaryButtonVisible = false
            isIntroPrimaryButtonGlowing = false
            introTitleShineCount = 0
            return
        }

        if introFeatureAnimationTask != nil {
            return
        }

        guard !hasPlayedFullScreenIntroAnimation else {
            visibleIntroFeatureCount = currentIntroFeatures.count
            isIntroHeroHeaderVisible = true
            isIntroDescriptionVisible = true
            isIntroPrimaryButtonVisible = true
            return
        }

        hasPlayedFullScreenIntroAnimation = true
        visibleIntroFeatureCount = 0
        if !isIntroHeroHeaderVisible {
            withAnimation(.easeInOut(duration: 1.0)) {
                isIntroHeroHeaderVisible = true
            }
        }
        isIntroDescriptionVisible = false
        isIntroPrimaryButtonVisible = false
        isIntroPrimaryButtonGlowing = false
        introTitleShineCount = 0
        guard featureCount > 0 else { return }
        introFeatureAnimationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_050_000_000)
            guard !Task.isCancelled else { return }
            introTitleShineCount += 1

            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }

            for count in 1...featureCount {
                withAnimation(.movingParts.easeInExponential(duration: 0.64)) {
                    visibleIntroFeatureCount = count
                }

                if count < featureCount {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    guard !Task.isCancelled else { return }
                }
            }

            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.4)) {
                isIntroDescriptionVisible = true
                isIntroPrimaryButtonVisible = true
            }

            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            isIntroPrimaryButtonGlowing = true
        }
    }

    private func selectCard(_ id: String) {
        guard cards.contains(where: { $0.id == id }) else { return }
        let currentIndex = currentIndex ?? cards.startIndex
        let nextIndex = cards.firstIndex(where: { $0.id == id }) ?? currentIndex
        transitionDirection = nextIndex >= currentIndex ? 1 : -1

        withAnimation(.spring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.04)) {
            scrolledID = id
        }
    }

    private func selectPreviousCard() {
        guard let currentIndex, currentIndex > cards.startIndex else { return }
        selectCard(cards[currentIndex - 1].id)
    }

    private func advanceOnboarding() {
        guard let currentIndex, currentIndex < cards.count - 1 else { return }
        let nextID = cards[currentIndex + 1].id
        selectCard(nextID)
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
        if currentCard?.id == "widgets", !hasCompletedRequiredAction {
            isPresentingWidgetSkipAlert = true
            return
        }

        completeSkippedRequiredAction()
    }

    private func completeSkippedRequiredAction() {
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
        scrolledID: Binding<String?>,
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
        _scrolledID = scrolledID
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
    @State private var selectedCardID: String?
    @State private var highlightedProduct: PrePurchaseSubscriptionInfo?
    @State private var hasPresentedStoreSheet = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasRespondedToOnboarding") private var hasRespondedToOnboarding = false

    private var isShowingLastCard: Bool {
        isFinished || selectedCardID == cards.last?.id
    }

    @ViewBuilder private var onboardingCardsView: some View {
        OnboardingCardsView(
            cards: cards,
            isPresentingSheet: $isPresentingSheet,
            isFinished: $isFinished,
            isPresentingStoreSheet: $isPresentingStoreSheet,
            navigationPath: $navigationPath,
            scrolledID: $selectedCardID,
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
        .onChange(of: isPresentingStoreSheet) { isPresentingStoreSheet in
            if isPresentingStoreSheet {
                hasPresentedStoreSheet = true
            } else {
                closeOnboardingIfSubscribedAfterStoreDismissal()
            }
        }
    }

    private func closeOnboardingIfSubscribedAfterStoreDismissal() {
        guard hasPresentedStoreSheet, isShowingLastCard else { return }

        Task { @MainActor in
            storeViewModel.refreshIsSubscribed(storeHelper: storeHelper)
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard hasPresentedStoreSheet, isShowingLastCard else { return }
            guard storeViewModel.isSubscribed || storeViewModel.isSubscribedFromElsewhere || !AdsViewModel.shared.showAds else { return }

            hasSeenOnboarding = true
            hasRespondedToOnboarding = true
            isPresentingSheet = false
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
#if os(iOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
#endif
    @State private var entranceProgress: CGFloat = 1
    @State private var lightWipeProgress: CGFloat = 1
    
    private var useVStack: Bool {
#if os(iOS)
        return verticalSizeClass == .regular
#else
        return true
#endif
    }

    @ViewBuilder private var headlineText: some View {
        Text(card.title)
            .font(.title3.bold())
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

    private var hasDescription: Bool {
        !card.description.isEmpty
    }

    private var effectiveColorScheme: ColorScheme {
        card.forcedColorScheme ?? colorScheme
    }

    private var fullBleedTitleGradientColor: Color {
        effectiveColorScheme == .dark ? .black : .white
    }

    private var fullBleedTitleGradient: some View {
        LinearGradient(
            stops: [
                .init(color: fullBleedTitleGradientColor.opacity(0.62), location: 0),
                .init(color: fullBleedTitleGradientColor.opacity(0.48), location: 0.45),
                .init(color: fullBleedTitleGradientColor.opacity(0), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 150)
        .allowsHitTesting(false)
    }

    private var fullBleedTitleForeground: Color {
        effectiveColorScheme == .dark ? .white : .black
    }

    private var fullBleedTitleShadow: Color {
        effectiveColorScheme == .dark ? .black.opacity(0.45) : .white.opacity(0.5)
    }
    
    @ViewBuilder private var innerView: some View {
        Group {
            if card.contentFillsCard {
                ZStack(alignment: .top) {
                    cardContentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    fullBleedTitleGradient

                    VStack(spacing: 0) {
                        headlineView
                            .foregroundStyle(fullBleedTitleForeground)
                            .shadow(color: fullBleedTitleShadow, radius: 8, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        Spacer(minLength: 0)

                        if hasDescription {
                            subheadlineView
                                .foregroundStyle(fullBleedTitleForeground)
                                .shadow(color: fullBleedTitleShadow, radius: 8, y: 2)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                    }
                }
            } else if useVStack {
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
                        if hasDescription {
                            Spacer(minLength: 8)
                            subheadlineView
                        }
                    }
                }
            } else {
                HStack(spacing: 16) {
                    VStack(spacing: 16) {
                        headlineView
                        Spacer(minLength: 8)
                        if hasDescription {
                            subheadlineView
                        }
                    }
                    cardContentView
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardPadding: EdgeInsets {
        guard !card.breakoutCard else { return EdgeInsets() }
        if card.contentFillsCard {
            return EdgeInsets()
        }
        if card.contentUsesFullWidth {
            return EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16)
        }
        return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    }

    private var entranceTiltDegrees: Double {
        guard isTopVisible, !reduceMotion else { return 0 }
        return -7 * Double(1 - entranceProgress)
    }

    private var lightWipeOffsetFactor: CGFloat {
        1.08 - (1.78 * lightWipeProgress)
    }

    @ViewBuilder private var entranceLightWipe: some View {
        if isTopVisible && !reduceMotion {
            GeometryReader { geometry in
	                LinearGradient(
	                    stops: [
	                        .init(color: Color.white.opacity(0), location: 0),
	                        .init(color: Color.white.opacity(0.08), location: 0.36),
	                        .init(color: Color.white.opacity(0.18), location: 0.5),
	                        .init(color: Color.white.opacity(0.07), location: 0.64),
	                        .init(color: Color.white.opacity(0), location: 1),
	                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: max(120, geometry.size.height * 0.46))
                .blur(radius: 10)
                .offset(y: geometry.size.height * lightWipeOffsetFactor)
                .blendMode(.plusLighter)
                .opacity(lightWipeProgress >= 0.995 ? 0 : 1)
            }
            .allowsHitTesting(false)
        }
    }

    private func runEntranceEffect() {
        guard isTopVisible, !reduceMotion else {
            entranceProgress = 1
            lightWipeProgress = 1
            return
        }

        entranceProgress = 0
        lightWipeProgress = 0

        withAnimation(.spring(response: 0.48, dampingFraction: 0.84, blendDuration: 0.05)) {
            entranceProgress = 1
        }
	        withAnimation(.easeOut(duration: 0.45)) {
	            lightWipeProgress = 1
	        }
    }

    var body: some View {
        Group {
            if card.breakoutCard {
                innerView
            } else {
                innerView
                    .background {
                        if effectiveColorScheme == .dark {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.secondarySystemBackground.opacity(0.85),
                                            Color.secondarySystemBackground.opacity(0.85),
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
                                            Color.systemBackground.opacity(0.85),
                                            Color.systemBackground.opacity(0.85),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    .overlay {
                        entranceLightWipe
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .rotation3DEffect(
                        .degrees(entranceTiltDegrees),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.55
                    )
                    .scaleEffect(isTopVisible ? 1 : 0.92)
                    .shadow(radius: isTopVisible ? 16 : 8)
                    .animation(.easeInOut, value: isTopVisible)
                    .onAppear {
                        if isTopVisible {
                            runEntranceEffect()
                        }
                    }
                    .onChange(of: isTopVisible) { isTopVisible in
                        if isTopVisible {
                            runEntranceEffect()
                        } else {
                            entranceProgress = 1
                            lightWipeProgress = 1
                        }
                    }
            }
        }
        .environment(\.colorScheme, effectiveColorScheme)
    }
}

//@available(iOS 15, macOS 14, *)
fileprivate struct PageNavigator: View {
    @Binding var scrolledID: String?
    let cards: [OnboardingCard]
    let onScrollRequest: (String) -> Void
    
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
        let id = cards[index].id
        onScrollRequest(id)
    }
    
    @ViewBuilder private func pageTurnButton(title: String, systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            if #available(iOS 26, macOS 26, *) {
                Image(systemName: systemImage)
                    .accessibilityLabel(title)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: pageButtonIconFontSize, weight: .bold))
                    .imageScale(.large)
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
        }
        .modifier(OnboardingChromeButtonStyleModifier())
        .tint(.secondary)
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
                .foregroundStyle(.secondary)
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

private struct OnboardingChromeButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.borderless)
        }
    }
}

public struct OnboardingSheet<CardContent: View, RequiredActionContent: View>: ViewModifier {
    let isActive: Bool
    @Binding var isPresentingStoreSheet: Bool
    let cards: [OnboardingCard]
    let onRequiredAction: (OnboardingCard, @escaping () -> Void) -> Void
    @ViewBuilder let requiredActionContent: (OnboardingCard) -> RequiredActionContent
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent

    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    @AppStorage("darkModeSetting") private var darkModeSetting = "system"
    @State private var isPresented = false
    @State private var isFinished = false
    @State private var didSkipOnboardingThisSession = false
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
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch darkModeSetting {
        case "darkModeOverride":
            return .dark
        case "alwaysLightMode":
            return .light
        default:
            return nil
        }
    }

    private var shouldBlankUnderlyingContent: Bool {
        isActive && !didSkipOnboardingThisSession && !(hasRespondedToOnboarding || hasSeenOnboarding)
    }

    @ViewBuilder
    private var onboardingDecisionBlankBackground: some View {
#if os(iOS)
        Color(uiColor: .systemBackground)
#elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color.clear
#endif
    }

    public func body(content: Content) -> some View {
        presentedContent(content)
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

    @ViewBuilder
    private func presentedContent(_ content: Content) -> some View {
#if os(iOS)
        ZStack {
            if shouldBlankUnderlyingContent {
                onboardingDecisionBlankBackground
                    .ignoresSafeArea()
            }

            content
                .opacity(shouldBlankUnderlyingContent ? 0 : 1)
                .accessibilityHidden(shouldBlankUnderlyingContent)
                .allowsHitTesting(!shouldBlankUnderlyingContent)
        }
            .fullScreenCover(isPresented: $isPresented.gatedBy(isActive)) {
                onboardingPresentationContent
                    .interactiveDismissDisabled()
            }
#elseif os(macOS)
        ZStack {
            if shouldBlankUnderlyingContent {
                onboardingDecisionBlankBackground
                    .ignoresSafeArea()
            }

            content
                .opacity(shouldBlankUnderlyingContent ? 0 : 1)
                .accessibilityHidden(shouldBlankUnderlyingContent)
                .allowsHitTesting(!shouldBlankUnderlyingContent)
        }
            .sheet(isPresented: $isPresented.gatedBy(isActive)) {
                onboardingPresentationContent
                    .frame(idealWidth: 450, idealHeight: 600)
            }
#else
        content
#endif
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
            isPresented = !(hasRespondedToOnboarding || hasSeenOnboarding)
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
        isPresentingStoreSheet: Binding<Bool> = .constant(false),
        cards: [OnboardingCard],
        onRequiredAction: @escaping (OnboardingCard, @escaping () -> Void) -> Void,
        requiredActionContent: @escaping (OnboardingCard) -> some View,
        cardContent: @escaping (OnboardingCard, Binding<Bool>, Bool) -> some View
    ) -> some View {
        self.modifier(
            OnboardingSheet(
                isActive: isActive,
                isPresentingStoreSheet: isPresentingStoreSheet,
                cards: cards,
                onRequiredAction: onRequiredAction,
                requiredActionContent: requiredActionContent,
                cardContent: cardContent
            )
        )
    }

    func onboardingSheet(
        isActive: Bool,
        isPresentingStoreSheet: Binding<Bool> = .constant(false),
        cards: [OnboardingCard],
        cardContent: @escaping (OnboardingCard, Binding<Bool>, Bool) -> some View
    ) -> some View {
        onboardingSheet(
            isActive: isActive,
            isPresentingStoreSheet: isPresentingStoreSheet,
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
