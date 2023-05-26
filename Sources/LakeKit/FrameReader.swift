#if os(macOS)
import SwiftUI

struct FrameReaderModifier: ViewModifier {
    let coordinateSpace: CoordinateSpace
    let frameReader: ((CGRect) -> Void)
    @State private var frame: CGRect = .zero
    
    func body(content: Content) -> some View {
        VStack {
            Color.clear
        }
        .hidden()
        .geometryReader { geometry in
            Task { @MainActor in
                let frame = geometry.frame(in: coordinateSpace)
                if self.frame != frame {
                    self.frame = frame
                    frameReader(frame)
                }
            }
        }
    }
}

//public extension View {
//    /**
//     Read a view's size. The closure is called whenever the size itself changes, or the transaction changes (in the event of a screen rotation.)
//
//     From https://stackoverflow.com/a/66822461/14351818
//     */
//    func sizeReader(transaction: Transaction? = nil, size: @escaping (CGSize) -> Void) -> some View {
//        return background(
//            GeometryReader { geometry in
//                Color.clear
//                    .preference(key: ContentSizeReaderPreferenceKey.self, value: geometry.size)
//                    .onPreferenceChange(ContentSizeReaderPreferenceKey.self) { newValue in
//                        DispatchQueue.main.async {
//                            size(newValue)
//                        }
//                    }
//                    .onValueChange(of: transaction?.animation) { _, _ in
//                        DispatchQueue.main.async {
//                            size(geometry.size)
//                        }
//                    }
//            }
//            .hidden()
//        )
//    }
//}

#endif
