import Testing
import Foundation
@testable import HazeSGKit

@Suite("PSI bands")
struct PSIBandTests {

    @Test("classifies PSI at NEA's published boundaries", arguments: [
        (0.0, PSIBand.good), (50.0, .good),
        (51.0, .moderate), (100.0, .moderate),
        (101.0, .unhealthy), (200.0, .unhealthy),
        (201.0, .veryUnhealthy), (300.0, .veryUnhealthy),
        (301.0, .hazardous), (500.0, .hazardous)
    ])
    func classifiesPSI(value: Double, expected: PSIBand) {
        #expect(PSIBand(psi: value) == expected)
    }

    @Test("today's central reading of 104 is Unhealthy")
    func todaysReading() {
        // Sampled live 2026-09-20 14:00 SGT.
        #expect(PSIBand(psi: 104) == .unhealthy)
    }

    @Test("every band has a label that can stand in for the colour")
    func bandsHaveLabels() {
        // Lock Screen and tinted widgets strip colour, so the word carries
        // the meaning on its own.
        for band in PSIBand.allCases {
            #expect(!band.label.isEmpty)
        }
    }
}

@Suite("1-hour PM2.5 bands")
struct PM25BandTests {

    @Test("classifies PM2.5 at NEA's published boundaries", arguments: [
        (0.0, PM25Band.normal), (55.0, .normal),
        (56.0, .elevated), (150.0, .elevated),
        (151.0, .high), (250.0, .high),
        (251.0, .veryHigh), (400.0, .veryHigh)
    ])
    func classifiesPM25(value: Double, expected: PM25Band) {
        #expect(PM25Band(microgramsPerCubicMetre: value) == expected)
    }

    @Test("today's central reading of 36 is Normal despite PSI being Unhealthy")
    func psiAndPM25CanDisagree() {
        // Live 2026-09-20: central PSI 104 (Unhealthy, a 24-hour average)
        // while 1-hour PM2.5 was 36 (Normal). Not a contradiction -- the PSI
        // is still carrying earlier, worse air. NEA advises the 1-hour PM2.5
        // for what you are about to do, which is why the app shows both.
        #expect(PSIBand(psi: 104) == .unhealthy)
        #expect(PM25Band(microgramsPerCubicMetre: 36) == .normal)
    }
}
