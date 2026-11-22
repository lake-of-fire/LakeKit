import XCTest
import Combine
import Dispatch
import StoreHelper
import BigSyncKit
import RealmSwift
import ZIPFoundation
@testable import RealmSwiftGaps
@testable import LakeKit

final class ZIPArchiveTransferFileTests: XCTestCase {
    func testSameTitleTransfersRetainIndependentSnapshots() throws {
        let root = try makeTransferRoot()
        let first = ZIPArchive(title: "Manabi User Data Backup", content: Data("first archive".utf8))
        let second = ZIPArchive(title: first.title, content: Data("second archive".utf8))

        let firstURL = try first.writeTransferFile(in: root)
        let secondURL = try second.writeTransferFile(in: root)

        XCTAssertNotEqual(firstURL, secondURL)
        XCTAssertEqual(firstURL.lastPathComponent, first.fileName)
        XCTAssertEqual(secondURL.lastPathComponent, second.fileName)
        XCTAssertEqual(try Data(contentsOf: firstURL), first.content)
        XCTAssertEqual(try Data(contentsOf: secondURL), second.content)
    }

    func testSanitizedFilenameCollisionsDoNotReplaceAnotherTransfer() throws {
        let root = try makeTransferRoot()
        let first = ZIPArchive(title: "Archive/Part", content: Data([1, 2, 3]))
        let second = ZIPArchive(title: "Archive\\Part", content: Data([4, 5, 6]))
        XCTAssertEqual(first.fileName, second.fileName)

        let firstURL = try first.writeTransferFile(in: root)
        let secondURL = try second.writeTransferFile(in: root)

        XCTAssertNotEqual(firstURL.deletingLastPathComponent(), secondURL.deletingLastPathComponent())
        XCTAssertEqual(firstURL.lastPathComponent, first.fileName)
        XCTAssertEqual(secondURL.lastPathComponent, second.fileName)
        XCTAssertEqual(try Data(contentsOf: firstURL), first.content)
        XCTAssertEqual(try Data(contentsOf: secondURL), second.content)
    }

    func testRepeatedTransferRecreatesSnapshotWithoutChangingEarlierReceiverFile() throws {
        let root = try makeTransferRoot()
        let archive = ZIPArchive(title: "Snapshot", content: Data("original archive".utf8))
        let firstURL = try archive.writeTransferFile(in: root)
        let receiverChanges = Data("receiver changes".utf8)
        try receiverChanges.write(to: firstURL, options: .atomic)

        let secondURL = try archive.writeTransferFile(in: root)

        XCTAssertNotEqual(firstURL, secondURL)
        XCTAssertEqual(try Data(contentsOf: firstURL), receiverChanges)
        XCTAssertEqual(try Data(contentsOf: secondURL), archive.content)
    }

    private func makeTransferRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZIPArchiveTransferFileTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}

final class RecentLogsTextTests: XCTestCase {
    private let header = "Logs truncated to the most recent 1 MiB for email.\n\n"

    func testClippedOlderUnicodeCannotDiscardNewerLogsOrBackfillStillOlderData() {
        XCTAssertEqual(
            recentLogsText(from: ["recent", "古a", "older"], byteLimit: 9),
            header + "recenta"
        )
        XCTAssertEqual(
            recentLogsText(from: ["recent", "古", "older"], byteLimit: 8),
            header + "recent"
        )
    }

    func testUTF8SuffixBudgetPreservesWholeScalarsAndExistingOrdering() {
        for budget in 1...4 {
            XCTAssertEqual(
                recentLogsText(from: ["recent", "😀x", "older"], byteLimit: 6 + budget),
                header + "recentx"
            )
        }
        XCTAssertEqual(
            recentLogsText(from: ["new", "old"], byteLimit: 6),
            header + "newold"
        )
        XCTAssertEqual(
            recentLogsText(from: ["before日本"], byteLimit: 6),
            header + "日本"
        )
        XCTAssertEqual(recentLogsText(from: ["古", "older"], byteLimit: 2), "")
        XCTAssertEqual(recentLogsText(from: ["logs"], byteLimit: 0), "")
        XCTAssertEqual(recentLogsText(from: [], byteLimit: 10), "")
    }
}

