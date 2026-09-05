# Sauna Companion

An Apple Watch app for tracking sauna visits, with an iPhone companion for
statistics and history. Built to be read with wet hands in a hot room: dark,
high contrast, few and large targets.

## What it does

A **session** is one visit and consists of several **rounds** — time in the
sauna — with a rest phase between them.

**On the watch**

- Large phase-coloured timer, current pulse and the round's maximum pulse
- Round counter — a session runs for as many rounds as you like
- Swipe left for the controls page: end the session, or engage Water Lock
- Always-On display keeps phase, elapsed time and pulse visible
- Optional reminder taps at a configurable interval, or switched off entirely
- Action button support on Apple Watch Ultra to switch between sauna and rest
  (see [Action button](#action-button) for the one-time setup it needs)

**On the iPhone**

- Statistics per day, week, month, year or all time: total sauna time,
  sessions, rounds, averages, calories, heart-rate trends, longest session and
  which day and time of day you go most often
- History with a round-by-round breakdown of every session
- Notes per session ("Finnish sauna 90 °C, Aufguss menthol")
- Settings for MET value, body weight override, vibration
- Swipe left on a session to delete it

## Action button

On Apple Watch Ultra, watchOS runs the Action button in two stages:

| Press | Runs | Effect |
|---|---|---|
| 1, with no session running | `StartSaunaWorkoutIntent` | Starts the session and its first round |
| any press during a session | `TogglePhaseIntent`, the *next action* | Ends the current phase, starts the other one |

The next action is an ordinary `AppIntent` the app donates while its workout
session is live. `HealthKitSessionRecorder` donates it the moment the session
starts, so the button is armed whether the session was started with the button
or on screen. Each toggle re-arms itself, and the app plays a haptic on the
switch: the press happens with the app in the background, usually with Water
Lock on, so the tap is the only confirmation.

`PauseWorkoutIntent` and `ResumeWorkoutIntent` are deliberately not adopted.
They belong to the Action + side button chord rather than to a single press —
mapping the phases onto them, as an earlier attempt did, left every press after
the first doing nothing.

**One-time setup.** An app cannot claim the button; it has to be pointed here,
and the assignment is global rather than per-app:

**Settings → Action Button → Action: Workout → App: Sauna Companion**

While it points here, a press no longer starts a workout in Apple's Workout
app. `ActionButtonInfoView` says all of this on first launch, on Ultra models
only.

## Where the data lives

**Apple Health is the only store.** Every finished session is written as an
`HKWorkout` of type *Other*, together with per-round heart rate and the
calculated active energy; the round structure and any note ride along in the
workout's metadata. The app keeps no database of its own, works fully offline,
has no account and collects nothing. Deleting a session in the app deletes the
workout in Health.

A note is stored with the workout, but Health and Fitness do not render
third-party workout metadata — so notes are only visible inside Sauna Companion.

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
- Apple Watch Series 8 or later for wrist temperature; Ultra for the Action button

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
