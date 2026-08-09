import Foundation

/// https://academy.realm.io/posts/realm-notifications-on-background-threads-with-swift/
open class BackgroundWorker: NSObject {
    private var thread: Thread?
    private var block: (() -> Void)?
    
    private let operationQueue: OperationQueue = OperationQueue()
    public var scheduler: OperationQueue { operationQueue }
    
    @objc internal func runBlock() { block?() }
    
    deinit {
        stop()
    }
    
    public func start(_ block: @escaping () -> Void) {
        self.block = block
        
        operationQueue.maxConcurrentOperationCount = 1
        
        let threadName = String(describing: self)
            .components(separatedBy: .punctuationCharacters)[1]
        
        let newThread = Thread {
            while !Thread.current.isCancelled {
              RunLoop.current.run(
                mode: RunLoop.Mode.default,
                before: Date.distantFuture)
            }
            Thread.exit()
        }
        thread = newThread
        newThread.name = "\(threadName)-\(UUID().uuidString)"
        newThread.start()
            
        perform(#selector(runBlock),
            on: newThread,
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.default.rawValue])
    }
    
    public func stop() {
        thread?.cancel()
    }
}
