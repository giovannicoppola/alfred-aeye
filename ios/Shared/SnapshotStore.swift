import Foundation

public enum SnapshotStore {
    public static let appGroupID = "group.com.giovanni.aeye"
    private static let snapshotFile = "aeye-snapshot.json"
    private static let visibilityKey = "row-visibility-v1"

    public static func save(_ snapshot: AeyeSnapshot) {
        guard let url = snapshotURL() else { return }
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Fail silently — widget falls back to last good snapshot.
        }
    }

    public static func load() -> AeyeSnapshot? {
        guard let url = snapshotURL(),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? decoder.decode(AeyeSnapshot.self, from: data)
    }

    public static func saveVisibility(_ visibility: RowVisibility) {
        guard let defaults = sharedDefaults else { return }
        if let data = try? encoder.encode(visibility) {
            defaults.set(data, forKey: visibilityKey)
        }
    }

    public static func loadVisibility() -> RowVisibility {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: visibilityKey),
              let visibility = try? decoder.decode(RowVisibility.self, from: data)
        else { return .allEnabled }
        return visibility
    }

    private static func snapshotURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(snapshotFile)
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
