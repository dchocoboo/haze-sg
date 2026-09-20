import Foundation
import Observation

/// Drives the Now screen: what the air is doing right now, in one region.
@MainActor
@Observable
public final class NowViewModel {

    public var selectedRegion: Region = .central
    public private(set) var snapshot: Snapshot?
    public private(set) var isLoading = false

    private let service: AirQualityService

    public init(service: AirQualityService) {
        self.service = service
    }

    public func load() async {
        isLoading = true
        snapshot = await service.fetchAll()
        isLoading = false
    }

    // MARK: - Readings for the selected region

    public var psi: Double? {
        value(of: .psi, from: .nea)
    }

    public var psiBand: PSIBand? {
        psi.map(PSIBand.init(psi:))
    }

    public var pm25: Double? {
        value(of: .pm2_5, from: .nea)
    }

    public var pm25Band: PM25Band? {
        pm25.map(PM25Band.init(microgramsPerCubicMetre:))
    }

    public var observedAt: Date? {
        snapshot?.readings.first { $0.source == .nea }?.observedAt
    }

    /// The observation time, always rendered in Singapore time.
    ///
    /// A reading published for 14:00 in Singapore is a fact about Singapore.
    /// Rendering it in the phone's own timezone would show the wrong hour to
    /// anyone travelling, with nothing on screen to say so — hence the
    /// explicit SGT suffix.
    public var observedAtDescription: String? {
        guard let observedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Singapore")
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: observedAt)) SGT"
    }

    /// True when the 24-hour PSI and the 1-hour PM2.5 are telling different
    /// stories — typically a clearing day, where PSI still carries earlier
    /// bad air while the air outside right now is fine.
    ///
    /// Worth surfacing rather than hiding: two numbers that look
    /// contradictory make the app look broken unless it explains them, and
    /// NEA's own advice is to act on the 1-hour PM2.5.
    public var psiAndPM25Disagree: Bool {
        guard let psiBand, let pm25Band else { return false }
        switch (psiBand, pm25Band) {
        case (.good, .normal), (.moderate, .normal):
            return false
        case (_, .normal):
            return true
        case (.good, _), (.moderate, _):
            return true
        default:
            return false
        }
    }

    /// Every source failed or none is configured. Distinct from "still
    /// loading" and from "one source is down but we have the rest".
    public var hasNoData: Bool {
        guard let snapshot else { return false }
        return snapshot.readings.isEmpty
    }

    /// Sources that failed this fetch, for a quiet note rather than an alert.
    public var failedSources: [SourceID] {
        Array(snapshot?.failures.keys ?? [:].keys).sorted { $0.rawValue < $1.rawValue }
    }

    private func value(of metric: Metric, from source: SourceID) -> Double? {
        snapshot?.readings.first {
            $0.source == source && $0.metric == metric && $0.region == selectedRegion
        }?.value
    }
}
