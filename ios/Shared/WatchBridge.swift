import Foundation
import WatchConnectivity

/// Syncs the latest ``AeyeSnapshot`` between iPhone and Apple Watch via WatchConnectivity.
///
/// Credentials stay on the iPhone. The Watch displays whatever snapshot the phone last pushed
/// (cached in ``WatchSnapshotCache`` for offline glances / complications).
@MainActor
public final class WatchBridge: NSObject, WCSessionDelegate {
    public static let shared = WatchBridge()

    public static let snapshotUserInfoKey = "aeyeSnapshotJSON"

    public private(set) var lastReceivedSnapshot: AeyeSnapshot?
    public var onSnapshotReceived: ((AeyeSnapshot) -> Void)?

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
        if let cached = WatchSnapshotCache.load() {
            lastReceivedSnapshot = cached
        }
#endif
    }

#if os(iOS)
    /// Push a fresh overview to the paired Watch (best-effort).
    public func send(snapshot: AeyeSnapshot) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? JSONEncoder.iso8601.encode(snapshot) else { return }
        let payload: [String: Any] = [Self.snapshotUserInfoKey: data]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else if session.isPaired, session.isWatchAppInstalled {
            session.transferUserInfo(payload)
        }
    }
#endif

#if os(watchOS)
    private func ingest(_ snapshot: AeyeSnapshot) {
        lastReceivedSnapshot = snapshot
        WatchSnapshotCache.save(snapshot)
        onSnapshotReceived?(snapshot)
    }
#endif

    // MARK: - WCSessionDelegate

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

#if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncoming(userInfo)
    }

    nonisolated private func handleIncoming(_ payload: [String: Any]) {
#if os(watchOS)
        guard let data = payload[Self.snapshotUserInfoKey] as? Data,
              let snapshot = try? JSONDecoder.iso8601.decode(AeyeSnapshot.self, from: data)
        else { return }
        Task { @MainActor in
            self.ingest(snapshot)
        }
#endif
    }
}

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
