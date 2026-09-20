import Foundation

/// What the air is doing in one region, ready to render.
///
/// The 1-hour PM2.5 is the headline and is non-optional: NEA's advice is to
/// use it for anything you are about to do, and a `Conditions` without one
/// has nothing to lead with. PSI rides along as context — it is the number
/// people recognise, but as a 24-hour mean it lags and can still read badly
/// on a clearing day.
public struct Conditions: Sendable, Equatable {
    public let region: Region
    public let pm25: Double
    public let psi: Double?
    public let observedAt: Date

    public var pm25Band: PM25Band { PM25Band(microgramsPerCubicMetre: pm25) }
    public var psiBand: PSIBand? { psi.map(PSIBand.init(psi:)) }

    /// How full a gauge should be. Driven by the headline reading's band so
    /// severity is legible where colour is stripped out — Lock Screen
    /// widgets, tinted Home Screens, and for colour-blind readers.
    public var severity: Double { pm25Band.severity }

    /// True when the two readings tell different stories, typically a
    /// clearing day where PSI still carries earlier bad air.
    public var readingsDisagree: Bool {
        guard let psiBand else { return false }
        return switch (psiBand, pm25Band) {
        case (.good, .normal), (.moderate, .normal): false
        case (_, .normal): true
        case (.good, _), (.moderate, _): true
        default: false
        }
    }

    public init(region: Region, pm25: Double, psi: Double?, observedAt: Date) {
        self.region = region
        self.pm25 = pm25
        self.psi = psi
        self.observedAt = observedAt
    }

    public var observedAtDescription: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Singapore")
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: observedAt)) SGT"
    }
}

public extension Snapshot {
    /// Conditions for one region, or `nil` when there is no 1-hour PM2.5 to
    /// lead with.
    func conditions(for region: Region) -> Conditions? {
        func nea(_ metric: Metric) -> Reading? {
            readings.first {
                $0.source == .nea && $0.metric == metric && $0.region == region
            }
        }
        guard let pm25 = nea(.pm2_5) else { return nil }
        return Conditions(
            region: region,
            pm25: pm25.value,
            psi: nea(.psi)?.value,
            observedAt: pm25.observedAt
        )
    }
}
