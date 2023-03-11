import SwiftUI
import Combine

// See: https://developer.apple.com/forums/thread/126878
public final class DeviceOrientation: ObservableObject {
    public enum Orientation {
        case portrait
        case landscape
    }
    @Published public var orientation: Orientation
    private var listener: AnyCancellable?
    public init() {
        orientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
        listener = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { ($0.object as? UIDevice)?.orientation }
            .compactMap { deviceOrientation -> Orientation? in
                if deviceOrientation.isPortrait {
                    return .portrait
                } else if deviceOrientation.isLandscape {
                    return .landscape
                } else {
                    return nil
                }
            }
            .assign(to: \.orientation, on: self)
    }
    deinit {
        listener?.cancel()
    }
}
