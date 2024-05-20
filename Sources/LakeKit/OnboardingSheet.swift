import SwiftUI
import NavigationBackport
//import MarkdownWebView

public struct OnboardingCard: Identifiable {
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

public struct UnfinishedOnboardingReminder: View {
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    @EnvironmentObject private var storeViewModel: StoreViewModel
 
    public var body: some View {
        if !hasRespondedToOnboarding && OnboardingSheet.dismissedWithoutResponse && !storeViewModel.isSubscribed {
            Button {
                OnboardingSheet.dismissedWithoutResponse = false
            } label: {
                GroupBox(label: Image(systemName: "info.circle.fill").resizable().frame(width: 25, height: 25).foregroundColor(.accentColor)) {
                    VStack(alignment: .leading) {
                        (Text("You're in Free Mode. ").foregroundColor(.secondary) + Text("View Upgrades").foregroundColor(Color.accentColor))
                            .bold()
                            .padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 15))
                    }
                }
                .frame(maxWidth: .infinity)
//                .backgroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
            }
        }
    }
}

struct OnboardingPrimaryButtons: View {
    @Binding var isPresentingStoreSheet: Bool
    @Binding var navigationPath: NBNavigationPath

    @EnvironmentObject private var storeViewModel: StoreViewModel
    @Environment(\.dismiss) private var dismiss
 
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
    
    @ViewBuilder private func primaryButton(title: String, systemImage: String?, action: @escaping () -> Void) -> some View {
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
    
    var body: some View {
        if storeViewModel.isSubscribed {
            primaryButton(title: "Continue", systemImage: nil) {
                dismiss()
            }
            .tint(.accentColor)
            .buttonStyle(.borderedProminent)
        } else {
            primaryButton(title: "Continue to Upgrades", systemImage: nil) {
                isPresentingStoreSheet.toggle()
            }
            .tint(.accentColor)
            .buttonStyle(.borderedProminent)
            
            primaryButton(title: "Skip Upgrades", systemImage: nil) {
                navigationPath.removeLast(navigationPath.count)
                navigationPath.append("free-mode")
            }
            .tint(.secondary)
        }
    }
}

struct OnboardingCardsView: View {
    let cards: [OnboardingCard]
    @Binding var navigationPath: NBNavigationPath
    @Binding var isPresentingStoreSheet: Bool
        @State private var cardFrames: [String: CGRect] = [:]
    @State private var scrolledID: String?
    
    private var cardMinHeight: CGFloat = 360
    
    private var appName: String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
        
    private var currentCard: OnboardingCard? {
        guard let scrolledID = scrolledID else { return nil }
        return cards.first(where: { $0.id == scrolledID })
    }
    
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder private func cardView(card: OnboardingCard) -> some View {
        OnboardingCardView(card: card, isTopVisible: scrolledID == card.id)
            .frame(minHeight: cardMinHeight)
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
        .padding(.horizontal)
        .padding(.bottom)
//        .id("wheel-welcome")
    }
        
    @ViewBuilder private func scrollViewInner() -> some View {
        ForEach(cards, id: \.id) { card in
            cardView(card: card)
        }
    }
        
    @ViewBuilder private func scrollViewFooter(wheelGeometry: GeometryProxy) -> some View {
        Color.clear.frame(height: max(0, wheelGeometry.size.height - cardMinHeight - wheelGeometry.safeAreaInsets.top - wheelGeometry.safeAreaInsets.bottom))
//            .id("empty-wheel")
    }
    
