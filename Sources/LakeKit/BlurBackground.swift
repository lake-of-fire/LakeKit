import SwiftUI

// See: https://stackoverflow.com/questions/63745084/how-can-i-make-a-background-color-with-opacity-on-a-sheet-view
#if os(iOS)
public struct BlurBackground: UIViewRepresentable {
    @MainActor
    private static var backgroundColor: UIColor?
    private let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    
    public init() {
    }

    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        Task { @MainActor in
            guard let container = view.superview?.superview else { return }
            Self.backgroundColor = container.backgroundColor
            container.backgroundColor = .clear
            
            blurEffectView.frame = container.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.superview?.addSubview(blurEffectView)
            container.removeFromSuperview()
            container.willMove(toSuperview: blurEffectView.contentView)
            blurEffectView.contentView.addSubview(container)
            container.didMoveToSuperview()
            //            container.insertSubview(blurEffectView, at: 0)
        }
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        guard let container = uiView.superview?.superview else { return }
        blurEffectView.frame = container.bounds
    }
    
    public static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        uiView.superview?.superview?.backgroundColor = Self.backgroundColor
        if let blurView = uiView.superview?.superview?.subviews.last(where: { $0 is UIVisualEffectView }) as? UIVisualEffectView {
            blurView.contentView.subviews.forEach { (subview: UIView) in
                if let container = blurView.superview {
                    subview.removeFromSuperview()
                    subview.willMove(toSuperview: container)
                    container.addSubview(subview)
                    subview.didMoveToSuperview()
                }
            }
            blurView.removeFromSuperview()
        }
    }
}
#endif
