#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MODE="${1:---run}"
CMAKE="$ROOT/build-tools/bin/cmake"
DEPS="$ROOT/buildenv/mixxx-deps-2.5-arm64-osx-min1100-release-40c29ff"
if [[ ! -x "$CMAKE" || ! -d "$DEPS" ]]; then
    echo 'Build tools or the official dependency bundle are missing. See PERSONAL_BUILD.md.' >&2
    exit 1
fi
SDK="${MIXXX_MACOS_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk}"
if [[ ! -f "$SDK/usr/include/stdlib.h" || ! -f "$SDK/System/Library/Frameworks/AGL.framework/AGL.tbd" ]]; then
    echo 'Set MIXXX_MACOS_SDK to a complete macOS SDK that includes AGL (verified with 15.4)' >&2
    exit 1
fi
BUNDLE="$ROOT/install/Mixxx Personal.app"
BINARY="$BUNDLE/Contents/MacOS/Mixxx Personal"
if [[ "$MODE" != '--build-only' ]]; then
    # Match only this build's absolute executable path; preserve installed Mixxx.
    while IFS= read -r PID; do
        [[ -z "$PID" ]] || kill -TERM "$PID"
    done < <(pgrep -f "^${BINARY//./\.}( |$)" || true)
fi
# The legacy FindSndFile module needs a version to link libsndfile's mpg123
# dependency. Read it from the pinned bundle when system pkg-config is absent.
SNDFILE_VERSION="$(sed -n 's/^Version: *//p' "$DEPS/installed/arm64-osx-min1100-release/lib/pkgconfig/sndfile.pc")"
[[ -n "$SNDFILE_VERSION" ]] || { echo 'Missing libsndfile version metadata' >&2; exit 1; }
"$CMAKE" -S . -B build -G Ninja \
    -DCMAKE_MAKE_PROGRAM="$ROOT/build-tools/bin/ninja" \
    -DCMAKE_BUILD_TYPE=Release -DMIXXX_VCPKG_ROOT="$DEPS" \
    -DSndFile_VERSION="$SNDFILE_VERSION" \
    -DVCPKG_TARGET_TRIPLET=arm64-osx-min1100-release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DMACOS_BUNDLE=ON \
    -DCMAKE_OSX_SYSROOT="$SDK" \
    -UWrapOpenGL_AGL \
    '-DMACOS_BUNDLE_NAME=Mixxx Personal' \
    -DMACOS_BUNDLE_IDENTIFIER=local.platterone.mixxx-personal \
    -DAPPLE_CODESIGN_ENTITLEMENTS="$ROOT/packaging/macos/MixxxPersonal.entitlements" \
    -DAU_EFFECTS=OFF -DLILV=OFF -DQML=OFF \
    -DBUILD_TESTING=ON -DBUILD_BENCH=OFF -DHSS1394=OFF -DMACAPPSTORE=OFF \
    -DCMAKE_INSTALL_PREFIX="$ROOT/install"
"$CMAKE" --build build --parallel "${MIXXX_BUILD_JOBS:-6}"
"$CMAKE" --install build
codesign --verify --deep --strict "$BUNDLE"
if [[ "$MODE" == '--build-only' ]]; then exit 0; fi
python3 "$ROOT/script/prepare_personal_profile.py" --destination "$ROOT/build-personal-profile"
case "$MODE" in
    --run|run) open -n "$BUNDLE" --args --settings-path "$ROOT/build-personal-profile" ;;
    --debug) lldb -- "$BINARY" --settings-path "$ROOT/build-personal-profile" ;;
    --verify)
        open -n "$BUNDLE" --args --settings-path "$ROOT/build-personal-profile"
        sleep 2
        pgrep -f "^${BINARY//./\.}( |$)"
        ;;
    *) echo 'Usage: script/build_and_run.sh [--build-only|--run|--debug|--verify]' >&2; exit 2 ;;
esac