@MainActor
final class LoggingRefreshOwnershipTests: XCTestCase {
    func testRetiredLoadsKeepSuccessorBusyAndCannotPublishLateLogs() async throws {
        let fixture = try makeFixture(contents: ["old A", "retired B", "current C"])
        let a = fixture.gates[0]
        let b = fixture.gates[1]
        let c = fixture.gates[2]
        var publishedText = [String]()
        let publication = fixture.model.$logsText.compactMap { $0 }.sink { publishedText.append($0) }
        defer { publication.cancel() }

        let first = fixture.start()
        try await waitForStart(a)
        let second = fixture.start()
        try await waitForStart(b)
        await fulfillment(of: [a.cancelled], timeout: 2)
        await a.release()
        await first.value

        XCTAssertTrue(fixture.model.isLoading, "A's completion must leave B's slot intact")
        XCTAssertNil(fixture.model.logsText)
        XCTAssertNil(fixture.model.logsZIPArchive)

        let third = fixture.start()
        try await waitForStart(c)
        await fulfillment(of: [b.cancelled], timeout: 2)
        await c.release()
        await third.value
        XCTAssertFalse(fixture.model.isLoading)
        XCTAssertEqual(fixture.model.logsText, "current C")

        await b.release()
        await second.value
        XCTAssertFalse(fixture.model.isLoading)
        XCTAssertEqual(publishedText, ["current C"])
        XCTAssertEqual(fixture.model.logsText, "current C")
        XCTAssertEqual(fixture.model.clippedLogsText, "current C")
        XCTAssertEqual(fixture.model.logs?.map(\.url), [c.url])
        XCTAssertEqual(try logText(in: fixture.model.logsZIPArchive), "current C")
        XCTAssertTrue(try logText(in: fixture.model.emailLogsZIPArchive).hasSuffix("current C"))
    }

    func testCancellingCallerCancelsWorkerAndWaitsUntilItReleases() async throws {
        let fixture = try makeFixture(contents: ["cancelled work"])
        let gate = fixture.gates[0]
        let returnedBeforeRelease = XCTestExpectation(description: "Cancelled caller returned while its worker was held")
        returnedBeforeRelease.isInverted = true
        var didRelease = false
        let load = fixture.start {
            if !didRelease { returnedBeforeRelease.fulfill() }
        }

        try await waitForStart(gate)
        load.cancel()
        await fulfillment(of: [gate.cancelled], timeout: 2)
        await fulfillment(of: [returnedBeforeRelease], timeout: 0.1)
        XCTAssertTrue(fixture.model.isLoading, "Cancelled work still owns its slot until it returns")

        didRelease = true
        await gate.release()
        await load.value
        XCTAssertFalse(fixture.model.isLoading)
        XCTAssertNil(fixture.model.logs)
        XCTAssertNil(fixture.model.logsText)
        XCTAssertNil(fixture.model.logsZIPArchive)
        XCTAssertNil(fixture.model.emailLogsZIPArchive)
    }

    func testAlreadyCancelledCallerDoesNotReplaceIncumbentLoad() async throws {
        let fixture = try makeFixture(contents: ["incumbent logs"])
        let gate = fixture.gates[0]
        let incumbent = fixture.start()
        try await waitForStart(gate)

        // These calls share the main actor. Cancellation precedes entry into
        // load(), even though the incumbent already owns a suspended worker.
        let cancelled = fixture.start()
        cancelled.cancel()
        await cancelled.value
        let invocationCount = await fixture.provider.invocationCount
        XCTAssertEqual(invocationCount, 1)
        XCTAssertTrue(fixture.model.isLoading)

        await gate.release()
        await incumbent.value
        XCTAssertFalse(fixture.model.isLoading)
        XCTAssertEqual(fixture.model.logsText, "incumbent logs")
        XCTAssertEqual(try logText(in: fixture.model.logsZIPArchive), "incumbent logs")
    }

    func testFreshTextWithdrawsPreviousArchivesBeforePublishingNewBytes() async throws {
        let fixture = try makeFixture(contents: ["previous logs", "fresh logs"])
        let original = fixture.start()
        try await waitForStart(fixture.gates[0])
        await fixture.gates[0].release()
        await original.value
        let retained = try XCTUnwrap(fixture.model.logsZIPArchive)
        XCTAssertEqual(try logText(in: retained), "previous logs")
        XCTAssertTrue(try logText(in: fixture.model.emailLogsZIPArchive).hasSuffix("previous logs"))

        var publishedFreshText = false
        let publication = fixture.model.$logsText.sink { text in
            guard text == "fresh logs" else { return }
            publishedFreshText = true
            XCTAssertNil(fixture.model.logsZIPArchive)
            XCTAssertNil(fixture.model.emailLogsZIPArchive)
        }
        defer { publication.cancel() }

        let replacement = fixture.start()
        try await waitForStart(fixture.gates[1])
        await fixture.gates[1].release()
        await replacement.value

        XCTAssertTrue(publishedFreshText)
        XCTAssertEqual(fixture.model.logsText, "fresh logs")
        XCTAssertEqual(try logText(in: fixture.model.logsZIPArchive), "fresh logs")
        XCTAssertTrue(try logText(in: fixture.model.emailLogsZIPArchive).hasSuffix("fresh logs"))
        XCTAssertEqual(try logText(in: retained), "previous logs")
    }

