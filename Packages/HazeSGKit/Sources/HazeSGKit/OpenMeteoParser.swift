import Foundation

/// Parses the Open-Meteo air quality response.
///
/// Open-Meteo serves CAMS model output. For Singapore that is the ~40 km
/// global domain rather than the 11 km European one, so a request is snapped
/// to a coarse grid point and a single value stands in for the whole island.
/// The parser surfaces that grid point so the UI can be honest about it.
public enum OpenMeteoParser {

    public enum ParseError: Error, Equatable {
        case badTimestamp(String)
    }

    /// Readings plus the grid point they actually describe.
    public struct Result: Sendable, Equatable {
        public let readings: [Reading]
        public let gridLatitude: Double
        public let gridLongitude: Double
    }

    private struct Envelope: Decodable {
        let latitude: Double
        let longitude: Double
        let utcOffsetSeconds: Int
        let current: Current

        struct Current: Decodable {
            let time: String
            let pm2_5: Double?
            let pm10: Double?
            let usAQI: Double?

            enum CodingKeys: String, CodingKey {
                case time
                case pm2_5 = "pm2_5"
                case pm10
                case usAQI = "us_aqi"
            }
        }

        enum CodingKeys: String, CodingKey {
            case latitude, longitude, current
            case utcOffsetSeconds = "utc_offset_seconds"
        }
    }

    public static func parse(_ data: Data) throws -> Result {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        let observedAt = try resolveTimestamp(
            envelope.current.time,
            offsetSeconds: envelope.utcOffsetSeconds
        )

        func reading(_ value: Double?, _ metric: Metric, _ unit: ReadingUnit) -> Reading? {
            guard let value else { return nil }
            return Reading(
                source: .openMeteo,
                // Deliberately nil: one 40 km cell cannot resolve NEA's five
                // regions, and pretending otherwise would invent precision.
                region: nil,
                metric: metric,
                unit: unit,
                // `current` is the model's value for the current hour, which
                // matches NEA's 1-hour mean and is what makes them comparable.
                windowMinutes: 60,
                observedAt: observedAt,
                value: value
            )
        }

        let readings = [
            reading(envelope.current.pm2_5, .pm2_5, .microgramsPerCubicMetre),
            reading(envelope.current.pm10, .pm10, .microgramsPerCubicMetre),
            reading(envelope.current.usAQI, .usAQI, .index)
        ].compactMap { $0 }

        return Result(
            readings: readings,
            gridLatitude: envelope.latitude,
            gridLongitude: envelope.longitude
        )
    }

    /// Open-Meteo returns a local naive timestamp such as `2026-09-20T13:00`
    /// alongside a separate `utc_offset_seconds`. Reading the string as UTC
    /// would put the reading eight hours out for Singapore and silently
    /// misalign it against NEA, which is exactly the kind of error the
    /// Compare screen would then present as a disagreement between sources.
    private static func resolveTimestamp(
        _ raw: String,
        offsetSeconds: Int
    ) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: offsetSeconds)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        guard let date = formatter.date(from: raw) else {
            throw ParseError.badTimestamp(raw)
        }
        return date
    }
}
