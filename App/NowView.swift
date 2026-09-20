import SwiftUI
import HazeSGKit

struct NowView: View {
    @State var model: NowViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    regionPicker

                    if model.hasNoData {
                        noDataNotice
                    } else {
                        psiCard
                        pm25Card
                        if model.psiAndPM25Disagree { disagreementNote }
                    }

                    if !model.failedSources.isEmpty { failureNote }
                    footer
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Haze SG")
            .refreshable { await model.load() }
            .overlay { if model.isLoading && model.snapshot == nil { ProgressView() } }
        }
        .task { await model.load() }
    }

    // MARK: - Region

    private var regionPicker: some View {
        Picker("Region", selection: $model.selectedRegion) {
            ForEach(Region.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.top, 8)
    }

    // MARK: - PSI

    private var psiCard: some View {
        VStack(spacing: 6) {
            Text("24-hour PSI")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(model.psi.map { String(Int($0.rounded())) } ?? "–")
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            if let band = model.psiBand {
                Text(band.label)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(band.color.opacity(0.18), in: Capsule())
                    .foregroundStyle(band.color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - PM2.5

    private var pm25Card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("1-hour PM2.5")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Use this one")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.15), in: Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.pm25.map { String(Int($0.rounded())) } ?? "–")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("µg/m³")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if let band = model.pm25Band {
                    Text(band.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(band.color)
                }
            }

            Text("NEA advises using the 1-hour PM2.5 for anything you're about to do. PSI is a 24-hour average, so it lags.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Notes

    private var disagreementNote: some View {
        Label {
            Text("PSI and PM2.5 disagree because they cover different periods. The 24-hour PSI is still carrying earlier air; the 1-hour PM2.5 is what it's like outside now.")
        } icon: {
            Image(systemName: "info.circle.fill")
        }
        .font(.footnote)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }

    private var failureNote: some View {
        Label(
            "Couldn't reach: \(model.failedSources.map(\.rawValue).joined(separator: ", "))",
            systemImage: "exclamationmark.triangle"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noDataNotice: some View {
        ContentUnavailableView(
            "No readings",
            systemImage: "wifi.slash",
            description: Text("Couldn't reach any air quality source. Pull to try again.")
        )
        .padding(.top, 40)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if let observedAt = model.observedAtDescription {
                Text("Reading for \(observedAt)")
            }
            Text("Data from NEA via data.gov.sg, under the Singapore Open Data Licence. Not endorsed by NEA.")
                .multilineTextAlignment(.center)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.top, 4)
    }
}
