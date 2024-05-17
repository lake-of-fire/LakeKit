import SwiftUI

public struct OnboardingCard: Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let imageName: String
    
    public init(id: String, title: String, description: String, imageName: String) {
        self.id = id
        self.title = title
        self.description = description
        self.imageName = imageName
    }
}

public class OnboardingViewModel: ObservableObject {
    @Published var cards: [OnboardingCard]
    
    public init(cards: [OnboardingCard]) {
        self.cards = cards
    }
}

public struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var currentIndex = 0
    @State private var topVisibleCardId: String?
    @State private var cardFrames: [String: CGRect] = [:]
    
    private var cardMinHeight: CGFloat = 400
    
    @ViewBuilder private func cardView(card: OnboardingCard) -> some View {
        OnboardingCardView(card: card, isTopVisible: topVisibleCardId == card.id)
            .frame(minHeight: cardMinHeight)
            .modifier {
                if #available(iOS 17, macOS 14, *) {
                    $0.scrollTargetLayout()
                } else { $0 }
            }
            .id(card.id)
    }
    
    @ViewBuilder private var scrollView: some View {
        if #available(iOS 17, macOS 14, *) {
            GeometryReader { wheelGeometry in
                WheelScroll(axis: .vertical, contentSpacing: 10) {
                    Group {
                        ForEach(viewModel.cards) { card in
                            cardView(card: card)
                        }
                        Color.clear.frame(height: max(0, wheelGeometry.size.height - cardMinHeight - 10 - wheelGeometry.safeAreaInsets.top - wheelGeometry.safeAreaInsets.bottom))
                            .overlay {
                                VStack {
                                    Text("\(wheelGeometry.size.height)")
                                    Text("\(cardMinHeight)")
                                }
                            }
                            .id("empty-wheel")
                    }
                }
            }
            .scrollTargetBehavior(.viewAligned)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            Task { @MainActor in
                                refresh(geo: geo)
                            }
                        }
                }
            }
        } else {
            ScrollView {
                
            }
        }
    }
    
    public var body: some View {
        scrollView
            .safeAreaInset(edge: .bottom) {
                VStack {
                    PageIndicator(currentIndex: $currentIndex, count: viewModel.cards.count)
                        .padding(.bottom, 20)
                        .background(.regularMaterial)
                    HStack {
                        Button(action: {
                            // Add your action here
                        }) {
                            Text("Skip")
                        }
                        Spacer()
                        Button(action: {
                            if currentIndex < viewModel.cards.count - 1 {
                                currentIndex += 1
                            }
                        }) {
                            Text("Next")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .background(.regularMaterial)
                }
            }
    }
    
    public init(cards: [OnboardingCard]) {
        self.viewModel = OnboardingViewModel(cards: cards)
    }
    
    func refresh(geo: GeometryProxy) {
        let visibleFrame = geo.frame(in: .named("scrollView"))
        if let topCard = viewModel.cards.first(where: {
            let cardFrame = cardFrames[$0.id]
            return cardFrame?.minY ?? 0 <= visibleFrame.midY && cardFrame?.maxY ?? 0 >= visibleFrame.midY
        }) {
            currentIndex = viewModel.cards.firstIndex(where: { $0.id == topCard.id }) ?? 0
        }
    }
}

struct CardFramePreferenceKey: PreferenceKey {
    typealias Value = [String: CGRect]
    
    static var defaultValue: [String: CGRect] = [:]
    
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct OnboardingCardView: View {
    let card: OnboardingCard
    let isTopVisible: Bool
    
    var body: some View {
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
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: isTopVisible ? 20 : 10)
        .scaleEffect(isTopVisible ? 1.05 : 1.0)
        .animation(.easeInOut, value: isTopVisible)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: CardFramePreferenceKey.self, value: [card.id: proxy.frame(in: .named("scrollView"))])
        })
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

struct PageIndicator: View {
    @Binding var currentIndex: Int
    let count: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.blue : Color.gray)
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        currentIndex = index
                    }
            }
        }
    }
}

public struct OnboardingSheet: ViewModifier {
    let isActive: Bool
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    @State private var hasInitialized = false
    @State private var dismissedWithoutResponse = false
    
    let cards: [OnboardingCard]
    
    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding<Bool>(
                get: {
                    hasInitialized
                    && isActive
                    && (!hasRespondedToOnboarding)// || dismissedWithoutResponse)
                },
                set: { newValue in
                    dismissedWithoutResponse = !newValue && !hasRespondedToOnboarding
                }
            )) {
                OnboardingView(cards: cards)
                // TODO: track onDisappear (after tracking onAppear to make sure it was seen for long enough too) timestamp as last seen date in AppStorage to avoid re-showing onboarding within seconds or minute of last seeing it again. Avoids annoying the user.
            }
            .task {
                refresh()
            }
            .onChange(of: isActive) { isActive in
                refresh()
            }
            .onChange(of: hasRespondedToOnboarding) { hasRespondedToOnboarding in
                refresh()
            }
    }
    
    private func refresh() {
        Task { @MainActor in
            print("!! \(isActive) isac \(hasInitialized) hasin")
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
