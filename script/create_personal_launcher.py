#!/usr/bin/env python3
"""Create a Finder-launchable app without modifying or opening the Mixxx bundle."""
from pathlib import Path
import plistlib
import shlex
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
engine = root / 'install/Mixxx Personal.app/Contents/MacOS/Mixxx Personal'
if not engine.is_file():
    raise SystemExit('Build Mixxx Personal first. See PERSONAL_BUILD.md.')
subprocess.run(['python3', str(root / 'script/prepare_personal_profile.py'),
                '--destination', str(root / 'build-personal-profile')], check=True)
app = root / 'Mixxx Personal.app'
contents = app / 'Contents'
(contents / 'MacOS').mkdir(parents=True, exist_ok=True)
(contents / 'Resources').mkdir(exist_ok=True)
launcher = contents / 'MacOS/launcher'
launcher.write_text('#!/bin/bash\nset -euo pipefail\nexec ' + shlex.quote(str(engine))
                    + ' --settings-path ' + shlex.quote(str(root / 'build-personal-profile'))
                    + ' "$@"\n')
launcher.chmod(0o755)
icon = root / 'install/Mixxx Personal.app/Contents/Resources/application.icns'
shutil.copy2(icon, contents / 'Resources/application.icns')
with (contents / 'Info.plist').open('wb') as file:
    plistlib.dump({'CFBundleExecutable': 'launcher',
                  'CFBundleIdentifier': 'local.platterone.mixxx-personal-launcher',
                  'CFBundleName': 'Mixxx Personal',
                  'CFBundleDisplayName': 'Mixxx Personal',
                  'CFBundlePackageType': 'APPL',
                  'CFBundleIconFile': 'application.icns',
                  'CFBundleVersion': '1',
                  'CFBundleShortVersionString': '1.0',
                  'NSHighResolutionCapable': True}, file)
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
print(f'Created {app}; no app was launched')
