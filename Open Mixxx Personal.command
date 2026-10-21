#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="$ROOT/install/Mixxx Personal.app"
[[ -d "$BUNDLE" ]] || { echo 'Build Mixxx Personal first. See PERSONAL_BUILD.md.' >&2; exit 1; }
python3 "$ROOT/script/prepare_personal_profile.py" --destination "$ROOT/build-personal-profile"
open -n "$BUNDLE" --args --settings-path "$ROOT/build-personal-profile"
