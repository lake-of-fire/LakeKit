#if os(iOS)
import SwiftUI
import UIKit

public extension View {
    @available(iOS 16, *)
    @ViewBuilder
    func largestUndimmedDetent(identifier: UISheetPresentationController.Detent.Identifier) -> some View {
//        let detentIdentifier = UISheetPresentationController.Detent.Identifier(identifier)
        background(UndimmedSheetPresentation.Representable(largestUndimmedDetent: identifier))
    }
}

@available(iOS 16, *)
enum UndimmedSheetPresentation {
    struct Representable: UIViewControllerRepresentable {
        let largestUndimmedDetent: UISheetPresentationController.Detent.Identifier

        func makeUIViewController(context: Context) -> Controller {
            Controller(largestUndimmedDetent: largestUndimmedDetent)
        }

        func updateUIViewController(_ controller: Controller, context: Context) {
            controller.update(largestUndimmedDetent: largestUndimmedDetent)
        }
    }

    final class Controller: UIViewController {
        private var observation: NSKeyValueObservation?

        private var largestUndimmedDetent: UISheetPresentationController.Detent.Identifier

        init(largestUndimmedDetent: UISheetPresentationController.Detent.Identifier) {
            self.largestUndimmedDetent = largestUndimmedDetent
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func willMove(toParent parent: UIViewController?) {
            super.willMove(toParent: parent)
            update(largestUndimmedDetent: largestUndimmedDetent)
        }
        
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            update(largestUndimmedDetent: largestUndimmedDetent)
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            update(largestUndimmedDetent: largestUndimmedDetent)
        }
        
//        override func viewDidLayoutSubviews() {
//            super.viewDidLayoutSubviews()
//            update(largestUndimmedDetent: largestUndimmedDetent)
//        }

        func update(largestUndimmedDetent: UISheetPresentationController.Detent.Identifier) {
            self.largestUndimmedDetent = largestUndimmedDetent

            if let controller = parent?.sheetPresentationController {
                controller.prefersScrollingExpandsWhenScrolledToEdge = true
                controller.prefersEdgeAttachedInCompactHeight = true
                controller.largestUndimmedDetentIdentifier = largestUndimmedDetent
            }
            if let controller = parent?.popoverPresentationController?.adaptiveSheetPresentationController {
                controller.prefersScrollingExpandsWhenScrolledToEdge = true
                controller.prefersEdgeAttachedInCompactHeight = true
                controller.largestUndimmedDetentIdentifier = largestUndimmedDetent
            }
        }

        // Not called when changed programmatically
        func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheetPresentationController: UISheetPresentationController) {
            update(largestUndimmedDetent: largestUndimmedDetent)
        }
    }
}
#endif
