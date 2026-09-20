import Foundation

/// Parses the data.gov.sg v2 real-time air quality envelopes into `Reading`s.
///
/// Uses the v2 endpoint family (`api-open.data.gov.sg/v2/real-time/api/...`).
/// The legacy `api.data.gov.sg/v1/environment/*` endpoints still respond but
/// are the deprecated generation.
public enum NEAParser {

    public enum ParseError: Error, Equatable {
        case noItems
        case badTimestamp(String)
    }

    // MARK: - Wire format

    private struct Envelope: Decodable {
        let data: Payload
        struct Payload: Decodable {
            let items: [Item]
        }
        struct Item: Decodable {
            let timestamp: String
            let readings: [String: [String: Double]]
        }
    }

    // MARK: - PSI

    public static func parsePSI(_ data: Data) throws -> [Reading] {
        let item = try latestItem(in: data)
        let observedAt = try parseTimestamp(item.timestamp)

        return regionValues(item.readings["psi_twenty_four_hourly"]).map {
            region, value in
            Reading(
                source: .nea,
                region: region,
                metric: .psi,
                unit: .index,
                windowMinutes: 1440,
                observedAt: observedAt,
                value: value
            )
        }
    }

    // MARK: - PM2.5

    /// Parses the 1-hour mean PM2.5 endpoint.
    ///
    /// This is the reading the Compare screen is built on: a 1-hour mean in
    /// micrograms per cubic metre is directly comparable with other sources
    /// publishing the same thing, which PSI is not.
    public static func parsePM25(_ data: Data) throws -> [Reading] {
        let item = try latestItem(in: data)
        let observedAt = try parseTimestamp(item.timestamp)

        return regionValues(item.readings["pm25_one_hourly"]).map { region, value in
            Reading(
                source: .nea,
                region: region,
                metric: .pm2_5,
                unit: .microgramsPerCubicMetre,
                windowMinutes: 60,
                observedAt: observedAt,
                value: value
            )
        }
    }

    // MARK: - Helpers

    private static func latestItem(in data: Data) throws -> Envelope.Item {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let item = envelope.data.items.last else { throw ParseError.noItems }
        return item
    }

    /// Maps a `{"north": 77, ...}` block to typed regions, dropping any
    /// region name NEA might add that this app does not know about.
    private static func regionValues(
        _ block: [String: Double]?
    ) -> [(Region, Double)] {
        guard let block else { return [] }
        return block.compactMap { name, value in
            guard let region = Region(rawValue: name) else { return nil }
            return (region, value)
        }
    }

    /// `ISO8601DateFormatter` is not `Sendable`, so it cannot be held in a
    /// `static let` under Swift 6. Parsing happens a handful of times per
    /// fetch, so building one per call is not worth working around.
    private static func parseTimestamp(_ raw: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: raw) else {
            throw ParseError.badTimestamp(raw)
        }
        return date
    }
}
