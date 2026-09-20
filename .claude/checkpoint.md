# Checkpoint — Haze SG

**Resume here:** Phase 0 in progress. Next concrete action: finish repo
scaffolding (.gitignore, LICENSE, README, docs/sources.md), commit, then
`gh repo create dchocoboo/haze-sg --public --source=. --push`.

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

- [~] Phase 0 — repo scaffolding + GitHub repo
- [ ] Phase 1 — Reading model, AirQualitySource protocol, NEA provider + fixture tests
- [ ] Phase 2 — Now screen against NEA only
- [ ] Phase 3 — Open-Meteo provider, concurrent fetch, per-source failure handling
- [ ] Phase 4 — Compare screen + divergence calc + explanatory copy
- [ ] Phase 5 — WidgetKit extension
- [ ] Phase 6 — Settings, Keychain, PurpleAir + Google providers (after spikes)
- [ ] Phase 7 — Release readiness: SG Open Data Licence attribution, privacy manifest

## Spikes still open

- PurpleAir: how many live sensors in SG? cost per fetch under points model?
- Google Air Quality: free quota workable? does it return `sgp_nea` for SG?
- WAQI: excluded. Public `demo` token is sandboxed (returns Shanghai for a
  Singapore query), so provenance and licence unconfirmed. Very likely an NEA
  passthrough.

## Notes / decisions

- Use data.gov.sg **v2** family. Legacy `api.data.gov.sg/v1/environment/*`
  still 200s but is deprecated.
- Open-Meteo snaps SG to a ~40km cell at 1.40/103.80 — city-wide sanity check
  only, cannot resolve NEA's 5 regions. Must be said in the UI.
- PurpleAir optical sensors over-read in high humidity (i.e. most of the time
  in SG). Must be said in the UI.