    private func waitForStart(_ gate: LogURLGate) async throws {
        await fulfillment(of: [gate.started], timeout: 2)
        guard await gate.didStart else { throw TestFailure.providerDidNotStart }
    }

    private func makeFixture(contents: [String]) throws -> LogRefreshFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LoggingRefreshOwnershipTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        do {
            let gates = try contents.enumerated().map { index, text in
                let url = root.appendingPathComponent("fixture-\(index).log")
                try Data(text.utf8).write(to: url)
                return LogURLGate(url: url)
            }
            let fixture = LogRefreshFixture(gates: gates)
            addTeardownBlock {
                await fixture.joinTasks()
                try FileManager.default.removeItem(at: root)
            }
            return fixture
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    private func logText(in snapshot: ZIPArchive?) throws -> String {
        let snapshot = try XCTUnwrap(snapshot)
        let archive = try XCTUnwrap(Archive(data: snapshot.content, accessMode: .read))
        let entry = try XCTUnwrap(archive["ManabiReaderLogs.txt"])
        var decoded = Data()
        _ = try archive.extract(entry) { decoded.append($0) }
        return try XCTUnwrap(String(data: decoded, encoding: .utf8))
    }

    private enum TestFailure: Error { case providerDidNotStart }
}

@MainActor
private final class LogRefreshFixture {
    let gates: [LogURLGate]
    let provider: LogURLProvider
    let model: LoggingViewModel
    private var tasks = [Task<Void, Never>]()

    init(gates: [LogURLGate]) {
        let provider = LogURLProvider(gates: gates)
        self.gates = gates
        self.provider = provider
        model = LoggingViewModel(loadLogURLs: { try await provider.load() })
    }

    func start(onReturn: @escaping @MainActor () -> Void = {}) -> Task<Void, Never> {
        let task = Task { @MainActor in
            await model.load()
            onReturn()
        }
        tasks.append(task)
        return task
    }

    func joinTasks() async {
        tasks.forEach { $0.cancel() }
        for gate in gates { await gate.release() }
        for task in tasks { await task.value }
    }
}

private actor LogURLProvider {
    private let gates: [LogURLGate]
    private(set) var invocationCount = 0

    init(gates: [LogURLGate]) { self.gates = gates }

    func load() async throws -> [URL] {
        let index = invocationCount
        invocationCount += 1
        guard gates.indices.contains(index) else { throw UnexpectedLoad() }
        return await gates[index].load()
    }

    private struct UnexpectedLoad: Error {}
}

private actor LogURLGate {
    nonisolated let url: URL
    nonisolated let started = XCTestExpectation(description: "Log URL provider started")
    nonisolated let cancelled = XCTestExpectation(description: "Log URL provider observed cancellation")
    private(set) var didStart = false
    private var isReleased = false
    private var continuation: CheckedContinuation<[URL], Never>?

    init(url: URL) { self.url = url }

    func load() async -> [URL] {
        // Deliberately noncooperative. Cancellation is observable but the
        // worker cannot settle until the test releases its original URL.
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if isReleased {
                    continuation.resume(returning: [url])
                } else {
                    self.continuation = continuation
                }
                didStart = true
                started.fulfill()
            }
        } onCancel: {
            self.cancelled.fulfill()
        }
    }

    func release() {
        isReleased = true
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(returning: [url])
    }
}

final class ReferralCodeUsageMutationTrackingTests: XCTestCase {
    @RealmBackgroundActor
    private final class Completion {
        var started = false
        var settled = false
    }

    private enum SettlementFailure: Error {
        case queuedCallerDidNotSettle
    }

    @RealmBackgroundActor
    private func waitForSettlement(_ completion: Completion) async -> Bool {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        while !completion.settled,
              DispatchTime.now().uptimeNanoseconds - startedAt < 2_000_000_000 {
            do {
                try await Task.sleep(nanoseconds: 1_000_000)
            } catch {
                await Task.yield()
            }
        }
        return completion.settled
    }

    @RealmBackgroundActor
    private func joinedResult(
        _ caller: Task<Void, Error>, completion: Completion
    ) async throws -> Result<Void, Error> {
        guard await waitForSettlement(completion) else {
            XCTFail("Queued referral caller did not settle after the owner released its write")
            throw SettlementFailure.queuedCallerDidNotSettle
        }
        // The completion latch is set in the task's final synchronous defer.
        // Only join once its operation has ended; do not hide a timeout in an
        // unbounded wait on the same operation this regression is exercising.
        return await caller.result
    }

