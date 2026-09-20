import SwiftUI
import WidgetKit
import HazeSGKit

/// Shared styling. Colour is never the message here: several widget surfaces
/// strip it out entirely — Lock Screen widgets render vibrant, tinted Home
/// Screens render accented, StandBy adds a red wash at night — so every
/// reading is accompanied by its band word, and severity also shows as a
/// gauge fill. Colour is reinforcement only.
private extension PM25Band {
    var color: Color {
        switch self {
        case .normal: Color(red: 0.16, green: 0.65, blue: 0.40)
        case .elevated: Color(red: 0.85, green: 0.70, blue: 0.13)
        case .high: Color(red: 0.90, green: 0.49, blue: 0.13)
        case .veryHigh: Color(red: 0.84, green: 0.22, blue: 0.22)
        }
    }
}

private extension Region {
    var label: String {
        switch self {
        case .north: "North"
        case .south: "South"
        case .east: "East"
        case .west: "West"
        case .central: "Central"
        }
    }
}

struct HazeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: HazeEntry

    private var tint: Color {
        // In accented and vibrant modes the system recolours everything, so
        // asking for our own colour there would be ignored at best and
        // muddy the contrast at worst.
        renderingMode == .fullColor
            ? (entry.conditions?.pm25Band.color ?? .secondary)
            : .primary
    }

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: - Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.region.label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let c = entry.conditions {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(c.pm25.rounded()))")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                    Text("µg/m³")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(c.pm25Band.label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                Text("PM2.5 · 1 hour")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
                psiFootnote(c)
            } else {
                unavailable
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(alignment: .center, spacing: 16) {
            small
            if let c = entry.conditions {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    labelled("24-hour PSI", value: c.psi.map { "\(Int($0.rounded()))" } ?? "–",
                             detail: c.psiBand?.label)
                    if c.readingsDisagree {
                        Text("PSI is a 24-hour average, so it still carries earlier air.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(c.observedAtDescription)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func labelled(_ title: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.title2.weight(.semibold)).monospacedDigit()
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func psiFootnote(_ c: Conditions) -> some View {
        Text(c.psi.map { "PSI \(Int($0.rounded()))" } ?? " ")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Lock Screen

    private var inline: some View {
        if let c = entry.conditions {
            Text("PM2.5 \(Int(c.pm25.rounded())) · \(c.pm25Band.label)")
        } else {
            Text("Haze SG –")
        }
    }

    private var circular: some View {
        Gauge(value: entry.conditions?.severity ?? 0) {
            Text("PM")
        } currentValueLabel: {
            Text(entry.conditions.map { "\(Int($0.pm25.rounded()))" } ?? "–")
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.region.label.uppercased())
                .font(.caption2.weight(.semibold))
            if let c = entry.conditions {
                Text("\(Int(c.pm25.rounded())) µg/m³ · \(c.pm25Band.label)")
                    .font(.headline)
                Text(c.psi.map { "PSI \(Int($0.rounded()))" } ?? "PM2.5, 1 hour")
                    .font(.caption2)
            } else {
                Text("No reading").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("–").font(.system(size: 40, weight: .bold, design: .rounded))
            Text("No reading").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
