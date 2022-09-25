import Foundation
import Kingfisher
import SwiftUI
import WebURL
import WebURLFoundationExtras

//private class RedirectHandler: ImageDownloadRedirectHandler {
//    func handleHTTPRedirection(for task: SessionDataTask, response: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
//        var modified = newRequest
//        //    modified.allHTTPHeaderFields = authorizationHeaders
//        completionHandler(modified)
//    }
//}

private let requestModifier = AnyModifier { request in
    var r = request
    r.setValue("abc", forHTTPHeaderField: "Access-Token")
    if let url = r.url, let webURL = WebURL(url) {
        r.url = URL(webURL) // Standardize safely.
    }
    return r
}

public struct LakeImage: View {
    @State var url: URL
    
    public var body: some View {
//        AsyncImage(url: url) { image in
//           image
//            .resizable()
//            .aspectRatio(contentMode: .fit)
//        } placeholder: {
//            Color.gray
//        }
        KFImage(url)
            .retry(maxCount: 10, interval: .seconds(1))
            .cacheOriginalImage()
            .cancelOnDisappear(true)
            .loadDiskFileSynchronously(false)
            .resizable()
            .requestModifier(requestModifier)
//            .redirectHandler(RedirectHandler())
            .aspectRatio(contentMode: .fit)
    }
    
    public init(_ url: URL) {
        self._url = State(initialValue: url)
    }
  }
