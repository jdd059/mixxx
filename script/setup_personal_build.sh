#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -m)" == arm64 ]] || { echo 'This setup targets Apple Silicon macOS' >&2; exit 1; }
python3 -m venv build-tools
build-tools/bin/python -m pip install cmake==3.31.10 ninja==1.13.2
NAME=mixxx-deps-2.5-arm64-osx-min1100-release-40c29ff
if [[ ! -d "buildenv/$NAME" ]]; then
    mkdir -p buildenv
    curl -fL --retry 2 "https://downloads.mixxx.org/dependencies/2.5-rel/macOS/$NAME.zip" -o buildenv/dependencies.zip
    printf '%s  %s\n' b76685e77f681baf8fdc5037297b0f16d323a405d09ce276d8844304530278e1 buildenv/dependencies.zip | shasum -a 256 -c -
    unzip -q buildenv/dependencies.zip -d buildenv
    rm buildenv/dependencies.zip
fi