    @ViewBuilder private var scrollView: some View {
        Group {
            if #available(iOS 17, macOS 14, *) {
                GeometryReader { wheelGeometry in
                    WheelScroll(axis: .vertical, contentSpacing: 10, header: {
                        scrollViewHeader()
                    }, footer: {
                        scrollViewFooter(wheelGeometry: wheelGeometry)
                    }) {
                        scrollViewInner()
                    }
                    .scrollPosition(id: $scrolledID)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always)) // always needed for top alignment for some reason
                    .defaultScrollAnchor(.top)
                    .onAppear {
                        scrolledID = cards.first?.id
                    }
                }
            } else {
                GeometryReader { wheelGeometry in
                    ScrollView {
                        scrollViewHeader()
                        scrollViewFooter(wheelGeometry: wheelGeometry)
                        scrollViewInner()
                    }
                }
            }
        }
        .modifier {
            if #available(iOS 16, macOS 13, *) {
                $0.background(colorScheme == .dark ? Color.black.gradient : Color.white.gradient)
            } else {
                $0.background(colorScheme == .dark ? Color.black : Color.white)
            }
        }
    }
    
    var body: some View {
        scrollView
            .ignoresSafeArea(edges: .vertical)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack {
                    if #available(iOS 17, macOS 14, *) {
                        PageNavigator(scrolledID: $scrolledID, cards: cards)
                            .padding(.bottom)
                    }
                    
                    VStack {
                        OnboardingPrimaryButtons(isPresentingStoreSheet: $isPresentingStoreSheet, navigationPath: $navigationPath)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
            }
    }
    
    init(cards: [OnboardingCard], isPresentingStoreSheet: Binding<Bool>, navigationPath: Binding<NBNavigationPath>) {
        self.cards = cards
        _isPresentingStoreSheet = isPresentingStoreSheet
        _navigationPath = navigationPath
    }
}

fileprivate struct FreeModeView: View {
    @Binding var isPresentingStoreSheet: Bool
 
    @AppStorage("hasViewedFreeModeUpsell") private var hasViewedFreeModeUpsell = false
    
    @Environment(\.dismiss) private var dismiss
    
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
        .modifier {
            if #available(iOS 17, macOS 14, *) {
                $0.controlSize(.extraLarge)
            } else {
                $0.controlSize(.large)
            }
        }
    }
    
    @ViewBuilder private func primaryButton(title: String, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            primaryButtonLabel(title: title, systemImage: systemImage)
        }
#if os(iOS)
        .font(.headline)
#endif
        .frame(maxWidth: .infinity)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack {
//                MarkdownWebView("""
                Text("""
                # Free Mode
                
                **Manabi Reader helps you stay motivated while learning faster, for free.**
                
                Read from a library of curated blogs, news feeds, stories and ebooks. Tap words to look them up. Listen to spoken audio as you read.
                
                Immersion is necessary. Manabi Reader caters to diverse taste and skill levels. Import your own files or browse the web as you like. Reader Mode works on most anything.
                
                Immersion can be a grind too. It's brutal to spend hours reading above your level without being able to feel the progress that you're making. That's why Manabi shows you personalized stats on how familiar you already are with the vocab and kanji you encounter. Collect example sentences automatically. Chart your progress as you read in real-time.
                
                All the above is free.
                
                # Subscriptions
                
                The subscription personalizes your stats more to help you see what words and kanji you need to learn. Your dictionary syncs with.  You get support for saving words to Manabi Flashcards or Anki. You'll also be supporting ongoing development.
                
                # Can't afford it?
                
                Equal access is education is a valuable principle. If you're a student or if you just can't afford the full price, please consider the discounted plan. It starts at $1 US per month for full access.
                
                ***Editor's Note:*** Thank you for using Manabi Reader. Whether or not you pay to support its full-time developmnent, rest assured there is more to come for Free Mode. As the subscription tier features improve, more paid features will become free too.
                ##
                """)
            }
        }
        .ignoresSafeArea(edges: .vertical)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack {
                primaryButton(title: "View Upgrade Discounts", systemImage: "chevron.up.circle") {
                    isPresentingStoreSheet.toggle()
                }
                
                primaryButton(title: hasViewedFreeModeUpsell ? "Continue Without Trying Discounts" : "Continue Without Viewing Upgrades", systemImage: nil) {
                    dismiss()
                }
                .tint(.secondary)
                .modifier {
                    if hasViewedFreeModeUpsell {
                        $0.buttonStyle(.bordered)
                    } else {
                        $0.buttonStyle(.borderless)
                    }
                }
            }
            .background(.thinMaterial)
        }
    }
}

struct OnboardingView: View {
    let cards: [OnboardingCard]
    @Binding var isPresentingStoreSheet: Bool
    
    @State private var navigationPath = NBNavigationPath()
    
    var body: some View {
        NBNavigationStack(path: $navigationPath) {
            OnboardingCardsView(cards: cards, isPresentingStoreSheet: $isPresentingStoreSheet, navigationPath: $navigationPath)
                .nbNavigationDestination(for: String.self, destination: { dest in
                    switch dest {
                    case "free-mode":
                        FreeModeView(isPresentingStoreSheet: $isPresentingStoreSheet)
                    default: EmptyView()
                    }
                })
        }
    }
    
