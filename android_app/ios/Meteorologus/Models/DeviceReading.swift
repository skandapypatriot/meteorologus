import Foundation

/// Mirrors the Flutter `DeviceReading` model.
/// A single telemetry snapshot pushed by a weather node.
struct DeviceReading {
    let key: String?
    let t: Double?   // temperature
    let h: Double?   // humidity
    let p: Double?   // pressure (hPa)
    let ts: Int?     // epoch seconds
    let weatherCode: Any?
    let forecast: [Any]?

    init(
        key: String? = nil,
        t: Double? = nil,
        h: Double? = nil,
        p: Double? = nil,
        ts: Int? = nil,
        weatherCode: Any? = nil,
        forecast: [Any]? = nil
    ) {
        self.key = key
        self.t = t
        self.h = h
        self.p = p
        self.ts = ts
        self.weatherCode = weatherCode
        self.forecast = forecast
    }

    /// Parses a single node reading from arbitrary JSON (Firebase RTDB values).
    static func fromJson(_ json: Any?, key: String?) -> DeviceReading {
        guard let json = json else {
            return DeviceReading(key: key)
        }

        guard let raw = json as? [String: Any] else {
            return DeviceReading(key: key)
        }

        func asDouble(_ val: Any?) -> Double? {
            if let n = val as? NSNumber { return n.doubleValue }
            if let s = val as? String  { return Double(s) }
            return nil
        }

        func asInt(_ val: Any?) -> Int? {
            if let n = val as? NSNumber { return n.intValue }
            if let s = val as? String   { return Int(s) }
            return nil
        }

        func asList(_ val: Any?) -> [Any]? {
            if let arr = val as? [Any] { return arr }
            if let map = val as? [String: Any] { return Array(map.values) }
            return nil
        }

        return DeviceReading(
            key: key,
            t: asDouble(raw["t"]),
            h: asDouble(raw["h"]),
            p: asDouble(raw["p"]),
            ts: asInt(raw["ts"]),
            weatherCode: raw["weather_code"] ?? raw["weatherCode"],
            forecast: asList(raw["forecast"])
        )
    }
}