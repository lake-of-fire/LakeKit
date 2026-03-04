import SwiftUI

public struct SteppedInstructionGroupBoxStyle: GroupBoxStyle {
    public var stepNumber: Int

    public init(stepNumber: Int) {
        self.stepNumber = stepNumber
    }

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Step \(stepNumber)")
                    .font(.footnote.weight(.medium))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.systemBackground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary)
                    )
                configuration.label
            }
            configuration.content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.stackListCardBackgroundPlain)
        )
    }
}

public extension GroupBoxStyle where Self == SteppedInstructionGroupBoxStyle {
    static func steppedInstruction(stepNumber: Int) -> Self {
        Self(stepNumber: stepNumber)
    }
}

