import Foundation

public enum AeyeJSON {
    /// JSONSerialization turns numbers into `NSNumber` / `Int`, so `as? Double` often fails.
    public static func double(_ value: Any?) -> Double? {
        guard let value, !(value is NSNull) else { return nil }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            return number.doubleValue
        }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) }
        return nil
    }

    public static func int(_ value: Any?) -> Int? {
        guard let value = double(value), value.isFinite else { return nil }
        return Int(value)
    }

    public static func bool(_ value: Any?) -> Bool? {
        guard let value, !(value is NSNull) else { return nil }
        if let value = value as? Bool { return value }
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue
        }
        return nil
    }
}

public enum AeyeHTTP {
    public static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
}