    @RealmBackgroundActor
    private func cleanUpCaller(
        _ caller: Task<Void, Error>, completion: Completion, in realm: Realm
    ) async {
        caller.cancel()
        if realm.isInWriteTransaction { realm.cancelWrite() }
        guard await waitForSettlement(completion) else {
            XCTFail("Cancelled referral caller did not settle during bounded cleanup")
            return
        }
        _ = await caller.result
    }

    private func configuration() -> Realm.Configuration {
        var configuration = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
        configuration.objectTypes = [ReferralCodeUsage.self, BigSyncPendingMutation.self]
        BigSyncMutationTracking.install(configurations: [configuration], excludedClassNames: [])
        return configuration
    }

    @RealmBackgroundActor
    func testCancelledCreatePreservesIndependentOwnerUsageAndJournal() async throws {
        let configuration = configuration()
        let realm = try await RealmBackgroundActor.shared.cachedRealm(for: configuration)
        let completion = Completion()
        // Retain fixtures for unsettled SDK callbacks; otherwise await cleanup
        // on the concrete cache actor rather than its global actor annotation.
        addTeardownBlock {
            let mayReleaseCache = await { @RealmBackgroundActor in
                !completion.started || completion.settled
            }()
            if mayReleaseCache {
                _ = await RealmBackgroundActor.shared.removeCachedRealm(for: configuration)
            }
        }
        defer {
            if realm.isInWriteTransaction { realm.cancelWrite() }
        }
        realm.beginWrite()
        let ownerUsage = ReferralCodeUsage()
        ownerUsage.referralCode = "independent-owner"
        realm.add(ownerUsage)
        ownerUsage.refreshChangeMetadata(explicitlyModified: true)
        let ownerRecord = "ReferralCodeUsage.\(ownerUsage.id.uuidString)"
        let ownerGeneration = try XCTUnwrap(realm.object(
            ofType: BigSyncPendingMutation.self, forPrimaryKey: ownerRecord
        )?.generation)
        let submitted = expectation(description: "Referral create submitted its own SDK begin ticket")
        let caller = Task { @RealmBackgroundActor in
            defer { completion.settled = true }
            try await RealmWriteSubmissionObservation.$willSubmit.withValue({ submitted.fulfill() }) {
                _ = try await ReferralCodeUsage.create(
                    referralCode: "cancelled-create", receipt: "cancelled-receipt",
                    realmConfiguration: configuration
                )
            }
        }
        completion.started = true
        do {
            await fulfillment(of: [submitted], timeout: 5)
            caller.cancel()
            let cancelledBeforeOwnerRelease = await waitForSettlement(completion)
            XCTAssertTrue(cancelledBeforeOwnerRelease,
                          "Cancellation must settle while another owner holds its write")
            XCTAssertTrue(realm.isInWriteTransaction)
            XCTAssertEqual(realm.objects(ReferralCodeUsage.self).count, 1)
            XCTAssertEqual(realm.objects(BigSyncPendingMutation.self).count, 1)
            XCTAssertEqual(realm.object(ofType: BigSyncPendingMutation.self,
                                        forPrimaryKey: ownerRecord)?.generation, ownerGeneration)
            // Release the real owner before bounded joining, even after timeout.
            if realm.isInWriteTransaction { try realm.commitWrite() }
            switch try await joinedResult(caller, completion: completion) {
            case .success:
                XCTFail("Cancelled referral creation must not report success")
            case .failure(is CancellationError):
                break
            case .failure(let error):
                XCTFail("Expected cancellation, received \(error)")
            }
        } catch {
            await cleanUpCaller(caller, completion: completion, in: realm)
            throw error
        }
        XCTAssertEqual(Array(realm.objects(ReferralCodeUsage.self).map(\.referralCode)), ["independent-owner"])
        XCTAssertEqual(realm.objects(BigSyncPendingMutation.self).count, 1)
        XCTAssertEqual(realm.object(ofType: BigSyncPendingMutation.self,
                                    forPrimaryKey: ownerRecord)?.generation, ownerGeneration)
    }

