import Foundation
import WatchConnectivity

/// Syncs the latest ``AeyeSnapshot`` between iPhone and Apple Watch via WatchConnectivity.
///
/// Credentials stay on the iPhone. The Watch displays whatever snapshot the phone last pushed
/// (cached in ``WatchSnapshotCache`` for offline glances / complications), and can ask the phone
/// for a fresh one — the request wakes the iOS app in the background and the reply carries the
/// new snapshot.
@MainActor
public final class WatchBridge: NSObject, WCSessionDelegate {
    public static let shared = WatchBridge()

    nonisolated public static let snapshotUserInfoKey = "aeyeSnapshotJSON"
    nonisolated public static let refreshRequestKey = "aeyeRefreshRequest"

    public private(set) var lastReceivedSnapshot: AeyeSnapshot?
    public var onSnapshotReceived: ((AeyeSnapshot) -> Void)?
    /// iPhone side: asked to produce a fresh snapshot because the Watch requested one.
    public var onRefreshRequested: (() async -> AeyeSnapshot)?

    private var pendingSnapshot: AeyeSnapshot?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    private override init() {
        super.init()
    }

    public func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
#if os(watchOS)
        ingestIncoming(session.receivedApplicationContext)
        if lastReceivedSnapshot == nil, let cached = WatchSnapshotCache.load() {
            lastReceivedSnapshot = cached
        }
#endif
    }

#if os(iOS)
    /// Push a fresh overview to the paired Watch (best-effort).
    public func send(snapshot: AeyeSnapshot) {
        pendingSnapshot = snapshot
        flush()
    }

    private func flush() {
        guard let snapshot = pendingSnapshot else { return }
        guard let session, session.activationState == .activated else { return }
        guard let payload = Self.payload(for: snapshot) else { return }

        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    /// Run the host app's refresh for a Watch-initiated request and push the result back.
    private func handleRefreshRequest(reply: (([String: Any]) -> Void)?) {
        guard let onRefreshRequested else {
            reply?([:])
            return
        }
        Task { @MainActor in
            let snapshot = await onRefreshRequested()
            reply?(Self.payload(for: snapshot) ?? [:])
        }
    }
#endif

#if os(watchOS)
    public enum RefreshOutcome: Sendable {
        /// The phone answered with a fresh snapshot.
        case updated(AeyeSnapshot)
        /// The phone was out of reach; the request is queued for the next connection.
        case queued
        case failed(String)
    }

    /// Ask the iPhone for a fresh overview. Wakes the iOS app in the background when reachable.
    public func requestRefresh() async -> RefreshOutcome {
        guard let session else { return .failed("Watch link unavailable") }
        guard session.activationState == .activated else {
            activate()
            return .failed("Watch link not ready — try again")
        }

        let payload: [String: Any] = [Self.refreshRequestKey: true]
        guard session.isReachable else {
            session.transferUserInfo(payload)
            return .queued
        }

        let reply: [String: Any]? = await withCheckedContinuation { continuation in
            let box = ReplyBox(continuation)
            session.sendMessage(
                payload,
                replyHandler: { box.resume($0) },
                errorHandler: { _ in box.resume(nil) }
            )
        }

        guard let reply, let snapshot = Self.decodeSnapshot(from: reply) else {
            return .failed("iPhone didn't answer")
        }
        ingest(snapshot)
        return .updated(snapshot)
    }

    private func ingest(_ snapshot: AeyeSnapshot) {
        lastReceivedSnapshot = snapshot
        WatchSnapshotCache.save(snapshot)
        onSnapshotReceived?(snapshot)
    }

    private func ingestIncoming(_ payload: [String: Any]) {
        guard let snapshot = Self.decodeSnapshot(from: payload) else { return }
        ingest(snapshot)
    }
#endif

    nonisolated private static func payload(for snapshot: AeyeSnapshot) -> [String: Any]? {
        guard let data = try? JSONEncoder.iso8601.encode(snapshot) else { return nil }
        return [snapshotUserInfoKey: data.base64EncodedString()]
    }

    nonisolated private static func decodeSnapshot(from payload: [String: Any]) -> AeyeSnapshot? {
        let raw = payload[snapshotUserInfoKey]
        let data: Data?
        if let dataValue = raw as? Data {
            data = dataValue
        } else if let string = raw as? String {
            data = Data(base64Encoded: string)
        } else {
            data = nil
        }
        guard let data else { return nil }
        return try? JSONDecoder.iso8601.decode(AeyeSnapshot.self, from: data)
    }

    // MARK: - WCSessionDelegate

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
#if os(iOS)
            self.flush()
#endif
#if os(watchOS)
            self.ingestIncoming(session.receivedApplicationContext)
#endif
        }
    }

#if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.flush()
        }
    }
#endif

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
#if os(iOS)
        guard message[Self.refreshRequestKey] != nil else {
            handleIncoming(message)
            replyHandler([:])
            return
        }
        Task { @MainActor in
            self.handleRefreshRequest(reply: replyHandler)
        }
#else
        handleIncoming(message)
        replyHandler([:])
#endif
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncoming(userInfo)
    }

    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncoming(applicationContext)
    }

    nonisolated private func handleIncoming(_ payload: [String: Any]) {
#if os(watchOS)
        guard let snapshot = Self.decodeSnapshot(from: payload) else { return }
        Task { @MainActor in
            self.ingest(snapshot)
        }
#endif
#if os(iOS)
        // A queued refresh request that arrived while the phone was unreachable:
        // refresh and let ``send(snapshot:)`` push the result back.
        guard payload[Self.refreshRequestKey] != nil else { return }
        Task { @MainActor in
            self.handleRefreshRequest(reply: nil)
        }
#endif
    }
}

#if os(watchOS)
/// Guarantees the WatchConnectivity reply/error pair resumes the continuation exactly once.
private final class ReplyBox: @unchecked Sendable {
    private let continuation: CheckedContinuation<[String: Any]?, Never>
    private let lock = NSLock()
    private var resumed = false

    init(_ continuation: CheckedContinuation<[String: Any]?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: [String: Any]?) {
        lock.lock()
        let alreadyResumed = resumed
        resumed = true
        lock.unlock()
        guard !alreadyResumed else { return }
        continuation.resume(returning: value)
    }
}
#endif

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
