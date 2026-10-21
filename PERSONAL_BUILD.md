# Mixxx Personal: manual MIDI rescan

This personal fork is based on the 2.5.6 release. It adds **Rescan MIDI Devices** under Preferences > Controllers and builds a separate Apple Silicon app named **Mixxx Personal**.

The rescan closes the current process's MIDI streams, refreshes PortMidi, and reopens saved enabled mappings for devices that are present. HID and bulk controller objects are retained. MIDI controls pause briefly during the operation. This does not add automatic hot-plugging or audio-device rescanning.

Apply or cancel pending controller edits before clicking Rescan MIDI Devices. A connected device without a saved mapping still needs its mapping selected and enabled. A previously configured device can be discovered again after removal/reconnection or a bridge restart.

## External effects

This personal build sets AU_EFFECTS=OFF and LILV=OFF. It includes Mixxx's built-in effects, but does not scan or load external Audio Unit or LV2 plugins at startup. The installed plugins and the original Mixxx app are not changed. The repeated scans observed in the original app's log were Audio Units.

## Build and run

Run from the repository root on Apple Silicon macOS, with Xcode/Command Line Tools and Python 3 installed. Setup uses Mixxx's official 1.28 GB dependency archive and verifies its published SHA-256. The package includes Intel build helpers that need Rosetta. The optional experimental QML interface is disabled because its cross-build scanner requires AVX; normal Qt Widgets UI and controller JavaScript remain enabled. The build uses the already-installed, compile/link-verified macOS 15.4 SDK because the old Qt dependency bundle links AGL, which is absent from the macOS 26 SDK. Set MIXXX_MACOS_SDK to override the SDK path; the script verifies that the selected SDK contains both C headers and AGL.

```sh
./script/setup_personal_build.sh
./script/build_and_run.sh --build-only
QT_QPA_PLATFORM=offscreen ./build/mixxx-test --gtest_filter='ControllerManagerRescanTest.*:PortMidiEnumeratorTest.*:MidiControllerTest.*' --resource-path "$PWD/res"
./script/build_and_run.sh --verify
```

The app is staged under `install/Mixxx Personal.app` with a distinct bundle identifier and an ad-hoc development signature. Its separate development entitlements allow audio input and controller JavaScript JIT, without the App Store sandbox, so it can access the copied profile and track paths. The original app and its sandbox entitlements are unchanged. The Codex Run action invokes the same build/run script. The script only stops this checkout's personal executable, never `/Applications/Mixxx.app`.

Double-click `Mixxx Personal.app` in the repository root to open the existing build without Terminal or rebuilding. You can drag this app to the Dock. It uses the same `build-personal-profile` as the command launcher and build/run script. The launcher is generated after each build, has the Mixxx icon and an ad-hoc signature, and points to this checkout’s installed app and personal profile. Keep this checkout in place; regenerate with `python3 script/create_personal_launcher.py` if it moves. Creating the launcher does not open Mixxx. The older `Open Mixxx Personal.command` remains available. On first launch, its profile helper copies saved configuration, user mappings, effects presets, and a consistent SQLite library snapshot from the original profile. Controller mapping paths are redirected to the copy. Audio tracks remain referenced at their original locations. Later launches reuse the personal profile without overwriting it. An explicit `--source` is required if multiple source profiles exist. Changes still open but unsaved in the original app are not imported.

The two apps should be tested one at a time for audio and physical controllers. Keep your installed copy available as the known-good version.

## Verification

The Apple Silicon build and bundle signature verification passed. All 20 targeted MIDI/controller tests passed. A normal Cocoa startup check with a disposable profile and disabled controller mappings reached the main event loop, with no external plugin scan. The safe-mode startup check hit an existing graphics initialization path that dereferences a missing shared GL widget; safe mode is not a validated launch path for this build. No graphics code was changed.

The native regression tests cover repeated rescans and creating/removing/recreating an actual CoreMIDI source after initialization, including reopening its saved enabled mapping. UI page registration cleanup is included to prevent deleted pages remaining in the preferences list between rescans. A physical controller/audio pass and the visible preferences button still require verification in the personal app.

No upstream contribution or merge is made by this branch. This is an explicitly requested personal fork, separate from the upstream libremidi migration.
