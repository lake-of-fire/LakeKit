import SwiftUI

public struct UnfinishedOnboardingReminder: View {
    @AppStorage("hasRespondedToOnboarding") var hasRespondedToOnboarding = false
    @EnvironmentObject private var storeViewModel: StoreViewModel
    
    public var body: some View {
        if !hasRespondedToOnboarding && OnboardingSheetStatus.dismissedWithoutResponse && !storeViewModel.isSubscribed {
            Button {
                OnboardingSheetStatus.dismissedWithoutResponse = false
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
