# Data sources

Research notes and verified API shapes. All endpoints below were checked live
on **2026-09-20** unless marked otherwise.

## The independence problem

NEA operates the only reference air quality monitoring network in Singapore.
Any service presenting an "official Singapore station" is re-serving NEA's
numbers. Comparing such a service against data.gov.sg compares NEA with itself
and will always show perfect agreement — it looks like corroboration and is
nothing of the sort.

A source earns a place in the Compare screen only if it is genuinely
independent: its own sensors, or its own model with no Singapore ground input.

## Verified: NEA via data.gov.sg

Use the **v2** family. The legacy `api.data.gov.sg/v1/environment/*` endpoints
still return 200 but are the deprecated generation — do not build on them.

No API key is required in practice; unauthenticated calls returned 200. An
`x-api-key` header raises the rate limit (limits reset every 10 seconds).

### `GET https://api-open.data.gov.sg/v2/real-time/api/psi`

Hourly. Envelope is `{code, data, errorMsg}`.

`data.regionMetadata[]` — five regions with fixed representative coordinates:

| region | latitude | longitude |
|---|---|---|
| north | 1.41803 | 103.82 |
| south | 1.29587 | 103.82 |
| east | 1.35735 | 103.94 |
| west | 1.35735 | 103.70 |
| central | 1.35735 | 103.82 |

These are representative points, **not polygons or station locations**.

`data.items[]` — each has `date`, `timestamp`, `updatedTimestamp` (both ISO 8601
with `+08:00`), and `readings`, keyed by:

```
psi_twenty_four_hourly      pm25_twenty_four_hourly   pm10_twenty_four_hourly
so2_twenty_four_hourly      co_eight_hour_max         o3_eight_hour_max
no2_one_hour_max
co_sub_index  o3_sub_index  pm10_sub_index  pm25_sub_index  so2_sub_index
```

Each of those maps region name → number.

### `GET https://api-open.data.gov.sg/v2/real-time/api/pm25`

Hourly. Same envelope and `regionMetadata`. `readings` has exactly one key:
`pm25_one_hourly`, region → µg/m³.

**This is the endpoint the comparison feature depends on** — a 1-hour mean
PM2.5 in µg/m³, which is directly comparable with other sources reporting the
same thing.

### Licence

Singapore Open Data Licence v1.0. Commercial use, redistribution and
modification are permitted. Requires a conspicuous notice crediting the source
agency with a link to the licence, and must not imply official endorsement.
App Store distribution is fine on these terms.

### Not available as an API

`haze.gov.sg` is an HTML portal only — PSI, PM2.5 bands, regional map graphics,
haze outlook text, ASMC satellite imagery, a wind overlay and a PDF health
advisory. There is no API; the same readings come from the data.gov.sg
endpoints above.

ASMC (`asmc.asean.org`) is a JS-rendered SPA. Its hotspot sub-page exposes
per-country `.txt` coordinate files for NOAA-20 passes, which is file-based
rather than a REST API. Relevant only if fire-hotspot attribution is added
later.

## Verified: Open-Meteo (CAMS)

`GET https://air-quality-api.open-meteo.com/v1/air-quality`

No key, no signup. Independent — a pure atmospheric composition model with no
Singapore ground-station input, which is exactly what makes it worth comparing.

Query used: `latitude=1.3521&longitude=103.8198&current=pm2_5,pm10,us_aqi&hourly=pm2_5`

**Resolution caveat, and it matters.** Singapore falls in the ~40 km global
CAMS domain, not the 11 km European one. Requesting 1.3521/103.8198 snapped the
response to **1.40/103.80** — which is approximately NEA's *north* region.

Observed at 13:00 SGT on 2026-09-20:

| | PM2.5 µg/m³ |
|---|---|
| Open-Meteo (grid point 1.40/103.80) | 21.9 |
| NEA north (1.41803/103.82) | 19 |
| NEA central | 36 |
| NEA west | 37 |

Against the region it is actually sampling, Open-Meteo is close. Against the
island as a whole it is badly wrong, because a single 40 km cell cannot contain
a 2× west-to-north gradient. **Treat Open-Meteo as a city-wide sanity check,
never as a per-region comparator, and say so in the UI.**

`past_days` and `forecast_days` parameters are available.

## Optional, user-supplied key

### PurpleAir — `api.purpleair.com/v1/sensors`

The truest independent ground measurement available for Singapore: real
low-cost optical PM sensors, privately owned, unaffiliated with NEA.

Two caveats. Low-cost optical sensors **over-read in high humidity**, which
describes Singapore most of the time — expect readings biased high, and say so
rather than presenting it as a neutral disagreement with NEA. And access has
been metered under a points model since 2022.

**Spike before building:** how many sensors actually report in Singapore, and
what does an on-demand fetch cost? If coverage is two sensors it is a curiosity,
not a comparator.

### Google Air Quality API

Part of Google Maps Platform. Its own model blending satellite, meteorological
and ground inputs — not a pure NEA mirror — and it conveniently computes an
`sgp_nea` PSI-style index, which makes it the one source that can be compared
against NEA *index to index* rather than only on raw PM2.5.

**Spike before building:** confirm the free monthly quota suits on-demand use,
and that `sgp_nea` is in fact returned for Singapore.

## Investigated and excluded

**WAQI / AQICN.** The public `demo` token is sandboxed — requesting
`/feed/singapore/` returned Shanghai, and `/search/?keyword=singapore` returned
Bangalore — so neither its Singapore provenance nor its licence terms could be
confirmed without signing up. It is very likely an NEA passthrough, and there
are secondhand reports that its terms bar use in paid applications. Excluded
for now; revisit with a real token if a mirror source is ever wanted for
illustration.

**IQAir / AirVisual.** Its Singapore "official" station is NEA relayed. Its
community stations are genuinely independent and would be usable, but only if
the API lets them be distinguished from the official one — unverified.

**OpenAQ.** Singapore coverage appears thin to absent; NEA does not publish
into the channels OpenAQ ingests. Not a reliable source here.

**Sensor.Community.** Independent DIY network, but sparse coverage in Singapore.

**NASA FIRMS.** Satellite fire hotspots in Sumatra and Kalimantan. Not an air
quality measurement, but the standard companion dataset for explaining *why*
PSI spikes. A candidate for a later "why is it bad today" feature.
