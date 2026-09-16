import Foundation

/// App Group cache for the last snapshot synced to Apple Watch (shared by Watch app + complications).
public enum WatchSnapshotCache {
    public static let appGroupID = "group.com.giovanni.aeye.watch"
    private static let key = "aeye.watch.cachedSnapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public static func load() -> AeyeSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(AeyeSnapshot.self, from: data)
    }

    public static func save(_ snapshot: AeyeSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