    @RealmBackgroundActor
    func testCreateQueuesIndependentlyAndJournalsAfterOwnerRollback() async throws {
        let configuration = configuration()
        let realm = try await RealmBackgroundActor.shared.cachedRealm(for: configuration)
        let completion = Completion()
        // Retain fixtures for unsettled SDK callbacks; otherwise await cleanup
        // on the concrete cache actor rather than its global actor annotation.
        addTeardownBlock {
            let mayReleaseCache = await { @RealmBackgroundActor in
                !completion.started || completion.settled
            }()
            if mayReleaseCache {
                _ = await RealmBackgroundActor.shared.removeCachedRealm(for: configuration)
            }
        }
        defer {
            if realm.isInWriteTransaction { realm.cancelWrite() }
        }
        realm.beginWrite()
        let ownerUsage = ReferralCodeUsage()
        ownerUsage.referralCode = "rolled-back-owner"
        realm.add(ownerUsage)
        ownerUsage.refreshChangeMetadata(explicitlyModified: true)
        let submitted = expectation(description: "Referral create submitted behind the independent owner")
        let caller = Task { @RealmBackgroundActor in
            defer { completion.settled = true }
            try await RealmWriteSubmissionObservation.$willSubmit.withValue({ submitted.fulfill() }) {
                _ = try await ReferralCodeUsage.create(
                    referralCode: "committed-create", receipt: "committed-receipt",
                    realmConfiguration: configuration
                )
            }
        }
        completion.started = true
        do {
            await fulfillment(of: [submitted], timeout: 5)
            XCTAssertFalse(completion.settled)
            XCTAssertTrue(realm.isInWriteTransaction)
            XCTAssertEqual(Array(realm.objects(ReferralCodeUsage.self).map(\.referralCode)), ["rolled-back-owner"])
            if realm.isInWriteTransaction { realm.cancelWrite() }
            try await joinedResult(caller, completion: completion).get()
        } catch {
            await cleanUpCaller(caller, completion: completion, in: realm)
            throw error
        }
        XCTAssertFalse(realm.isInWriteTransaction)
        let usage = try XCTUnwrap(realm.objects(ReferralCodeUsage.self).first)
        XCTAssertEqual(realm.objects(ReferralCodeUsage.self).count, 1)
        XCTAssertEqual(usage.referralCode, "committed-create")
        XCTAssertEqual(usage.itunesReceipt, "committed-receipt")
        XCTAssertFalse(usage.wasSubmitted)
        XCTAssertNil(usage.lastAttemptedAt)
        let record = "ReferralCodeUsage.\(usage.id.uuidString)"
        let mutation = try XCTUnwrap(realm.object(ofType: BigSyncPendingMutation.self, forPrimaryKey: record))
        XCTAssertEqual(realm.objects(BigSyncPendingMutation.self).count, 1)
        XCTAssertEqual(mutation.entityType, ReferralCodeUsage.className())
        XCTAssertEqual(mutation.objectIdentifier, usage.id.uuidString)
        XCTAssertEqual(mutation.changedAt, usage.explicitlyModifiedAt)
    }

    @RealmBackgroundActor
    func testCreateRecordsDurableBigSyncMutationAfterAddingUsage() async throws {
        var configuration = Realm.Configuration(
            inMemoryIdentifier: UUID().uuidString
        )
        configuration.objectTypes = [
            ReferralCodeUsage.self,
            BigSyncPendingMutation.self,
        ]
        BigSyncMutationTracking.install(
            configurations: [configuration],
            excludedClassNames: []
        )

        let usage = try await ReferralCodeUsage.create(
            referralCode: "referral",
            receipt: "receipt",
            realmConfiguration: configuration
        )
        let realm = try await RealmBackgroundActor.shared.cachedRealm(
            for: configuration
        )
        let recordName = "ReferralCodeUsage.\(usage.id.uuidString)"
        let mutation = realm.object(
            ofType: BigSyncPendingMutation.self,
            forPrimaryKey: recordName
        )

        XCTAssertNotNil(mutation)
        XCTAssertEqual(mutation?.entityType, ReferralCodeUsage.className())
        XCTAssertEqual(mutation?.objectIdentifier, usage.id.uuidString)
        XCTAssertEqual(usage.explicitlyModifiedAt, mutation?.changedAt)
    }
}

final class AccountSessionStateTests: XCTestCase {
    @MainActor
    func testSessionRepairsIncompleteStoredCredentialsToSignedOut() {
        let store = InMemoryCredentialStore()
        store.stringValues[CredentialKeys.legacyUserID] = "42"

        let session = makeSession(using: store)

        XCTAssertEqual(session.observedAccountSessionSnapshot.identity, .signedOut)
        XCTAssertEqual(session.userID, -1)
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertNil(store.stringValues[CredentialKeys.legacyUserID])
    }

    @MainActor
    func testSessionRejectsStoredSignedOutSentinelAsAuthenticatedIdentity() {
        let store = InMemoryCredentialStore()
        store.stringValues[CredentialKeys.legacyAuthToken] = "token"
        store.stringValues[CredentialKeys.legacyUserID] = "-1"

        let session = makeSession(using: store)

        XCTAssertEqual(session.observedAccountSessionSnapshot.identity, .signedOut)
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertNil(store.stringValues[CredentialKeys.legacyAuthToken])
        XCTAssertNil(store.stringValues[CredentialKeys.legacyUserID])
    }

