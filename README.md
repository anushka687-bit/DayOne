# DayOne

Privacy-first, on-device personalization — useful from a user's very first
session, and still learning on session 100, with nothing stored off the
device and nothing sent outside it beyond one opaque trigger id.

## First-time setup

This project was hand-written (not generated with `flutter create`), so the
platform folders (`android/`, `ios/`, `web/`, etc.) don't exist yet. Add them
once, in this folder:

```
flutter create --project-name dayone .
flutter pub get
```

`flutter create .` is safe to run here — it only adds the missing platform
folders; it will not touch `lib/` or the dependencies already listed in
`pubspec.yaml`.

## Run it

```
flutter run -d chrome
```

This opens the app at a `localhost` address in Chrome with hot reload. For
most of development you can stay here — everything except the real ESP32
Bluetooth connection works the same in the browser as on a phone, because the
"sensors" are simulated sliders (see below).

To run on an actual Android device/emulator instead (needed once you wire up
the real ESP32 over Bluetooth):

```
flutter devices
flutter run -d <device-id>
```

## What's actually in here

```
lib/
  main.dart                        — app entry; shows Welcome or Dashboard
  app_state.dart                   — the one shared state object (Provider)
  models/
    preference_profile.dart        — the onboarding answers (0.0–1.0 each)
    context_snapshot.dart          — the live sensor reading (0.0–1.0 each)
    mode.dart                      — Mode as data (4 built-ins + custom),
                                      SceneTriggerRef (the opaque scene link)
    pending_transition.dart        — a proposed change waiting out its
                                      5-minute cancel window
  engine/
    personalization_engine.dart    — THE AI: scores modes, and learns —
                                      one online-learning step per correction
    personalization_model.dart     — the learned weights (per mode) + the
                                      correction count that drives the
                                      decaying learning rate
    routine_learner.dart           — "this mode, around this time, on this
                                      day" habit tally — the thing that lets
                                      DayOne act on a schedule, not just
                                      sensors
    trigger_adapter.dart           — the entire smart-home integration
                                      contract: one opaque scene id in,
                                      nothing else crosses it
    mock_trigger_adapter.dart      — the demo-safe stand-in; logs what it
                                      would have fired instead of calling a
                                      real webhook
  storage/
    profile_store.dart             — preference profile + learned weights +
                                      current mode (local only)
    mode_store.dart                — the mode list (local only)
    routine_store.dart             — the routine tally (local only)
  screens/
    welcome_screen.dart            — Step 1: generic, no profile yet
    onboarding_screen.dart         — Step 2: the 4-question, ~60s onboarding
    home_shell.dart                — bottom-nav shell after onboarding
    dashboard_screen.dart          — Step 4/5: the screen that visibly
                                      adapts, plus the pending-transition
                                      banner and "Switch" override sheet
    why_this_mode_screen.dart      — explainability: engine scores, learned
                                      routines, and the trigger log
    context_screen.dart            — Step 3/6: simulated sensor sliders +
                                      "simulate a moment" for demoing
                                      time-based routines without waiting
    modes_screen.dart              — the dynamic mode list: add a mode, pick
                                      its content shape, optionally wire a
                                      scene trigger
    privacy_screen.dart            — Step 7/8: full profile viewer
                                      (including the learned model and
                                      routines), connected integrations, and
                                      the Delete button
  theme/
    app_theme.dart                 — the deck's palette, carried into the app
```

### The personalization engine, in one sentence

`PersonalizationEngine.decide()` scores every mode with its own learned
weight vector against `[preference, context]`, picks the winner, and
returns every mode's score (softmax-normalized) so "Why this mode?" can
show its work. `learnFromCorrection()` is the other half: a single
online-learning step (perceptron-style) that nudges the target mode's
weights up and the rejected mode's down, with a learning rate that decays
as more corrections arrive — biggest moves right after onboarding, smaller
fine-tuning after. No model file, no network call, no training *run* — the
model is just `Map<modeId, List<double>>`, updated in place.

### Where learning actually happens

Three paths feed the same `learnFromCorrection()`:

- **Explicit override** — the "Switch" sheet on the Dashboard. Strongest
  signal: applies immediately, no waiting.
- **Cancelling a proposed transition** — the 5-minute banner's Cancel
  button is itself a correction (reinforces staying put).
- **Time-based routines** — `RoutineLearner` tallies `(weekday, 30-minute
  bucket) -> mode`. Once the same combination has been seen 3+ times, it
  counts as a routine and can propose a transition on its own, even with
  no sensor change — the "every day at 6pm" case. The Context tab has time
  presets to demo this without waiting for the real clock.

### Nothing applies instantly

Every mode change — from a sensor shift or a learned routine — becomes a
`PendingTransition` with a 5-minute countdown, shown as a banner with
Cancel (and, for demos, "Apply now"). Only an explicit override from the
Switch sheet skips the wait, since the user is already looking right at it.

### Smart-home / other-app integration, as code

`TriggerAdapter` is one method: `fire(sceneId)`. A mode's `sceneTriggers`
list is the only thing in `Mode` that can reach outside the device, and
even then only that opaque id — never a preference value, a sensor
reading, or anything from the learned model. This build ships
`MockTriggerAdapter`, which just logs what it would have fired (see Privacy
→ Connected Integrations, or Why this mode? → Environment Triggers Sent).
A real integration — a Home Assistant automation webhook, an IFTTT/
SmartThings Maker webhook, or a virtual device an Alexa Routine watches —
is one more class implementing the same interface, registered in
`AppState.adapters` alongside the mock. Any other app that wants to be
personalized along with DayOne can do the same from its own side (a local
webhook, an OS-level Intent/App Shortcut/App Intent) without DayOne
knowing anything about what happens on the other end.

### Where the real ESP32 plugs in

Everything upstream of the engine is simulated right now: `context_screen.dart`
has sliders for noise/movement/light that call `AppState.updateContext()`.
When the real ESP32 + BH1750 + MPU6050 + sound sensor are ready, replace
*only* what calls `updateContext()` — e.g. a `flutter_blue_plus` listener
that parses incoming BLE packets into a `ContextSnapshot` and calls the same
method. Nothing in `app_state.dart`, the engine, or any screen needs to
change, because they only ever see the `ContextSnapshot` shape, never where
it came from.

### The privacy guarantee, as code

The entire persistence layer is `lib/storage/` (`ProfileStore`, `ModeStore`,
`RoutineStore`), wrapping `shared_preferences` (device-local storage;
`localStorage` on web). There is no HTTP client anywhere in this codebase
and no backend to point one at — the only thing that ever reaches outside
the device is `TriggerAdapter.fire(sceneId)`, and that's one opaque string.
`AppState.deleteProfile()` is what "Delete My Profile" calls — it wipes the
preference profile, the learned weights, the mode list, the routine tally,
and the trigger log in one call, and is the whole of what DayOne stores.