    init(cards: [OnboardingCard], isPresentingStoreSheet: Binding<Bool>) {
        self.cards = cards
        _isPresentingStoreSheet = isPresentingStoreSheet
    }
}

struct OnboardingCardView: View {
    let card: OnboardingCard
    let isTopVisible: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    Image(card.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                        .overlay(SquiggleLine().stroke(Color.blue, lineWidth: 2))
                    
                    Text(card.title)
                        .font(.title)
                        .bold()
                    
                    Text(card.description)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .padding()
            }
            .modifier {
                if #available(iOS 17, macOS 14, *) {
                    $0
                        .scrollContentBackground(.hidden)
                        .scrollBounceBehavior(.basedOnSize)
                } else { $0 }
            }
        }
        .background(colorScheme == .dark ? .black : .white)
        .cornerRadius(15)
        .shadow(radius: isTopVisible ? 16 : 8)
        .scaleEffect(isTopVisible ? 1.02 : 1.0)
        .animation(.easeInOut, value: isTopVisible)
    }
}

struct SquiggleLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midHeight = rect.midY
        
        path.move(to: CGPoint(x: rect.minX, y: midHeight))
        path.addCurve(to: CGPoint(x: rect.maxX, y: midHeight), control1: CGPoint(x: rect.minX + rect.width / 3, y: rect.minY), control2: CGPoint(x: rect.maxX - rect.width / 3, y: rect.maxY))
        
        return path
    }
}

@available(iOS 13, macOS 14, *)
fileprivate struct PageNavigator: View {
    @Binding var scrolledID: String?
    let cards: [OnboardingCard]
    
    @State var animateCount: Int = 0
    
    private var currentIndex: Int? {
        guard let scrolledID = scrolledID else { return nil }
        return cards.firstIndex(where: { $0.id == scrolledID })
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
                    Label(title, systemImage: systemImage)
                        .labelStyle(.iconOnly)
#if os(iOS)
                        .bold()
                        .fontDesign(.rounded)
#endif
                        .symbolEffect(.bounce, value: isAnimated ? animateCount : 0)
                } else {
                    Label(title, systemImage: systemImage)
                        .labelStyle(.iconOnly)
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
            .padding()
        }
#if os(iOS)
        .buttonStyle(.borderless)
        .font(.headline)
#endif
        .tint(.secondary)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0)
        .allowsHitTesting(isEnabled)
    }

    var body: some View {
        HStack {
            pageTurnButton(title: "Previous", systemImage: "chevron.backward", isEnabled: (currentIndex ?? -1) > 0, isAnimated: false) {
                guard let currentIndex = currentIndex else { return }
                scrollTo(index: currentIndex - 1)
            }
            
            HStack(spacing: 0) {
                ForEach(0..<cards.count, id: \.self) { index in
                    Circle()
                        .fill(.primary)
                        .opacity(index == currentIndex ? 1 : 0.5)
                        .frame(width: 8, height: 8)
                        .padding(4)
                        .onTapGesture {
                            scrollTo(index: index)
                        }
                }
            }
            
            pageTurnButton(title: "Forward", systemImage: "chevron.forward", isEnabled: ((currentIndex ?? cards.count) + 1) < cards.count, isAnimated: true) {
                guard let currentIndex = currentIndex else { return }
                scrollTo(index: currentIndex + 1)
            }
        }
        .onAppear {
            animateCount = 1
        }
    }
}

public struct OnboardingSheet: ViewModifier {
    static var dismissedWithoutResponse = false
    
    let isActive: Bool
    @State var isPresentingStoreSheet = false
    
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    @State private var hasInitialized = false

    let cards: [OnboardingCard]
    
    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding<Bool>(
                get: {
                return hasInitialized
                    && isActive
                    && !(hasRespondedToOnboarding || Self.dismissedWithoutResponse)
                },
                set: { newValue in
                    Self.dismissedWithoutResponse = !newValue && !hasRespondedToOnboarding
                }
            )) {
                OnboardingView(cards: cards, isPresentingStoreSheet: $isPresentingStoreSheet)
                    .onDisappear {
                        if !hasRespondedToOnboarding {
                            Self.dismissedWithoutResponse = true
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
    func onboardingSheet(isActive: Bool = true, cards: [OnboardingCard]) -> some View {
        self.modifier(OnboardingSheet(isActive: isActive, cards: cards))
    }
}
