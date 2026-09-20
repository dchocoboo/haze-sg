# Haze SG

An iPhone app for checking Singapore's haze **right now** — and for seeing
whether the different air quality sources actually agree with each other.

Most AQI apps show you one number from one source. This one shows you several,
side by side, and is honest about why they differ.

## What it does

**Is it bad right now?** Current PSI and PM2.5 for each of NEA's five regions,
in the official colour bands, plus a home screen widget.

**Do the sources agree?** The same moment's air, measured and modelled by
different organisations, compared fairly — with the reasons for any divergence
spelled out rather than left as a mystery.

## Why comparing air quality sources is harder than it looks

Two things make a naive comparison meaningless, and this app is built around
avoiding both.

**Most "third-party" sources for Singapore are NEA passthroughs.** NEA operates
the only reference monitoring network in the country. A service showing an
"official Singapore station" is re-serving NEA's own numbers, so comparing it
against data.gov.sg compares NEA with itself and always shows perfect
agreement. Only genuinely independent sources are treated as corroboration
here; mirrors, if any are ever added, are labelled as mirrors.

**Averaging windows and index scales are not interchangeable.** NEA's PSI is a
24-hour average. NEA's PM2.5 is a 1-hour average. PurpleAir sensors report
near-instantaneously. Singapore PSI, US EPA AQI and raw µg/m³ are different
functions of the same underlying pollutant. Plot a 24-hour average against an
instantaneous reading and most of the gap you see is the method, not the air.

So the app has one rule: **the headline comparison is 1-hour mean PM2.5 in
µg/m³, and only that.** It happens to be exactly what NEA's `pm25_one_hourly`
and Open-Meteo's hourly `pm2_5` both already publish — same metric, same unit,
same window, no fudging. PSI is shown prominently because it is the number
Singaporeans recognise, but it is never compared against another source's
index, because nobody else computes it the same way.

## Sources

| Source | API key | Independent of NEA? | Notes |
|---|---|---|---|
| **NEA** via data.gov.sg | not needed | Reference ground truth | 24h PSI + sub-indices, 1h PM2.5, per region |
| **Open-Meteo** (CAMS model) | not needed | Yes — no Singapore ground input | ~40 km grid cell; city-wide sanity check, cannot resolve NEA's regions |
| **PurpleAir** | yours, optional | Yes — real sensors in Singapore | Low-cost optical sensors over-read in high humidity |
| **Google Air Quality** | yours, optional | Yes — own model | Reports an `sgp_nea` PSI-style index |

NEA and Open-Meteo need no setup and work on first launch. PurpleAir and Google
are optional: paste your own key into Settings and it is stored in the Keychain,
billed to your own account. **No API keys are committed to this repository.**

## Architecture

A single SwiftUI app. No backend, no server, nothing to deploy or pay for —
the app calls the APIs directly from the phone.

Every provider conforms to one `AirQualitySource` protocol and normalises into
a common `Reading` value carrying its metric, unit and averaging window, so a
comparison can never silently mix incompatible numbers. Sources are fetched
concurrently and independently: one failing or missing a key degrades that row
to an empty state and never blocks the others.

Requires iOS 18. Built with Swift 6 strict concurrency.

## Attribution

Air quality data for Singapore is provided by the National Environment Agency
(NEA) via [data.gov.sg](https://data.gov.sg), used under the
[Singapore Open Data Licence v1.0](https://data.gov.sg/open-data-licence).
This application is not endorsed by or affiliated with NEA or the Government
of Singapore.

## Licence

MIT — see [LICENSE](LICENSE).
