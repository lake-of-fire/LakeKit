import SwiftUI
import SwiftUIX
import NavigationBackport
import MarkdownWebView
import Pow

public struct OnboardingCard: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let color: Color
    public let description: String
    public let imageName: String
    public let breakoutCard: Bool

    public init(id: String, title: String, color: Color, description: String, imageName: String, breakoutCard: Bool = false) {
        self.id = id
        self.title = title
        self.color = color
        self.description = description
        self.imageName = imageName
        self.breakoutCard = breakoutCard
    }
}

fileprivate struct PrimaryButton: View {
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
        
    @ViewBuilder private func primaryButtonLabel(title: String, systemImage: String?) -> some View {
        Group {
            if let systemImage = systemImage {
                Label(title, systemImage: systemImage)
                    .labelStyle(.iconOnly)
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
        .frame(maxWidth: .infinity)
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
                $0.controlSize(controlSize)
            } else if #available(iOS 17, macOS 14, *) {
                $0.controlSize(.extraLarge)
            } else {
                $0.controlSize(.large)
            }
        }
    }
}

struct OnboardingPrimaryButtons: View {
    let isFinishedOnboarding: Bool
    @Binding var isPresentingSheet: Bool
    @Binding var isPresentingStoreSheet: Bool
    @Binding var navigationPath: NBNavigationPath
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false

