#if os(iOS)
import UIKit
import XCTest
@testable import LakeKit

final class OnboardingPresentationSceneProbeTests: XCTestCase {
    @MainActor
    func testReportsExactSceneAndRetiresOnDetach() async throws {
        let window = try makeWindowInHostedScene()
        let scene = try XCTUnwrap(window.windowScene)
        let log = ReceiptLog()
        let observer = Observer(name: "primary", log: log)
        let probe = OnboardingPresentationSceneProbe.NativeView()

        probe.updateObserver(observer)
        XCTAssertTrue(log.receipts.isEmpty)

        window.addSubview(probe)
        probe.updateObserver(observer)
        XCTAssertEqual(log.receipts.map(\.scene), [ObjectIdentifier(scene)])

        probe.removeFromSuperview()
        probe.updateObserver(observer)
        XCTAssertEqual(log.receipts.map(\.scene), [ObjectIdentifier(scene), nil])
        XCTAssertEqual(Set(log.receipts.map(\.owner)).count, 1)
    }

    @MainActor
    func testReplacementRetiresOldObserverBeforeAttachingNewOne() async throws {
        let window = try makeWindowInHostedScene()
        let scene = try XCTUnwrap(window.windowScene)
        let log = ReceiptLog()
        let oldObserver = Observer(name: "old", log: log)
        let newObserver = Observer(name: "new", log: log)
        let probe = OnboardingPresentationSceneProbe.NativeView()

        probe.updateObserver(oldObserver)
        window.addSubview(probe)
        probe.updateObserver(newObserver)
        probe.updateObserver(newObserver)
        OnboardingPresentationSceneProbe.dismantleUIView(probe, coordinator: ())
        OnboardingPresentationSceneProbe.dismantleUIView(probe, coordinator: ())
        probe.removeFromSuperview()
        window.addSubview(probe)
        probe.updateObserver(oldObserver)

        XCTAssertEqual(log.receipts.map(\.observer), ["old", "old", "new", "new"])
        XCTAssertEqual(log.receipts.map(\.scene), [ObjectIdentifier(scene), nil, ObjectIdentifier(scene), nil])
        XCTAssertEqual(Set(log.receipts.map(\.owner)).count, 1)
    }

    @MainActor
    func testOverlappingNativeProbesRetireTheirOwnIdentities() async throws {
        let window = try makeWindowInHostedScene()
        let scene = try XCTUnwrap(window.windowScene)
        let log = ReceiptLog()
        let observer = Observer(name: "shared", log: log)
        let earlierProbe = OnboardingPresentationSceneProbe.NativeView()
        let laterProbe = OnboardingPresentationSceneProbe.NativeView()

        earlierProbe.updateObserver(observer)
        laterProbe.updateObserver(observer)
        window.addSubview(earlierProbe)
        window.addSubview(laterProbe)
        OnboardingPresentationSceneProbe.dismantleUIView(earlierProbe, coordinator: ())
        laterProbe.updateObserver(observer)

        XCTAssertEqual(log.receipts.map(\.scene), [ObjectIdentifier(scene), ObjectIdentifier(scene), nil])
        let earlierOwner = try XCTUnwrap(log.receipts.first?.owner)
        let laterOwner = try XCTUnwrap(log.receipts.dropFirst().first?.owner)
        XCTAssertNotEqual(earlierOwner, laterOwner)
        XCTAssertEqual(log.receipts.last?.owner, earlierOwner)

        laterProbe.removeFromSuperview()
        XCTAssertEqual(log.receipts.last?.owner, laterOwner)
        XCTAssertNil(log.receipts.last?.scene)
    }

    @MainActor
    private func makeWindowInHostedScene() throws -> UIWindow {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { !$0.windows.isEmpty })
        else {
            throw XCTSkip("An iOS app host with a UIWindowScene is required.")
        }
        return UIWindow(windowScene: scene)
    }

    @MainActor
    private final class ReceiptLog {
        struct Receipt {
            let observer: String
            let owner: UUID
            let scene: ObjectIdentifier?
        }

        var receipts: [Receipt] = []
    }

    @MainActor
    private final class Observer: OnboardingPresentationSceneObserver {
        let name: String
        let log: ReceiptLog

        init(name: String, log: ReceiptLog) {
            self.name = name
            self.log = log
        }

        func onboardingPresentation(_ owner: UUID, didMoveTo scene: UIWindowScene?) {
            log.receipts.append(.init(observer: name, owner: owner, scene: scene.map(ObjectIdentifier.init)))
        }
    }
}
#endif
