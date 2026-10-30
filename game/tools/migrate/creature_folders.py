#!/usr/bin/env python3
"""Historic, already applied (2026-10-28, Q14): do not run again.

Move every creature into one folder: res://creatures/<name>/.

A creature is the CreatureType data/catalog/creatures/<name>.tres. Its folder gets every file that only that creature
uses, found by following the `res://` references of the text resources:

    creatures/<name>/<name>.tres              CreatureType
    creatures/<name>/<name>.tscn              BodyFrame (was scenes/units/bodies/)
    creatures/<name>/<name>_look.tscn         BodyLook
    creatures/<name>/<name>_passives.tscn     the creature's passives
    creatures/<name>/<name>_sounds.tres       SoundSet (was data/audio/creatures/<name>.tres)
    creatures/<name>/<ability>.tres           an ability only this creature has (was data/catalog/abilities/)
    creatures/<name>/model/                   the skeletal model, its clips and its materials (was scenes/bodies/models/)

A file that a second owner also references stays where it is (a model two creatures wear, a shared material, a shared
ability). Every `res://` path in the project's text files (scenes, resources, scripts, docs) is rewritten. Moves go
through `git mv`. Run from game/ with `--apply` to change files; without it, it prints the plan.
"""
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXT_EXT = {'.tscn', '.tres', '.gd', '.godot', '.cfg', '.md', '.py', '.sh', '.json', '.csv', '.txt', '.yml', '.gdshader'}
SKIP_DIRS = {'.godot', 'addons', '.git'}
REF = re.compile(r'res://([^"\s)\]\'>`,]+)')
CREATURES = 'data/catalog/creatures'
DEST = 'creatures'


def text_files():
    out = []
    for path in ROOT.rglob('*'):
        if not path.is_file() or path.suffix not in TEXT_EXT:
            continue
        rel = path.relative_to(ROOT)
        if rel.parts[0] in SKIP_DIRS:
            continue
        out.append(rel.as_posix())
    return out


def resource_refs(files):
    """file -> set of res:// paths it references (only .tscn/.tres: the real dependency graph)."""
    refs = {}
    for f in files:
        if not f.endswith(('.tscn', '.tres')):
            continue
        text = (ROOT / f).read_text(encoding='utf-8', errors='replace')
        refs[f] = {m.group(1) for m in REF.finditer(text)}
    return refs


def referrers(refs):
    back = defaultdict(set)
    for f, targets in refs.items():
        for t in targets:
            back[t].add(f)
    # scripts and docs that name a path also count as users (a preload, a tool constant)
    return back


def code_users(files):
    back = defaultdict(set)
    for f in files:
        # only game scripts make a file shared; tools, tests and disposable probes just get their paths rewritten
        if f.endswith(('.tscn', '.tres', '.md')) or not f.startswith('scenes/'):
            continue
        text = (ROOT / f).read_text(encoding='utf-8', errors='replace')
        for m in REF.finditer(text):
            back[m.group(1)].add(f)
    return back


def plan():
    files = text_files()
    refs = resource_refs(files)
    back = referrers(refs)
    code = code_users(files)
    moves = {}
    for type_file in sorted((ROOT / CREATURES).glob('*.tres')):
        name = type_file.stem
        dest = f'{DEST}/{name}'
        type_rel = f'{CREATURES}/{name}.tres'
        owned = {type_rel: f'{dest}/{name}.tres'}
        # grow the set: a file referenced only by owned files (and by no script) is owned
        frontier = [type_rel]
        while frontier:
            cur = frontier.pop()
            for target in sorted(refs.get(cur, ())):
                if target in owned or not (ROOT / target).exists():
                    continue
                if not movable(target, name):
                    continue
                users = back[target] - {cur}
                if any(u not in owned for u in users) or code.get(target):
                    continue
                owned[target] = destination(target, name, dest)
                frontier.append(target)
                if target.endswith('_clips.tres'):
                    clip_dir = target[: -len('.tres')]
                    for clip in sorted((ROOT / clip_dir).glob('*')):
                        rel = clip.relative_to(ROOT).as_posix()
                        owned[rel] = f'{dest}/model/{Path(clip_dir).name}/{clip.name}'
        # a look whose body is owned goes with it (BodyLook finds it next to the body)
        for src in list(owned):
            if src.startswith('scenes/units/bodies/') and src.endswith('.tscn') and not src.endswith(('_look.tscn', '_passives.tscn')):
                look = src[: -len('.tscn')] + '_look.tscn'
                if (ROOT / look).exists() and look not in owned:
                    print(f'WARN {name}: look {look} not owned, its users: {sorted(back[look])}')
        for src, dst in owned.items():
            if src in moves and moves[src] != dst:
                print(f'WARN {src} claimed twice')
            moves[src] = dst
    return moves, files


def movable(path, name):
    return path.startswith((
        'scenes/units/bodies/', 'scenes/bodies/models/', 'scenes/bodies/materials/',
        'data/audio/creatures/', 'data/catalog/abilities/',
    ))


def destination(path, name, dest):
    base = Path(path).name
    if path.startswith('scenes/units/bodies/'):
        return f'{dest}/{base}'
    if path.startswith('scenes/bodies/models/'):
        return f'{dest}/model/{base}'
    if path.startswith('scenes/bodies/materials/'):
        return f'{dest}/model/materials/{base}'
    if path.startswith('data/audio/creatures/'):
        return f'{dest}/{Path(path).stem}_sounds.tres'
    if path.startswith('data/catalog/abilities/'):
        return f'{dest}/{base}'
    raise ValueError(path)


def main():
    apply = '--apply' in sys.argv
    moves, files = plan()
    counts = defaultdict(int)
    for src in moves:
        counts[src.split('/')[0] + '/' + src.split('/')[1] + ('/' + src.split('/')[2] if src.count('/') > 2 else '')] += 1
    for k in sorted(counts):
        print(f'{counts[k]:5d}  {k}')
    print(f'{len(moves)} files move into {len({d.split("/")[1] for d in moves.values()})} creature folders')
    if not apply:
        for src in sorted(moves):
            if 'firefist' in src or 'ftrl' in src:
                print(f'  {src} -> {moves[src]}')
        return
    # rewrite references first (paths are unique strings), then move
    pattern = re.compile('res://(' + '|'.join(re.escape(s) for s in sorted(moves, key=len, reverse=True)) + r')(?=["\s)\]\'>`,]|$)')
    for f in files:
        path = ROOT / f
        text = path.read_text(encoding='utf-8', errors='replace')
        new = pattern.sub(lambda m: 'res://' + moves[m.group(1)], text)
        if new != text:
            path.write_text(new, encoding='utf-8')
    for src, dst in sorted(moves.items()):
        (ROOT / dst).parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'mv', src, dst], cwd=ROOT, check=True)
        for side in ('.uid', '.import'):
            if (ROOT / (src + side)).exists():
                subprocess.run(['git', 'mv', src + side, dst + side], cwd=ROOT, check=True)
    print('moved.')


if __name__ == '__main__':
    main()