    @EnvironmentObject private var storeViewModel: StoreViewModel
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    var body: some View {
        if storeViewModel.isSubscribed {
            PrimaryButton(title: isFinishedOnboarding ? "Continue" : "Skip Onboarding", systemImage: nil) {
                hasSeenOnboarding = true
                isPresentingSheet = false
            }
            .tint(isFinishedOnboarding ? .accentColor : .secondary)
            .buttonStyle(.borderedProminent)
        } else {
            VStack {
                Button {
                    isPresentingStoreSheet.toggle()
                } label: {
                    VStack {
                        Text("As low as $0.99 per month")
                            .font(.headline)
                        Text("$0.99/month or $9.99/year US with discount")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .modifier {
                    if #available(iOS 17, macOS 14, *) {
                        $0.controlSize(.extraLarge)
                    } else {
                        $0.controlSize(.large)
                    }
                }
                .padding(.horizontal)
#if os(iOS)
                .padding(.vertical, (horizontalSizeClass == .compact ? 0: nil) as CGFloat?)
#endif

                PrimaryButton(title: "Continue to Upgrades", systemImage: nil) {
                    isPresentingStoreSheet.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .conditionalEffect(
                    .repeat(
                        .shine.delay(0.75),
                        every: 4
                    ),
                    condition: isFinishedOnboarding)
            }
            
            PrimaryButton(title: "Skip Upgrades", systemImage: nil) {
                navigationPath.removeLast(navigationPath.count)
                navigationPath.append("free-mode")
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }
}

struct OnboardingCardsView<CardContent: View>: View {
    let cards: [OnboardingCard]
    @Binding var isPresentingSheet: Bool
    @Binding var isFinished: Bool
    @Binding var navigationPath: NBNavigationPath
    @Binding var isPresentingStoreSheet: Bool
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent
    
    @State private var scrolledID: String?

//    private var cardMinHeight: CGFloat = 330
    private var cardHeightFactor: CGFloat {
#if os(iOS)
        if isPortrait {
            return 0.75
        }
#endif
        return 0.85
    }

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
    @Environment(\.userInterfaceIdiom) private var userInterfaceIdiom
#endif
    @ScaledMetric(relativeTo: .body) private var maxCardWidth: CGFloat = 500
    @ScaledMetric(relativeTo: .body) private var maxCardHeight: CGFloat = 580

    private var isPortrait: Bool {
#if os(iOS)
        return horizontalSizeClass == .compact || userInterfaceIdiom != .phone
#elseif os(macOS)
        return true
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
            VStack {
//                Text(" ")
//                
//                let frameHeight: CGFloat = (cardHeightFactor * geometry.insetAdjustedSize.height).rounded()
//                let paddingVertical: CGFloat = (((1 - cardHeightFactor) / 2) * geometry.insetAdjustedSize.height).rounded()
//                let frameHeight: CGFloat = (cardHeightFactor * geometry.size.height).rounded()
                let paddingVertical: CGFloat = (((1 - cardHeightFactor) / 6) * geometry.size.height).rounded()
                let frameHeight: CGFloat = geometry.size.height - (paddingVertical * 2)
                OnboardingCardView(card: card, isFinished: $isFinished, isTopVisible: scrolledID == card.id, cardContent: cardContent)
//                    .padding(.horizontal, 20)
                    .frame(idealHeight: frameHeight)
                    .frame(maxWidth: maxCardWidth, maxHeight: maxCardHeight)
                    .padding(12)
                    .padding(.top, paddingVertical)
//                    .padding(.bottom, paddingVertical)
//
//                Text(" ")
            }
//            .frame(maxWidth: geometry.insetAdjustedSize.width)
            .frame(width: geometry.insetAdjustedSize.width)
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
    
    @ViewBuilder private var scrollView: some View {
        ZStack {
            ZStack {
                ForEach(cards, id: \.id) { card in
                    Group {
                        if #available(iOS 16, macOS 13, *) {
                            Rectangle()
                                .fill(card.color.gradient.opacity(0.75))
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
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always)) // always needed for top alignment for some reason
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
                        Group {
//                            scrollViewHeader()
//                            scrollViewFooter(wheelGeometry: wheelGeometry)
                            scrollViewInner(geometry: wheelGeometry)
                        }
                        .padding(.horizontal)
                    }
                }
                .background(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            if #available(iOS 17, macOS 14, *) {
                VStack {
                    PageNavigator(scrolledID: $scrolledID, cards: cards)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
            }
        }
    }
    
    @ViewBuilder private var callToActionView: some View {
        VStack {
            OnboardingPrimaryButtons(isFinishedOnboarding: scrolledID == cards.last?.id, isPresentingSheet: $isPresentingSheet, isPresentingStoreSheet: $isPresentingStoreSheet, navigationPath: $navigationPath)
        }
        .padding()
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
            scrollView
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    callToActionView
                        .background(.regularMaterial)
                }
#elseif os(iOS)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if !isPortrait {
                        callToActionView
                            .frame(maxHeight: .infinity)
                            .background(.regularMaterial)
                    }
                    scrollView
                        .frame(width: !isPortrait ? 0.666 * geometry.insetAdjustedSize.width : nil)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isPortrait {
                    callToActionView
                        .background(.regularMaterial)
                }
            }
#endif
        }
        .onAppear {
            scrolledID = "welcome"
        }
    }
    
    init(cards: [OnboardingCard], isPresentingSheet: Binding<Bool>, isFinished: Binding<Bool>, isPresentingStoreSheet: Binding<Bool>, navigationPath: Binding<NBNavigationPath>, cardContent: @escaping (OnboardingCard, Binding<Bool>, Bool) -> CardContent) {
        self.cards = cards
        _isPresentingSheet = isPresentingSheet
        _isFinished = isFinished
        _isPresentingStoreSheet = isPresentingStoreSheet
        _navigationPath = navigationPath
        self.cardContent = cardContent
    }
}

fileprivate struct FreeModeView: View {
    @Binding var isPresentingSheet: Bool
    @Binding var isPresentingStoreSheet: Bool
    
    @AppStorage("hasViewedFreeModeUpsell") private var hasViewedFreeModeUpsell = false
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false

    @State private var shouldAnimate = false
    
    var body: some View {
        ScrollView {
            VStack {
                Image("Onboarding - Free Mode Landscape")
                    .resizable()
                    .scaledToFit()
                MarkdownWebView("""
                **Manabi Reader helps you stay motivated while learning faster, for free.**
                
                Read from a library of curated blogs, news feeds, stories and ebooks. Tap words to look them up. Listen to spoken audio as you read.
                
                Immersion is key. Manabi Reader caters to diverse taste and skill levels. Import your own files or browse the web as you like. Reader Mode works on most anything.
                
                Immersion can be a grind too. It's brutal to spend hours reading above your level without being able to feel the progress that you're making. That's why Manabi shows you personalized stats on how familiar you already are with the vocab and kanji you encounter. Collect example sentences automatically. Chart your progress as you read in real-time.
                
                All the above is free.
                
                ## Why upgrade?
                
                The subscription personalizes your stats more to help you see what words and kanji you need to learn. Your dictionary syncs with your reading activity to filter by learning status. You get support for saving words to Manabi Flashcards or Anki.
                
                You'll also support onngoing development: Manabi is independently-made and has no external investors. Thousands of paying customers have enabled Manabi development to continue part-time since 2018 and full-time since 2022.
                
                ## Can't afford it?
                
                Equal access in education is a valuable principle that Manabi aspires toward. If you're a student or if you just can't afford the full price, please consider the discounted plan. It starts at $0.99 US per month for full access.
                
                ***Editor's Note:*** *Thank you for using Manabi Reader. Whether or not you pay to support its full-time developmnent, rest assured there is more to come for Free Mode. As the subscription tier features improve, more paid features will become free too. Manabi values accessibility for all.*
                ##
                """)
                .modifier {
                    if #available(iOS 17, macOS 14, *) {
                        $0.selectionDisabled()
                    } else { $0 }
                }
                .frame(maxWidth: 850)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Free Mode")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack {
                PrimaryButton(title: "View Discounts", systemImage: nil, controlSize: .regular) {
                    isPresentingStoreSheet.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                PrimaryButton(title: hasViewedFreeModeUpsell ? "Continue Without Trying Discounts" : "Continue Without Checking Upgrades", systemImage: nil, controlSize: .regular) {
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
            }
            .padding()
            .background(.regularMaterial)
        }
    }
}

struct OnboardingView<CardContent: View>: View {
    let cards: [OnboardingCard]
    @Binding var isPresentingSheet: Bool
    @Binding var isFinished: Bool
    @Binding var isPresentingStoreSheet: Bool
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent
    
    @State private var navigationPath = NBNavigationPath()
    
    var body: some View {
        NBNavigationStack(path: $navigationPath) {
            OnboardingCardsView(cards: cards, isPresentingSheet: $isPresentingSheet, isFinished: $isFinished, isPresentingStoreSheet: $isPresentingStoreSheet, navigationPath: $navigationPath, cardContent: cardContent)
                .nbNavigationDestination(for: String.self, destination: { dest in
                    switch dest {
                    case "free-mode":
                        FreeModeView(isPresentingSheet: $isPresentingSheet, isPresentingStoreSheet: $isPresentingStoreSheet)
                    default: EmptyView()
                    }
                })
        }
    }
    
    init(cards: [OnboardingCard], isPresentingSheet: Binding<Bool>, isFinished: Binding<Bool>, isPresentingStoreSheet: Binding<Bool>, cardContent: @escaping (OnboardingCard, Binding<Bool>, Bool) -> CardContent) {
        self.cards = cards
        _isPresentingSheet = isPresentingSheet
        _isFinished = isFinished
        _isPresentingStoreSheet = isPresentingStoreSheet
        self.cardContent = cardContent
    }
}

struct OnboardingCardView<CardContent: View>: View {
    let card: OnboardingCard
    @Binding var isFinished: Bool
    let isTopVisible: Bool
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent

    @Environment(\.colorScheme) private var colorScheme
    
    @ViewBuilder private var innerView: some View {
        VStack(spacing: 16) {
            Text(card.title)
                .font(.title2)
                .fontWeight(.heavy)
                .lineLimit(9001)
                .fixedSize(horizontal: false, vertical: true)
            
            cardContent(card, $isFinished, isTopVisible)
            
            if !card.description.isEmpty {
                Text(card.description)
                    .font(.subheadline.bold())
                    .lineLimit(9001)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
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
                        Color.systemBackground.opacity(0.9)
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
    
    @State var animateCount: Int = 0
    
    @ScaledMetric(relativeTo: .body) private var pageButtonTitleFontSize = 15
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
    
    private var canGoNext: Bool {
        return ((currentIndex ?? cards.count) + 1) < cards.count
    }

    func scrollTo(index: Int) {
        guard cards.indices.contains(index) else {
            scrolledID = nil
            return
        }
        withAnimation {
            scrolledID = cards[index].id
        }
    }
    
    @ViewBuilder private func pageTurnButton(title: String, systemImage: String, isEnabled: Bool, isAnimated: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Group {
                if #available(iOS 16.0, macOS 13, *) {
                    Label {
                        Text(title)
                            .font(.system(size: pageButtonTitleFontSize))
#if os(iOS)
                            .bold()
#endif
                    } icon: {
                        Image(systemName: systemImage)
                            .font(.system(size: pageButtonIconFontSize))
#if os(iOS)
                            .bold()
                            .modifier {
                                if #available(iOS 16.1, macOS 13.1, *) {
                                    $0
                                        .bold()
                                        .fontDesign(.rounded)
                                } else { $0 }
                            }
#endif
                    }
//                    .symbolEffect(.bounce, value: isAnimated ? animateCount : 0)
                } else {
                    Label {
                        Text(title)
                            .font(.system(size: pageButtonTitleFontSize))
#if os(iOS)
                            .bold()
#endif
                    } icon: {
                        Image(systemName: systemImage)
                            .font(.system(size: pageButtonIconFontSize))
                    }
                }
            }
            
#if os(macOS)
            .padding(6)
#endif
            .frame(minWidth: pageButtonMinHeight, minHeight: pageButtonMinHeight)
#if os(iOS)
            .padding(12)
#endif
        }
#if os(iOS)
        .buttonStyle(.borderless)
#endif
        .tint(.secondary)
        .background(.regularMaterial)
        .shadow(radius: 16)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0)
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
            indicatorView

            let canGoPrevious = canGoPrevious
            let canGoNext = canGoNext
            HStack {
                pageTurnButton(title: "Previous", systemImage: "chevron.backward", isEnabled: canGoPrevious, isAnimated: false) {
                    guard let currentIndex = currentIndex else { return }
                    scrollTo(index: currentIndex - 1)
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(Color.accentColor)
                .clipShape(.circle)

                Spacer()
                
                pageTurnButton(title: "Next", systemImage: "chevron.forward", isEnabled: canGoNext, isAnimated: true) {
                    guard let currentIndex = currentIndex else { return }
                    scrollTo(index: currentIndex + 1)
                }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(Color.accentColor)
                .clipShape(.capsule)
                .animation(.default, value: canGoNext)
                .conditionalEffect(
                    .repeat(
                        .glow(color: .systemBackground, radius: 30),
                        every: 1.75
                    ),
                    condition: canGoNext && !canGoPrevious)
            }
        }
        .padding(.horizontal)
        .onAppear {
            animateCount = 1
        }
    }
}

public struct OnboardingSheet<CardContent: View>: ViewModifier {
    let isActive: Bool
    @State var isPresentingStoreSheet = false
    let cards: [OnboardingCard]
    @ViewBuilder let cardContent: (OnboardingCard, Binding<Bool>, Bool) -> CardContent

    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    @State private var isPresented = false
    @State private var isFinished = false

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                OnboardingView(cards: cards, isPresentingSheet: $isPresented, isFinished: $isFinished, isPresentingStoreSheet: $isPresentingStoreSheet, cardContent: cardContent)
#if os(macOS)
                    .frame(idealWidth: 450, idealHeight: 600)
#endif
                    .onDisappear {
                        if !hasRespondedToOnboarding {
                            hasSeenOnboarding = true
                        }
                    }
                    .storeSheet(isPresented: $isPresentingStoreSheet && isActive)
                // TODO: track onDisappear (after tracking onAppear to make sure it was seen for long enough too) timestamp as last seen date in AppStorage to avoid re-showing onboarding within seconds or minute of last seeing it again. Avoids annoying the user.
            }
            .onAppear {
                refresh()
            }
            .onChange(of: isActive) { isActive in
                refresh(isActive: isActive)
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
    
    private func refresh(isActive: Bool? = nil, hasRespondedToOnboarding: Bool? = nil, hasSeenOnboarding: Bool? = nil) {
        let isActive = isActive ?? self.isActive
        let hasRespondedToOnboarding = hasRespondedToOnboarding ?? self.hasRespondedToOnboarding
        let hasSeenOnboarding = hasSeenOnboarding ?? self.hasSeenOnboarding
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            isPresented = isActive && !(hasRespondedToOnboarding || hasSeenOnboarding)
        }
    }
}

public extension View {
    func onboardingSheet(isActive: Bool = true, cards: [OnboardingCard], cardContent: @escaping (OnboardingCard, Binding<Bool>, Bool) -> some View) -> some View {
        self.modifier(OnboardingSheet(isActive: isActive, cards: cards, cardContent: cardContent))
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
