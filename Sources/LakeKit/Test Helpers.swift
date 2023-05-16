#if TEST
import Foundation
import XCTest

public protocol Screen {
    var app: XCUIApplication { get }
}

public extension Screen {
    func takeScreenshot(_ name: String) -> Self {
        XCTContext.runActivity(named: name) { activity in
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
        return self
    }
}
#endif
