import Foundation

public enum SnapshotStore {
    public static let appGroupID = "group.com.giovanni.aeye"
    private static let snapshotFile = "aeye-snapshot.json"
    private static let visibilityKey = "row-visibility-v1"
    private static let sampleDataKey = "sample-data-enabled-v1"

    /// Backs ``SampleDataMode``. Lives in the App Group so the preference and the
    /// sample snapshot it produces stay together.
    public static var isSampleDataEnabled: Bool {
        get { sharedDefaults?.bool(forKey: sampleDataKey) ?? false }
        set { sharedDefaults?.set(newValue, forKey: sampleDataKey) }
    }

    public static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    public static var isAvailable: Bool { snapshotURL() != nil }

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
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return group.appendingPathComponent(snapshotFile)
        }
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Aeye", isDirectory: true)
        if let dir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent(snapshotFile)
        }
        return nil
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID) ?? .standard
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
