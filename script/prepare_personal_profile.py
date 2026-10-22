#!/usr/bin/env python3
"""Copy a saved Mixxx profile once, without modifying the source profile."""
import argparse
from pathlib import Path
import shutil
import sqlite3


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    destination = args.destination.resolve()
    if (destination / 'mixxx.cfg').exists():
        print(f'Using existing personal profile: {destination}')
        return
    candidates = [
        Path.home() / 'Library/Containers/org.mixxx.mixxx/Data/Library/Application Support/Mixxx',
        Path.home() / 'Library/Application Support/Mixxx',
    ]
    if args.source:
        requested_source = args.source.expanduser().absolute()
        source = requested_source.resolve()
    else:
        existing = [path for path in candidates if (path / 'mixxx.cfg').is_file()]
        if len(existing) != 1:
            raise SystemExit('Choose one saved Mixxx profile with --source before launching.')
        source = existing[0]
        requested_source = source
    if source == destination or source in destination.parents:
        raise SystemExit('Personal profile must be separate from the original profile.')
    destination.mkdir(parents=True, exist_ok=True)
    for directory in ('controllers', 'effects'):
        if (source / directory).is_dir():
            shutil.copytree(source / directory, destination / directory, dirs_exist_ok=True)
    for filename in ('effects.xml', 'samplers.xml', 'soundconfig.xml'):
        if (source / filename).is_file():
            shutil.copy2(source / filename, destination / filename)
    database = source / 'mixxxdb.sqlite'
    if database.exists():
        with sqlite3.connect(database.as_uri() + '?mode=ro', uri=True) as original:
            with sqlite3.connect(destination / database.name) as copied:
                original.backup(copied)
                assert copied.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    # Keep controller mapping edits in the copy, even when the original config
    # stores absolute paths to its user mapping folder.
    config = (source / 'mixxx.cfg').read_text()
    for original in (requested_source, source):
        config = config.replace(str(original / 'controllers'), str(destination / 'controllers'))
    (destination / 'mixxx.cfg').write_text(config)
    print(f'Prepared personal profile: {destination}')
    print('The original profile was read only; track audio files are shared by reference.')


if __name__ == '__main__':
    main()
