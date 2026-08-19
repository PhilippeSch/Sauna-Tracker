# Sauna Tracker

An Apple Watch app for tracking sauna visits, with an iPhone companion for
statistics and history. Built to be read with wet hands in a hot room: dark,
high contrast, few and large targets.

## What it does

A **session** is one visit and consists of several **rounds** — time in the
sauna — with a rest phase between them.

**On the watch**

- Large phase-coloured timer, current pulse and the round's maximum pulse
- Round indicator against the configured maximum
- Swipe left for the controls page: end the session, or engage Water Lock
- Always-On display keeps phase, elapsed time and pulse visible
- Optional reminder taps at a configurable interval, or switched off entirely

**On the iPhone**

- Statistics per day, week, month, year or all time: total sauna time,
  sessions, rounds, averages, calories, heart-rate trends, longest session and
  which day and time of day you go most often
- History with a round-by-round breakdown of every session
- Notes per session ("Finnish sauna 90 °C, Aufguss menthol")
- Settings for MET value, maximum rounds, body weight override, vibration
- Swipe left on a session to delete it

## Where the data lives

**Apple Health is the only store.** Every finished session is written as an
`HKWorkout` of type *Other*, together with per-round heart rate and the
calculated active energy; the round structure and any note ride along in the
workout's metadata. The app keeps no database of its own, works fully offline,
has no account and collects nothing. Deleting a session in the app deletes the
workout in Health.

A note is stored with the workout, but Health and Fitness do not render
third-party workout metadata — so notes are only visible inside Sauna Tracker.

## Calories

Energy is estimated with the MET model, counting only time actually spent in
the sauna:

```
kcal = MET × body weight (kg) × hours in sauna
```

The MET value is configurable between 1.5 and 2.0 and defaults to 1.75. Body
weight comes from Health unless overridden in settings.

## Requirements

- watchOS 26.5, iOS 26.5, Xcode 26
- Apple Watch Series 8 or later for wrist temperature

## Build

Open `Sauna Tracker.xcodeproj` and run the *Sauna Tracker Watch App* scheme.

The build number is a `YYYYMMDDHHMM` timestamp shared by both apps: a build
phase writes `Config/Version.xcconfig`, and every target takes
`CURRENT_PROJECT_VERSION` from `BUILD_TIMESTAMP`, so the iPhone app and the
watch app always carry the same number. It takes effect from the next build.

## Tests

```
xcodebuild test -scheme "Sauna Tracker" -destination 'platform=iOS Simulator,name=iPhone 17'
```

Covers the session state machine, statistics, the calorie model, duration
formatting and the Health metadata round-trip.

## Languages

English, German, Swedish, Finnish.
