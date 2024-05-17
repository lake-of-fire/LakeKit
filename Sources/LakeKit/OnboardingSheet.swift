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
    
    public var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 40) {
                        ForEach(viewModel.cards) { card in
                            OnboardingCardView(card: card)
                                .frame(height: 400)
                                .id(card.id)
                        }
                    }
                    .padding()
                    .onChange(of: currentIndex) { newIndex in
                        withAnimation {
                            proxy.scrollTo(viewModel.cards[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
            
            PageIndicator(currentIndex: $currentIndex, count: viewModel.cards.count)
                .padding(.top, 20)
            
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
        }
    }
    
    public init(cards: [OnboardingCard]) {
        self.viewModel = OnboardingViewModel(cards: cards)
    }
}

struct OnboardingCardView: View {
    let card: OnboardingCard
    
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
        .shadow(radius: 10)
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
            .overlay { Text("\(isActive) \(hasInitialized)").background(.red) }
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
