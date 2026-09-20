# Checkpoint — Haze SG

**Resume here:** Phases 0-2 COMPLETE. 53 tests green. The app builds, runs
in the simulator and shows live NEA data.

Next concrete action: Phase 3 is already half done (OpenMeteoSource exists
and is wired into the app's AirQualityService), so go to Phase 4: the
Compare screen. Build a CompareViewModel over `Snapshot.comparison(of:in:)`,
showing each source's 1-hour PM2.5 side by side with the spread, each row
labelled measured vs modelled, and `SourceDescriptor.caveat` as the
explanation for why they differ.

## Build and run

    xcodegen generate                 # .xcodeproj is gitignored, regenerate it
    cd Packages/HazeSGKit && swift test
    HAZE_LIVE=1 swift test            # hits the real endpoints
    xcodebuild -project HazeSG.xcodeproj -scheme HazeSG \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
      -derivedDataPath build build

The built app lands at
`build/Build/Products/Debug-iphonesimulator/Haze SG.app`.

## Deploying to the physical iPhone

Device is "Choco PRO", an iPhone 18 Pro, UDID 00008160-0014658108834036.
Signing team KNLTNXVHSU, automatic provisioning.

    xcodebuild -project HazeSG.xcodeproj -scheme HazeSG \
      -destination 'platform=iOS,id=00008160-0014658108834036' \
      -derivedDataPath build-device -allowProvisioningUpdates build
    xcrun devicectl device install app --device 00008160-0014658108834036 \
      "build-device/Build/Products/Debug-iphoneos/Haze SG.app"
    xcrun devicectl device process launch --device 00008160-0014658108834036 \
      com.dchocoboo.hazesg

Gotchas hit while doing this:
- The launch step fails with "Locked" unless the phone is actually unlocked.
  Installing works while locked; launching does not.
- A fresh install lands on the last home screen page or only in the App
  Library, so it can look like it did not install. Verify with
  `xcrun devicectl device info apps --device <UDID> | grep hazesg`.
- If the icon is there but will not open, check Developer Mode under
  Settings > Privacy & Security. Off by default on iOS 16+, needs a restart.
- Signed with an Apple Development certificate. If KNLTNXVHSU is a free
  personal team the app stops launching after 7 days and must be reinstalled;
  a paid team gets a year.
- There is no iPhone 18 Pro simulator available: that device type needs a
  runtime newer than the installed iOS 26.5. Use iPhone 17 Pro for simulator
  work, or download a newer runtime through Xcode.

Run tests with: `cd Packages/HazeSGKit && swift test`
Run live integration tests with: `HAZE_LIVE=1 swift test`
Repo: https://github.com/dchocoboo/haze-sg

Plan: `/Users/david/.claude/plans/system-reminder-the-user-started-swift-valiant.md`

## Context a fresh session needs

- iPhone app, SwiftUI, iOS 18 min, Swift 6 strict concurrency. Xcode 27.
- **No backend.** Everything in-app. History is out of scope by user decision.
- Two questions the app answers: "is it bad right now" and "do the sources
  agree right now".
- Headline comparison rule: compare **1-hour mean PM2.5 in µg/m³ only**.
  NEA `pm25_one_hourly` and Open-Meteo hourly `pm2_5` match on metric, unit
  and window. Never compare PSI against another source's index.
- Keyless sources (NEA, Open-Meteo) ship working. PurpleAir + Google are
  optional, user pastes own key into Settings, stored in Keychain.
- No secrets in the repo, ever.

## Verified live 2026-09-20 12:45 SGT

- `https://api-open.data.gov.sg/v2/real-time/api/psi` → 200, no key
- `https://api-open.data.gov.sg/v2/real-time/api/pm25` → 200, no key
- `https://air-quality-api.open-meteo.com/v1/air-quality` → 200, no key
- Real haze that day: 24h PSI central 112, west 101, east 92, south 83,
  north 80. Good non-trivial value to assert against.
- NEA region coords: north 1.41803/103.82, south 1.29587/103.82,
  east 1.35735/103.94, west 1.35735/103.70, central 1.35735/103.82

## Tasks

- [x] Phase 0 — repo scaffolding + GitHub repo
- [x] Phase 1 — Reading model, NEA parser, Open-Meteo parser,
      SourceDescriptor, Comparison guard, AirQualitySource + AirQualityService,
      NEASource + OpenMeteoSource live clients. 38 tests green.
- [x] Phase 2 — Xcode project (xcodegen) + Now screen. Verified running in
      the simulator against live NEA data.
- [~] Phase 3 — Open-Meteo provider and concurrent fetch done in Phase 1 and
      wired into the app. Nothing shows it in the UI yet; that is Phase 4.
- [ ] Phase 4 — Compare screen + divergence calc + explanatory copy
- [ ] Phase 5 — Widgets. Full design in `docs/widgets.md`: Home Screen
      (small/medium/large), Lock Screen (circular/rectangular/inline),
      StandBy, and an iOS 18 ControlWidget for Control Center / Lock Screen
      button / Action Button. Two hard constraints: colour is stripped on
      several surfaces so severity must be encoded redundantly; and with no
      backend the widget fetches for itself on an hourly timeline sharing an
      App Group cache with the app.
- [ ] Phase 6 — Settings, Keychain, PurpleAir + Google providers (after spikes)
- [ ] Phase 7 — Release readiness: SG Open Data Licence attribution, privacy manifest

## Spikes still open

- PurpleAir: how many live sensors in SG? cost per fetch under points model?
- Google Air Quality: free quota workable? does it return `sgp_nea` for SG?
- WAQI: excluded. Public `demo` token is sandboxed (returns Shanghai for a
  Singapore query), so provenance and licence unconfirmed. Very likely an NEA
  passthrough.

## Notes / decisions

- NEA publishes the reading for hour N at about hour N, not on a fixed lag.
  Sampled 2026-09-20: 12:00 data seen at 12:45:40, 13:00 at 13:45:38, but
  14:00 at 14:00:37. `updatedTimestamp` moves as the record is republished
  within the hour, so the first two only recorded when the fetch happened.
  Do not build a 45-minute offset into the widget timeline.

- Logic lives in a local Swift package `Packages/HazeSGKit` so it is testable
  from the CLI with `swift test`, independent of Xcode and the simulator. The
  app target will depend on it. The Xcode project does not exist yet.
- Swift 6 strict concurrency rejects a `static let ISO8601DateFormatter`
  (not Sendable). Build one per call instead; parsing is rare enough.
- `Unit` collides with Foundation's `Unit` class. The enum is `ReadingUnit`.
- Open-Meteo timestamps are local-naive with `utc_offset_seconds` separate.
  Parsing as UTC silently puts SG readings 8h out. Test pins this.
- PSI bands (NEA): 0-50 Good, 51-100 Moderate, 101-200 Unhealthy,
  201-300 Very Unhealthy, 300+ Hazardous. 1h PM2.5 bands: 0-55 Normal,
  56-150 Elevated, 151-250 High, 251+ Very High.
- NEA advises using the 1-hour PM2.5, not the 24-hour PSI, for anything you
  are about to do in the next hour. The Now screen reflects this: PSI is the
  recognised headline, PM2.5 is badged "Use this one". When the two bands
  disagree (PSI still carrying earlier bad air on a clearing day) the app
  explains it rather than looking broken.
- Reading times are always rendered in SGT with an explicit suffix. A reading
  published for 14:00 in Singapore is a fact about Singapore; showing it in
  the phone's own timezone would silently show the wrong hour when travelling.
- The `.xcodeproj` is generated from `project.yml` and gitignored. Run
  `xcodegen generate` after cloning.
- Open-Meteo readings carry `region: nil` on purpose — one 40km cell cannot
  resolve NEA's five regions and pretending otherwise invents precision.
- `Comparison.build` is the safety rail: it throws on mixed metric, unit,
  window, or observations more than an hour apart. Verified by mutation —
  removing the window guard makes the test fail, as it should.

- Use data.gov.sg **v2** family. Legacy `api.data.gov.sg/v1/environment/*`
  still 200s but is deprecated.
- Open-Meteo snaps SG to a ~40km cell at 1.40/103.80 — city-wide sanity check
  only, cannot resolve NEA's 5 regions. Must be said in the UI.
- PurpleAir optical sensors over-read in high humidity (i.e. most of the time
  in SG). Must be said in the UI.