    @MainActor
    func testCanceledAuthenticationRequirementCannotCompleteSuccessfullyAfterDecision() async {
        let session = makeSession(
            using: InMemoryCredentialStore(),
            authenticationPresentationDelayNanoseconds: 100_000_000
        )
        let requirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.authenticated(authToken: "token", userID: 42)
        requirement.cancel()

        do {
            try await requirement.value
            XCTFail("A canceled authentication requirement must not receive success")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected cancellation, received \(error)")
        }
    }

    @MainActor
    func testLogoutCompletesAuthenticationRequirementThatIsAwaitingDecision() async {
        let session = makeSession(
            using: InMemoryCredentialStore(),
            authenticationPresentationDelayNanoseconds: 0
        )
        let requirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.logout()

        do {
            try await requirement.value
            XCTFail("Logging out must not leave an authentication requirement suspended")
        } catch SessionError.notAuthenticatedAsRequired {
        } catch {
            XCTFail("Expected logout rejection, received \(error)")
        }
    }

    @MainActor
    func testAuthenticationSuccessIsRejectedIfSessionChangesBeforeReturn() async {
        let session = makeSession(
            using: InMemoryCredentialStore(),
            authenticationPresentationDelayNanoseconds: 20_000_000
        )
        let requirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.authenticated(authToken: "token", userID: 42)
        session.logout()

        do {
            try await requirement.value
            XCTFail("A superseded authenticated session must not return success")
        } catch SessionError.notAuthenticatedAsRequired {
        } catch {
            XCTFail("Expected stale-session rejection, received \(error)")
        }
    }

    @MainActor
    func testInvalidAuthenticationPayloadFailsWithoutPersistingPartialCredentials() async {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        let requirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.authenticated(authToken: "", userID: -1)

        do {
            try await requirement.value
            XCTFail("Invalid credentials must not satisfy an authentication requirement")
        } catch SessionError.credentialStorageFailed {
        } catch {
            XCTFail("Expected credential storage failure, received \(error)")
        }
        XCTAssertEqual(session.observedAccountSessionSnapshot.identity, .signedOut)
        XCTAssertNil(store.stringValues[CredentialKeys.legacyAuthToken])
        XCTAssertNil(store.stringValues[CredentialKeys.legacyUserID])
    }

    @MainActor
    func testAuthenticationDecisionOnlyCompletesRequestsItCaptured() async throws {
        let session = makeSession(
            using: InMemoryCredentialStore(),
            authenticationPresentationDelayNanoseconds: 10_000_000
        )
        let canceledRequirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.cancelAuthentication()
        let successfulRequirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        for _ in 0..<10 {
            await Task.yield()
        }
        session.authenticated(authToken: "token", userID: 42)

        do {
            try await canceledRequirement.value
            XCTFail("The canceled presentation must retain its failure")
        } catch SessionError.notAuthenticatedAsRequired {
        } catch {
            XCTFail("Expected authentication cancellation, received \(error)")
        }
        try await successfulRequirement.value
    }

