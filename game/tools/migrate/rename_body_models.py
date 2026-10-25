#!/usr/bin/env python3
"""Rename the skeletal models of scenes/bodies/models/ from their original code to the human name (055s s6).

  python3 tools/migrate/rename_body_models.py --check     # the plan and the references to rewrite; touches nothing
  python3 tools/migrate/rename_body_models.py --apply     # moves the files and rewrites every reference

`models/eorc.tscn` becomes `models/trogg_model.tscn`, with `eorc_clips.tres` -> `trogg_model_clips.tres` and the folder
`eorc_clips/` -> `trogg_model_clips/`. Only file names and paths change: the model tag (`eorc`, the `model` of the scene and the
`model_id` that travels on the wire) stays. `models/model_files.tres` (ModelFiles) records tag -> file stem, so
`BodyModel.scene_path("eorc")` still finds the scene; the script rewrites it from what is on disk.

The human name is the name of the look scene that wears the model (`scenes/units/bodies/trogg_look.tscn` -> `trogg`), so it is the
name of the CreatureType / WizardType. Left with their code (listed in the output):
  - a model worn by more than one look (there is no single name for it),
  - a model no look wears, and the clip libraries without a scene,
  - `testmonster`, the custom creature: its tag is already its name and new_creature.gd writes it under the tag.

Idempotent: a second run finds every model named and every reference rewritten, and does nothing. Plain Python 3 and `git`; no Godot.
Exit codes: 0 ok, 1 an old path remains, 2 the plan is invalid (nothing was touched).
"""
import argparse
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('rename_resources', os.path.join(HERE, 'rename_resources.py'))
rr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rr)
# History and generated data keep the names they had; so does the changelog of the features.
rr.SKIP_PREFIX = rr.SKIP_PREFIX + ('docs/CHANGELOG', 'tools/migrate/rename_body_models.py')

GAME = rr.GAME
MODELS = 'scenes/bodies/models'
LOOK_DIRS = ('scenes/units/bodies', 'scenes/wizards/bodies')
FILES_TRES = f'{MODELS}/model_files.tres'
KEEP = ('testmonster',)
MODEL_REF = re.compile(r'scenes/bodies/models/([A-Za-z0-9_]+)\.tscn')
TAG_LINE = re.compile(r'^model = "([^"]*)"', re.M)


def read(path):
    with open(os.path.join(GAME, path), encoding='utf-8', errors='surrogateescape', newline='') as handle:
        return handle.read()


def worn_by():
    """{model file stem: [look names]} from the look scenes."""
    found = {}
    for folder in LOOK_DIRS:
        for name in sorted(os.listdir(os.path.join(GAME, folder))):
            if not name.endswith('_look.tscn'):
                continue
            for stem in set(MODEL_REF.findall(read(f'{folder}/{name}'))):
                found.setdefault(stem, []).append(name.removesuffix('_look.tscn'))
    return found


def model_stems():
    return sorted(name[:-5] for name in os.listdir(os.path.join(GAME, MODELS)) if name.endswith('.tscn'))


def plan():
    """Returns (rows, kept) where kept is a list of (stem, reason)."""
    worn = worn_by()
    rows, kept = [], []
    for stem in model_stems():
        looks = worn.get(stem, [])
        if stem in KEEP:
            kept.append((stem, 'custom creature, its tag is its name'))
        elif stem.endswith('_model'):
            continue  # already renamed
        elif len(looks) > 1:
            kept.append((stem, 'worn by ' + ', '.join(looks)))
        elif not looks:
            kept.append((stem, 'no look wears it'))
        else:
            new = looks[0] + '_model'
            rows.append((f'{MODELS}/{stem}.tscn', f'{MODELS}/{new}.tscn'))
            rows.append((f'{MODELS}/{stem}_clips.tres', f'{MODELS}/{new}_clips.tres'))
            if os.path.isdir(os.path.join(GAME, MODELS, f'{stem}_clips')):
                rows.append((f'{MODELS}/{stem}_clips', f'{MODELS}/{new}_clips'))
    scenes = set(model_stems())
    for name in sorted(os.listdir(os.path.join(GAME, MODELS))):
        if name.endswith('_clips.tres') and name[:-len('_clips.tres')] not in scenes:
            kept.append((name[:-len('_clips.tres')], 'clip library without a scene'))
    return rows, kept


