import Foundation

/// https://academy.realm.io/posts/realm-notifications-on-background-threads-with-swift/
open class BackgroundWorker: NSObject {
    private var thread: Thread!
    private var block: (()->Void)!
    
    private let operationQueue: OperationQueue = OperationQueue()
    public var scheduler: OperationQueue { operationQueue }
    
    @objc internal func runBlock() { block() }
    
    deinit {
        stop()
    }
    
    public func start(_ block: @escaping () -> Void) {
        self.block = block
        
        operationQueue.maxConcurrentOperationCount = 1
        
        let threadName = String(describing: self)
            .components(separatedBy: .punctuationCharacters)[1]
        
        thread = Thread { [weak self] in
            while (self != nil && !self!.thread.isCancelled) {
              RunLoop.current.run(
                mode: RunLoop.Mode.default,
                before: Date.distantFuture)
            }
            Thread.exit()
        }
        thread.name = "\(threadName)-\(UUID().uuidString)"
        thread.start()
            
        perform(#selector(runBlock),
            on: thread,
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.default.rawValue])
    }
    
    public func stop() {
        thread.cancel()
    }
}
