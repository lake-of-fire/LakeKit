import Foundation
import Translation

public struct TranslationRequest {
    public let textToTranslate: String
    public let action: ((String) async throws -> Void)
    
    public init(textToTranslate: String, action: @escaping (String) async throws -> Void) {
        self.textToTranslate = textToTranslate
        self.action = action
    }
}

public struct BatchedTranslationRequest {
    public var translationTaskConfiguration: Any {
        willSet {
            removeAll()
        }
    }
    public var requests: [TranslationRequest]
    
    public init(translationTaskConfiguration: Any, requests: [TranslationRequest]) {
        self.translationTaskConfiguration = translationTaskConfiguration
        self.requests = requests
    }
    
    public var isEmpty : Bool {
        return requests.isEmpty
    }
    
    @available(iOS 18, macOS 15, *)
    public func translationSessionRequests() -> [TranslationSession.Request] {
        return requests.enumerated().map { (index, request) in
            TranslationSession.Request(
                sourceText: request.textToTranslate,
                clientIdentifier: String(index)
            )
        }
    }
    
    public mutating func invalidate() {
        if #available(iOS 18, macOS 15, *) {
            guard var configuration = (translationTaskConfiguration as? TranslationSession.Configuration) else { return }
            configuration.invalidate()
            translationTaskConfiguration = configuration // Necessary?
        }
    }
    
    public mutating func removeAll() {
        requests.removeAll()
    }
}
