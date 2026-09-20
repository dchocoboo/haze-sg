# Widgets

Everything you can add to a Home Screen, Lock Screen, StandBy display or
Control Center, and the constraints that shape how they have to look.

The app's core job is the three-second check — "is it bad right now?" — and
a widget answers that without opening anything. This is arguably the most
important surface in the project, not a nice-to-have bolted on at the end.

## What you can add

### Home Screen

| Family | Shows |
|---|---|
| `systemSmall` | One region: big PSI number, band word, 1h PM2.5 underneath, time of reading |
| `systemMedium` | One region large, plus the other four as a compact row — so you can see the island's spread at a glance |
| `systemLarge` | All five regions, plus the source comparison: NEA against whichever independent sources are configured, with the spread called out |

### Lock Screen

These are the ones you actually see most, because the Lock Screen is what
you look at when you pick the phone up.

| Family | Shows |
|---|---|
| `accessoryCircular` | A gauge, PSI against the band scale — the fullness of the ring *is* the reading |
| `accessoryRectangular` | Region, PSI, band word, and 1h PM2.5 on two lines |
| `accessoryInline` | A single line beside the clock: `PSI 104 · Unhealthy` |

### StandBy

StandBy reuses `systemSmall`, so the Home Screen small widget covers it. Worth
checking the design separately though: StandBy is viewed from across a room in
a dark bedroom, and at night it renders with a red tint, so the number needs to
be large and the design must not depend on the band colour.

### Control Center, Lock Screen buttons, and the Action Button

iOS 18's `ControlWidget` covers all three of these with one implementation.
`ControlWidgetButton` is driven by an App Intent, so:

- A **"Haze" control** in Control Center showing the current PSI and opening
  the app when tapped.
- The same control can be assigned to a **Lock Screen button** (replacing the
  torch or camera shortcut) or to the **Action Button** on Pro models.

`ControlValueProvider` is what lets the control display a live value rather
than a static icon.

## Configuration

Widgets are configured with an App Intent (`AppIntentConfiguration` plus a
`WidgetConfigurationIntent`), which gives two parameters:

- **Region** — one of NEA's five, or "nearest to me", resolved from location.
- **Metric** — PSI (the number Singaporeans recognise) or 1-hour PM2.5.

Because each widget instance holds its own configuration, you can put two
small widgets side by side showing, say, home and the office.

## The colour problem

This is the main design constraint and it is easy to miss until the widget
looks wrong on a real device.

The app's visual language is NEA's PSI colour bands — green through yellow,
orange, red. But several widget surfaces strip colour out:

- Lock Screen accessory widgets render in **vibrant** mode: everything becomes
  a monochrome tint of the wallpaper.
- iOS 18's **tinted** Home Screen renders widgets in **accented** mode, where
  your palette is replaced by the user's chosen tint.
- StandBy at night applies a red wash.

So severity must never be carried by colour alone. Every widget encodes it at
least twice: the **number**, the **band word** ("Moderate", "Unhealthy"), and
where there is room, a **gauge fill or bar length**. Colour becomes
reinforcement rather than the message.

Read `\.widgetRenderingMode` from the environment and adapt rather than
assuming full colour. The same discipline makes the app legible to
colour-blind users, which matters for a palette built on red/green.

## Refresh strategy

This is the real engineering constraint, because there is no backend — the
widget extension fetches for itself in its timeline provider.

**What NEA's publishing actually looks like.** Sampled 2026-09-20:

| Observation hour | Published at |
|---|---|
| 12:00 | 12:45:40 |
| 13:00 | 13:45:38 |
| 14:00 | 14:00:37 |

The first two suggested a 45-minute lag. The third disproves it — the 14:00
reading was available 37 seconds after the hour. `updatedTimestamp` moves as
NEA republishes the record *during* the hour, so the first two samples were
recording when the fetch happened, not when the data landed. Three samples is
not a pattern; treat the reading for hour N as available at hour N, and if the
returned `timestamp` is still the previous hour, schedule a short retry rather
than assuming a fixed offset.

**Therefore:**

- Timeline policy `.after(a few minutes past the next hour)`, matching NEA's
  hourly cadence. That is ~24 refreshes a day, comfortably inside WidgetKit's
  budget for a frequently-viewed widget.
- If the fetch returns the previous hour's `timestamp`, schedule the next
  reload in ~10 minutes instead of waiting a full hour.
- The widget extension and the app share the last good snapshot through an
  **App Group** container, so the widget renders immediately from cache and
  never shows a blank or a spinner. A stale reading with its timestamp shown
  is far better than no reading.
- Failures must degrade to the cached value with its age visible, never to an
  error state — the widget is glanced at, not read.

**Only the keyless sources should run in the widget.** NEA and Open-Meteo are
free and unmetered; PurpleAir and Google bill the user's own key, and a widget
refreshing hourly on every device is not the place to spend that quota. The
widget shows NEA (optionally with Open-Meteo), and the comparison across all
configured sources stays in the app.

## Deep linking

Every widget uses `widgetURL` so a tap opens the app on the region it was
showing, rather than on whatever was last open.

## Testing

- SwiftUI `#Preview(as: .systemSmall)` and friends, backed by the same
  recorded fixtures the parser tests use, so previews show real haze-day
  numbers rather than invented ones.
- Preview each family in light, dark, vibrant and accented rendering modes —
  the colour problem above is only visible if you actually look.
- The simulator tooling can install the widget and screenshot the Home and
  Lock Screens for verification.