def problems_of(rows):
    problems = []
    seen = {}
    for old, new in rows:
        if not os.path.lexists(os.path.join(GAME, old)):
            problems.append(f'{old}: does not exist')
        if os.path.lexists(os.path.join(GAME, new)):
            problems.append(f'{new}: the destination exists')
        if new.lower() in seen:
            problems.append(f'{new}: collides with {seen[new.lower()]}')
        seen[new.lower()] = old
        stem = os.path.basename(new).split('.')[0]
        if not rr.NAME_OK.match(stem):
            problems.append(f'{new}: not snake_case')
    return problems


def model_tag(stem):
    match = TAG_LINE.search(read(f'{MODELS}/{stem}.tscn'))
    return match.group(1) if match else stem


def files_text():
    """model_files.tres from what is on disk: every scene whose stem is not its tag."""
    entries = {}
    for stem in model_stems():
        tag = model_tag(stem)
        if tag != stem:
            entries[tag] = stem
    dictionary = '{\n' + ',\n'.join(f'"{tag}": "{entries[tag]}"' for tag in sorted(entries)) + '\n}' if entries else '{}'
    return ('[gd_resource type="Resource" script_class="ModelFiles" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/bodies/model_files.gd" id="1_files"]\n\n'
            '[resource]\nscript = ExtResource("1_files")\n'
            f'stems = Dictionary[String, String]({dictionary})\n')


def write_files_tres(apply):
    text = files_text()
    current = read(FILES_TRES) if os.path.isfile(os.path.join(GAME, FILES_TRES)) else ''
    if text == current:
        return False
    if apply:
        with open(os.path.join(GAME, FILES_TRES), 'w', encoding='utf-8', newline='') as handle:
            handle.write(text)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true', help='print the plan, write nothing')
    mode.add_argument('--apply', action='store_true', help='move the files and rewrite the references')
    args = parser.parse_args()

    rows, kept = plan()
    if rows:
        width = max(len(old) for old, _ in rows)
        for old, new in rows:
            print(f'{old.ljust(width)}  {new}')
    print(f'\n{len([r for r in rows if r[0].endswith(".tscn")])} models to rename ({len(rows)} entries).')
    for stem, reason in kept:
        print(f'  kept {stem}: {reason}')

    problems = problems_of(rows)
    if problems:
        print('\nPLAN INVALID, nothing was touched:', file=sys.stderr)
        for problem in problems:
            print('  ' + problem, file=sys.stderr)
        return 2

    if rows:
        regex = rr.pattern_for(rows)
        hits = {}
        for path in rr.text_files():
            count = len(regex.findall(read(path)))
            if count:
                hits[path] = count
        print(f'{sum(hits.values())} references in {len(hits)} files to rewrite.')
    else:
        print('Nothing to rename.')

    if args.check:
        if write_files_tres(False):
            print('model_files.tres would change.')
        return 0

    for old, new in rows:
        rr.move(old, new)
    if rows:
        touched = rr.rewrite(rows, rr.text_files())
        print(f'Moved {len(rows)} entries; rewrote {sum(touched.values())} references in {len(touched)} files.')
    changed = write_files_tres(True)
    print('model_files.tres written.' if changed else 'model_files.tres is up to date.')
    left = rr.leftovers(rows) if rows else []
    if left:
        print('\nFAIL: an old path remains:', file=sys.stderr)
        for line in left:
            print('  ' + line, file=sys.stderr)
        return 1
    print('OK: no old path remains.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
