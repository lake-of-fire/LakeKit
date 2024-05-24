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
    
    public init(id: String, title: String, color: Color, description: String, imageName: String) {
        self.id = id
        self.title = title
        self.color = color
        self.description = description
        self.imageName = imageName
    }
}

fileprivate struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    
    init(title: String, systemImage: String?, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
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
            if #available(iOS 17, macOS 14, *) {
                $0.controlSize(.extraLarge)
            } else {
                $0.controlSize(.large)
            }
        }
    }
}

struct OnboardingPrimaryButtons: View {
    let isFinishedOnboarding: Bool
    @Binding var isPresentingStoreSheet: Bool
    @Binding var navigationPath: NBNavigationPath

    @EnvironmentObject private var storeViewModel: StoreViewModel
    @Environment(\.dismiss) private var dismiss
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    var body: some View {
        if storeViewModel.isSubscribed {
            PrimaryButton(title: "Continue", systemImage: nil) {
                dismiss()
            }
            .tint(.accentColor)
            .buttonStyle(.borderedProminent)
        } else {
            VStack {
                Button {
                    isPresentingStoreSheet.toggle()
                } label: {
                    VStack {
                        Text("As low as $1 per month")
                            .font(.headline)
                        Text("$1 US per month or $10 US per year with discount")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
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
                        .shine.delay(0.5),
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
    @Binding var navigationPath: NBNavigationPath
    @Binding var isPresentingStoreSheet: Bool
    @ViewBuilder let cardContent: (OnboardingCard) -> CardContent
    
    @State private var scrolledID: String?

//    private var cardMinHeight: CGFloat = 330
    private var cardHeightFactor: CGFloat {
#if os(iOS)
        if horizontalSizeClass == .compact {
            return 0.75
        }
#endif
        return 0.8
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
#endif

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
                Text(" ")
                
//                let frameHeight: CGFloat = (cardHeightFactor * geometry.insetAdjustedSize.height).rounded()
//                let paddingVertical: CGFloat = (((1 - cardHeightFactor) / 2) * geometry.insetAdjustedSize.height).rounded()
                let frameHeight: CGFloat = (cardHeightFactor * geometry.size.height).rounded()
                let paddingVertical: CGFloat = (((1 - cardHeightFactor) / 4) * geometry.size.height).rounded()
                OnboardingCardView(card: card, isTopVisible: scrolledID == card.id, cardContent: cardContent)
                    .padding(.horizontal, 30)
                    .frame(height: frameHeight)
                    .padding(.top, paddingVertical)
//                    .padding(.bottom, paddingVertical)

                Text(" ")
            }
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
                                .fill(card.color.gradient)
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
                    .scrollClipDisabled()
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always)) // always needed for top alignment for some reason
                    .onAppear {
                        scrolledID = cards.first?.id
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
                PageNavigator(scrolledID: $scrolledID, cards: cards)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    @ViewBuilder private var callToActionView: some View {
        VStack {
            OnboardingPrimaryButtons(isFinishedOnboarding: scrolledID == cards.last?.id, isPresentingStoreSheet: $isPresentingStoreSheet, navigationPath: $navigationPath)
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
                    if horizontalSizeClass == .regular {
                        callToActionView
                            .frame(maxHeight: .infinity)
                            .background(.regularMaterial)
                    }
                    scrollView
                        .frame(width: horizontalSizeClass == .regular ? 0.666 * geometry.insetAdjustedSize.width : nil)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if horizontalSizeClass == .compact {
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
    
    init(cards: [OnboardingCard], isPresentingStoreSheet: Binding<Bool>, navigationPath: Binding<NBNavigationPath>, cardContent: @escaping (OnboardingCard) -> CardContent) {
        self.cards = cards
        _isPresentingStoreSheet = isPresentingStoreSheet
        _navigationPath = navigationPath
        self.cardContent = cardContent
    }
}

fileprivate struct FreeModeView: View {
    @Binding var isPresentingStoreSheet: Bool
 
    @AppStorage("hasViewedFreeModeUpsell") private var hasViewedFreeModeUpsell = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            LazyVStack {
                MarkdownWebView("""
                ## Free Mode
                
                **Manabi Reader helps you stay motivated while learning faster, for free.**
                
                Read from a library of curated blogs, news feeds, stories and ebooks. Tap words to look them up. Listen to spoken audio as you read.
                
                Immersion is necessary. Manabi Reader caters to diverse taste and skill levels. Import your own files or browse the web as you like. Reader Mode works on most anything.
                
                Immersion can be a grind too. It's brutal to spend hours reading above your level without being able to feel the progress that you're making. That's why Manabi shows you personalized stats on how familiar you already are with the vocab and kanji you encounter. Collect example sentences automatically. Chart your progress as you read in real-time.
                
                All the above is free.
                
                ## Why upgrade?
                
                The subscription personalizes your stats more to help you see what words and kanji you need to learn. Your dictionary syncs with.  You get support for saving words to Manabi Flashcards or Anki. You'll also be supporting ongoing development.
                
                ## Can't afford it?
                
                Equal access is education is a valuable principle. If you're a student or if you just can't afford the full price, please consider the discounted plan. It starts at $1 US per month for full access.
                
                ***Editor's Note:*** Thank you for using Manabi Reader. Whether or not you pay to support its full-time developmnent, rest assured there is more to come for Free Mode. As the subscription tier features improve, more paid features will become free too.
                ##
                """)
                .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack {
                PrimaryButton(title: "View Upgrade Discounts", systemImage: "chevron.up.circle") {
                    isPresentingStoreSheet.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                PrimaryButton(title: hasViewedFreeModeUpsell ? "Continue Without Trying Discounts" : "Continue Without Checking Upgrades", systemImage: nil) {
                    dismiss()
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
    @Binding var isPresentingStoreSheet: Bool
    @ViewBuilder let cardContent: (OnboardingCard) -> CardContent
    
    @State private var navigationPath = NBNavigationPath()
    
    var body: some View {
        NBNavigationStack(path: $navigationPath) {
            OnboardingCardsView(cards: cards, isPresentingStoreSheet: $isPresentingStoreSheet, navigationPath: $navigationPath, cardContent: cardContent)
                .nbNavigationDestination(for: String.self, destination: { dest in
                    switch dest {
                    case "free-mode":
                        FreeModeView(isPresentingStoreSheet: $isPresentingStoreSheet)
                    default: EmptyView()
                    }
                })
        }
    }
    
    init(cards: [OnboardingCard], isPresentingStoreSheet: Binding<Bool>, cardContent: @escaping (OnboardingCard) -> CardContent) {
        self.cards = cards
        _isPresentingStoreSheet = isPresentingStoreSheet
        self.cardContent = cardContent
    }
}

struct OnboardingCardView<CardContent: View>: View {
    let card: OnboardingCard
    let isTopVisible: Bool
    @ViewBuilder let cardContent: (OnboardingCard) -> CardContent

    @State private var cardSize: CGSize?
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack {
//            ScrollView {
                VStack {
                    Text(card.title)
                        .font(.title)
                        .bold()
                        .lineLimit(9001)
                        .fixedSize(horizontal: false, vertical: true)

                    cardContent(card)
                    
                    Text(card.description)
                        .font(.headline)
                        .lineLimit(9001)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .multilineTextAlignment(.center)
                .padding()
//            }
//            .modifier {
//                if #available(iOS 17, macOS 14, *) {
//                    $0
//                        .scrollContentBackground(.hidden)
//                        .scrollBounceBehavior(.basedOnSize)
//                } else { $0 }
//            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .task { @MainActor in
                        cardSize = geometry.insetAdjustedSize
                    }
                    .onChange(of: geometry.insetAdjustedSize) { insetAdjustedSize in
                        cardSize = insetAdjustedSize
                    }
            }
        }
        .frame(maxWidth: cardSize?.height ?? .infinity)
        .background(Color.systemGroupedBackground)
        .cornerRadius(15)
        .shadow(radius: isTopVisible ? 16 : 8)
        .scaleEffect(isTopVisible ? 1.02 : 1.0)
        .animation(.easeInOut, value: isTopVisible)
    }
}

@available(iOS 13, macOS 14, *)
fileprivate struct PageNavigator: View {
    @Binding var scrolledID: String?
    let cards: [OnboardingCard]
    
    @State var animateCount: Int = 0
    
    @ScaledMetric(relativeTo: .body) private var pageButtonFontSize = 14
    
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
                if #available(iOS 17.0, *) {
                    Label {
                        Text(title)
                    } icon: {
                        Image(systemName: systemImage)
#if os(iOS)
                            .bold()
                            .fontDesign(.rounded)
#endif
                    }
#if os(iOS)
                    .bold()
#endif
                    .symbolEffect(.bounce, value: isAnimated ? animateCount : 0)
                } else {
                    Label(title, systemImage: systemImage)
#if os(iOS)
                        .modifier {
                            if #available(iOS 16.1, macOS 13.1, *) {
                                $0
                                    .bold()
                                    .fontDesign(.rounded)
                            } else { $0 }
                        }
#endif
                }
            }
#if os(iOS)
            .font(.system(size: pageButtonFontSize))
            .padding(12)
#endif
        }
#if os(iOS)
        .buttonStyle(.borderless)
#endif
        .tint(.secondary)
        .background(.regularMaterial)
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
                .clipShape(.circle)
                .foregroundStyle(Color.accentColor)

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

struct OnboardingSheetStatus {
    static var dismissedWithoutResponse = false
}

public struct OnboardingSheet<CardContent: View>: ViewModifier {
    let isActive: Bool
    @State var isPresentingStoreSheet = false
    let cards: [OnboardingCard]
    @ViewBuilder let cardContent: (OnboardingCard) -> CardContent
    
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    @State private var hasInitialized = false

    
    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding<Bool>(
                get: {
                return hasInitialized
                    && isActive
                    && !(hasRespondedToOnboarding || OnboardingSheetStatus.dismissedWithoutResponse)
                },
                set: { newValue in
                    OnboardingSheetStatus.dismissedWithoutResponse = !newValue && !hasRespondedToOnboarding
                }
            )) {
                OnboardingView(cards: cards, isPresentingStoreSheet: $isPresentingStoreSheet, cardContent: cardContent)
                    .onDisappear {
                        if !hasRespondedToOnboarding {
                            OnboardingSheetStatus.dismissedWithoutResponse = true
                        }
                    }
                    .storeSheet(isPresented: $isPresentingStoreSheet && isActive)
                // TODO: track onDisappear (after tracking onAppear to make sure it was seen for long enough too) timestamp as last seen date in AppStorage to avoid re-showing onboarding within seconds or minute of last seeing it again. Avoids annoying the user.
            }
            .task {
                refresh()
            }
            .onChange(of: isActive) { isActive in
                refresh(isActive: isActive)
            }
            .onChange(of: hasRespondedToOnboarding) { hasRespondedToOnboarding in
                refresh()
            }
    }
    
    private func refresh(isActive: Bool? = nil) {
        let isActive = isActive ?? self.isActive
        Task { @MainActor in
            if !isActive {
                hasInitialized = false
            } else {
                try? await Task.sleep(nanoseconds: 10_000_000)
                hasInitialized = true
            }
        }
    }
}

public extension View {
    func onboardingSheet(isActive: Bool = true, cards: [OnboardingCard], cardContent: @escaping (OnboardingCard) -> some View) -> some View {
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