    @MainActor
    func testSessionPublishesSettledAuthenticationImmediately() {
        let session = makeSession(using: InMemoryCredentialStore())
        var snapshots = [AccountSessionSnapshot]()
        let observation = session.$observedAccountSessionSnapshot.sink {
            snapshots.append($0)
        }

        session.authenticated(authToken: "token", userID: 42)

        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 42)
        XCTAssertEqual(
            session.observedAccountSessionSnapshot,
            AccountSessionSnapshot(identity: .authenticated(userID: 42), generation: 1)
        )
        XCTAssertEqual(snapshots.map(\.identity), [
            .signedOut,
            .transitioning,
            .authenticated(userID: 42),
        ])
        withExtendedLifetime(observation) {}
    }

    func testTransitionSettlementKeepsItsGeneration() {
        var state = AccountSessionState()

        XCTAssertEqual(
            state.beginTransition(),
            AccountSessionSnapshot(identity: .transitioning, generation: 1)
        )
        XCTAssertEqual(
            state.settle(
                identity: .authenticated(userID: 42)
            ),
            AccountSessionSnapshot(identity: .authenticated(userID: 42), generation: 1)
        )
    }

    func testUnannouncedAccountChangeAdvancesGeneration() {
        var state = AccountSessionState()
        _ = state.settle(identity: .authenticated(userID: 42))

        XCTAssertEqual(
            state.settle(
                identity: .authenticated(userID: 7)
            ),
            AccountSessionSnapshot(identity: .authenticated(userID: 7), generation: 2)
        )
    }

    func testSameAccountReauthenticationGetsANewGeneration() {
        var state = AccountSessionState()
        _ = state.settle(identity: .authenticated(userID: 42))

        XCTAssertEqual(state.beginTransition().generation, 2)
        XCTAssertEqual(
            state.settle(
                identity: .authenticated(userID: 42)
            ),
            AccountSessionSnapshot(identity: .authenticated(userID: 42), generation: 2)
        )
    }

    func testUnchangedSettlementDoesNotAdvanceGeneration() {
        var state = AccountSessionState()

        XCTAssertEqual(
            state.settle(identity: .signedOut).generation,
            0
        )
        XCTAssertEqual(
            state.settle(identity: .signedOut).generation,
            0
        )
    }

    func testAccessRejectsPublicationFromAStaleGeneration() throws {
        let expected = AccountSessionSnapshot(
            identity: .authenticated(userID: 42),
            generation: 1
        )
        var current = expected
        let access = AccountSessionAccess(testSnapshotProvider: { current })
        current = AccountSessionSnapshot(identity: expected.identity, generation: 2)
        var didPublish = false

        let published = try access.publish(ifCurrent: expected) {
            didPublish = true
        }

        XCTAssertFalse(published)
        XCTAssertFalse(didPublish)
    }

    @MainActor
    private func waitForAuthenticationPresentation(_ session: Session) async {
        for _ in 0..<1_000 {
            if session.isPresentingWebAuthentication {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for authentication presentation")
    }

    @MainActor
    private func makeSession(
        using store: InMemoryCredentialStore,
        authenticationPresentationDelayNanoseconds: UInt64 = 0
    ) -> Session {
        Session(
            credentialStore: store.credentialStore,
            authenticationPresentationDelayNanoseconds:
                authenticationPresentationDelayNanoseconds
        )
    }
}

final class LakeKitPersistedLRUCacheDependencyTests: XCTestCase {
    func testPersistedCacheStoresAndReloadsValues() throws {
        let root = try makeTemporaryRoot()
        let namespace = "lakekit.persisted.\(UUID().uuidString)"

        let cache = PersistedCache<String, String>(
            namespace: namespace,
            compressionThreshold: .max,
            cacheRootURL: root
        )
        cache.setValue(String(repeating: "value", count: 8), forKey: "key")

        XCTAssertEqual(cache.value(forKey: "key"), String(repeating: "value", count: 8))
        XCTAssertEqual(
            PersistedCache<String, String>(
                namespace: namespace,
                compressionThreshold: .max,
                cacheRootURL: root
            ).value(forKey: "key"),
            String(repeating: "value", count: 8)
        )
    }

    func testSQLiteCacheStoresAndReloadsValues() throws {
        let root = try makeTemporaryRoot()
        let namespace = "lakekit.sqlite.\(UUID().uuidString)"

        let cache = LRUSQLiteCache<String, String>(namespace: namespace, cacheRootURL: root)
        cache.setValue("value", forKey: "key")

        XCTAssertEqual(cache.value(forKey: "key"), "value")
        XCTAssertEqual(
            LRUSQLiteCache<String, String>(namespace: namespace, cacheRootURL: root).value(forKey: "key"),
            "value"
        )
    }

    func testFileCacheStoresAndReloadsValues() throws {
        let root = try makeTemporaryRoot()
        let namespace = "lakekit.file.\(UUID().uuidString)"

        let cache = LRUFileCache<String, String>(namespace: namespace, cacheRootURL: root)
        cache.setValue("value", forKey: "key")

        XCTAssertEqual(cache.value(forKey: "key"), "value")
        XCTAssertEqual(
            LRUFileCache<String, String>(namespace: namespace, cacheRootURL: root).value(forKey: "key"),
            "value"
        )
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("LakeKitPersistedLRUCacheDependencyTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}

final class EnhancedSearchablePlatformPolicyTests: XCTestCase {
    func testResolvedPlacementAndHideabilityMatchPlatformPolicy() {
        XCTAssertFalse(
            EnhancedSearchablePlatformPolicy.canHide(hasPresentationBinding: false)
        )
        let resolvedPlacement = EnhancedSearchablePlatformPolicy.resolvedPlacement(
            .native(.toolbar)
        )

#if os(macOS)
        guard case .contentTop = resolvedPlacement else {
            return XCTFail("macOS enhanced search must use content-top placement")
        }
        XCTAssertFalse(
            EnhancedSearchablePlatformPolicy.canHide(hasPresentationBinding: true)
        )
#else
        guard case .native = resolvedPlacement else {
            return XCTFail("iOS enhanced search must preserve native placement")
        }
        XCTAssertTrue(
            EnhancedSearchablePlatformPolicy.canHide(hasPresentationBinding: true)
        )
#endif
    }
}

final class AccountSessionBoundaryIdentityTests: XCTestCase {
    @MainActor
    func testAccessValuesForOneSessionShareBoundaryIdentity() {
        let store = InMemoryCredentialStore()
        let session = Session(
            credentialStore: store.credentialStore,
            authenticationPresentationDelayNanoseconds: 0
        )

        XCTAssertEqual(
            AccountSessionAccess(session: session).boundaryID,
            AccountSessionAccess(session: session).boundaryID
        )
    }

    func testIndependentInjectedAccessValuesHaveDistinctBoundaryIdentities() {
        let snapshot = AccountSessionSnapshot(identity: .signedOut, generation: 0)

        XCTAssertNotEqual(
            AccountSessionAccess(testSnapshotProvider: { snapshot }).boundaryID,
            AccountSessionAccess(testSnapshotProvider: { snapshot }).boundaryID
        )
    }
}

@MainActor
private final class SubscriptionStatusGate {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var result: Bool?

    var isWaiting: Bool { continuation != nil }

    func wait() async -> Bool {
        if let result { return result }
        return await withCheckedContinuation { continuation = $0 }
    }

    func resolve(_ result: Bool) {
        self.result = result
        let pending = continuation
        continuation = nil
        pending?.resume(returning: result)
    }
}

@MainActor
final class StoreSubscriptionRefreshTests: XCTestCase {
    func testRetiredExternalStatusCannotOverwriteNewerSubscriptionRefresh() async throws {
        let defaults = UserDefaults.standard
        let previousSubscription = defaults.object(forKey: "LakeKit.isSubscribed")
        let previousExternalSubscription = defaults.object(forKey: "LakeKit.isSubscribedFromElsewhere")
        let previousAds = AdsViewModel.shared
        AdsViewModel.shared = AdsViewModel()
        defer {
            defaults.set(previousSubscription, forKey: "LakeKit.isSubscribed")
            defaults.set(previousExternalSubscription, forKey: "LakeKit.isSubscribedFromElsewhere")
            AdsViewModel.shared = previousAds
        }

        let entered = expectation(description: "Older external status request entered")
        let gate = SubscriptionStatusGate()
        var callbackCount = 0
        let model = makeStoreViewModel { _ in
            callbackCount += 1
            if callbackCount == 1 {
                entered.fulfill()
                // Deliberately completes after cancellation, as a caught
                // network error or non-cooperative provider can do.
                return await gate.wait()
            }
            return true
        }
        model.isSubscribed = false
        // Also keep the Debug pretend-subscribed fixture on the real callback path.
        model.isSubscribedFromElsewhere = true
        let storeHelper = StoreHelper()
        model.refreshIsSubscribed(storeHelper: storeHelper)
        let olderTask = try XCTUnwrap(model.subscriptionRefreshTask)
        defer {
            olderTask.cancel()
            model.subscriptionRefreshTask?.cancel()
            gate.resolve(false)
        }

        await fulfillment(of: [entered], timeout: 2)
        guard gate.isWaiting else {
            olderTask.cancel()
            gate.resolve(false)
            await olderTask.value
            return XCTFail("Older refresh did not suspend at the external status provider")
        }

        model.refreshIsSubscribed(storeHelper: storeHelper)
        let newerTask = try XCTUnwrap(model.subscriptionRefreshTask)
        await newerTask.value
        XCTAssertEqual(callbackCount, 2)
        XCTAssertTrue(model.isSubscribedFromElsewhere)
        XCTAssertTrue(model.isSubscribed)
        XCTAssertTrue(model.isInitialized)
        XCTAssertTrue(AdsViewModel.shared.isInitialized)
        XCTAssertFalse(AdsViewModel.shared.showAds)

        gate.resolve(false)
        await olderTask.value

        XCTAssertTrue(model.isSubscribedFromElsewhere)
        XCTAssertTrue(defaults.bool(forKey: "LakeKit.isSubscribedFromElsewhere"))
        XCTAssertTrue(model.isSubscribed)
        XCTAssertTrue(model.isInitialized)
        XCTAssertTrue(AdsViewModel.shared.isInitialized)
        XCTAssertFalse(AdsViewModel.shared.showAds)
    }

    private func makeStoreViewModel(
        externalStatus: @escaping (StoreViewModel) async -> Bool
    ) -> StoreViewModel {
        let url = URL(string: "https://example.invalid")!
        return StoreViewModel(
            products: [], studentProducts: [], highlightedProductID: "unused",
            headline: "", subheadline: "", productGroupHeading: "",
            productGroupSubtitle: nil, freeTierExplanation: nil,
            awardTitle: nil, awardImage: nil, awardTestimonial: "", awardLink: nil,
            benefits: [], termsOfService: url, privacyPolicy: url,
            faq: [:], isSubscribedFromElsewhereCallback: externalStatus
        )
    }
}
