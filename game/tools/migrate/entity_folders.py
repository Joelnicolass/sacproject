#!/usr/bin/env python3
"""Historic, already applied (2026-10-28, Q14 second part): do not run again.

Finishes the move to one folder per entity and empties data/:

1. Entities. Every file that only one entity uses goes into the entity's folder:
       creatures/<name>/   (already there; picks up what it still had outside, e.g. its shots)
       spells/<name>/      SpellType data/catalog/spells/<name>.tres, its action, projectile, zones...
       wizards/<name>/     WizardType data/catalog/wizards/<name>.tres, body, look, model/, sounds
       gods/<name>/        GodType data/gods/<name>.tres, its look, and buildings/<god>_*.tres
   Inside a folder: effects (ParticleType/BeamType from data/fx) in fx/, the skeletal model, its clips and
   materials in model/, the entity's SoundSet as <name>_sounds.tres, everything else flat.
   A file a second owner also uses stays (it is shared). A script moves only when no other script names
   its class.
2. Systems. What is left in data/ goes next to the code of its system (DIR_MOVES).

Every `res://` path in the project's text files is rewritten; moves go through `git mv`. Prints the plan
without `--apply`.
"""
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXT_EXT = {'.tscn', '.tres', '.gd', '.godot', '.cfg', '.md', '.py', '.sh', '.json', '.csv', '.yml', '.gdshader'}
SKIP = {'.godot', '.git', 'addons'}
REF = re.compile(r'res://([^"\s)\]\'>`,]+)')
CLASS = re.compile(r'^class_name\s+(\w+)', re.M)
GODS = ['charnel', 'james', 'persephone', 'pyro', 'stratos']

DIR_MOVES = [
    ('data/afflictions/', 'scenes/units/afflictions/'),
    ('data/ai/', 'scenes/ai/'),
    ('data/audio/', 'scenes/audio/'),
    ('data/buildings/', 'scenes/structures/buildings/'),
    ('data/catalog/abilities/', 'scenes/units/abilities/'),
    ('data/death_clouds/', 'scenes/units/death_clouds/'),
    ('data/fx/', 'scenes/fx/effects/'),
    ('data/i18n/', 'scenes/ui/i18n/'),
    ('data/look/', 'scenes/look/'),
    ('data/match_rules.tres', 'scenes/match/match_rules.tres'),
    ('data/modes/', 'scenes/match/modes/'),
    ('data/nav/', 'scenes/map/'),
    ('data/net/', 'scenes/net/'),
    ('data/orders/', 'scenes/orders/'),
    ('data/sacrifice/', 'scenes/sacrifice/'),
    ('data/shots/', 'scenes/units/attacks/shots/'),
    ('data/targeting/', 'scenes/units/targeting/'),
    ('data/templates/', 'tools/bake/templates/'),
    ('data/ui/', 'scenes/ui/'),
    ('data/vegetation/', 'scenes/look/vegetation/'),
]
ENTITY_ROOTS = ('creatures/', 'spells/', 'wizards/', 'gods/')


def tracked():
    out = subprocess.run(['git', 'ls-files'], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [p for p in out.splitlines() if (ROOT / p).exists()]


def read(p):
    return (ROOT / p).read_text(encoding='utf-8', errors='replace')


def build_graph(files):
    refs, back, code = {}, defaultdict(set), defaultdict(set)
    for f in files:
        if Path(f).suffix not in TEXT_EXT or f.split('/')[0] in SKIP:
            continue
        found = {m.group(1) for m in REF.finditer(read(f))}
        if f.endswith(('.tscn', '.tres')):
            refs[f] = found
            for t in found:
                back[t].add(f)
        elif f.endswith('.gd') and f.startswith('scenes/'):
            for t in found:
                code[t].add(f)
    return refs, back, code


def class_users(files):
    """class_name -> scripts that mention it (other than its own file)."""
    scripts = {f: read(f) for f in files if f.endswith('.gd') and f.split('/')[0] not in SKIP}
    names = {}
    for f, text in scripts.items():
        m = CLASS.search(text)
        if m:
            names[f] = m.group(1)
    users = defaultdict(set)
    words = {f: set(re.findall(r'\b[A-Z]\w+\b', t)) for f, t in scripts.items()}
    for f, name in names.items():
        for g, w in words.items():
            if g != f and name in w:
                users[f].add(g)
    return users


def movable(path):
    if path.startswith(ENTITY_ROOTS) or path.endswith(('.uid', '.import', '.md')):
        return False
    return path.startswith('data/') or path.startswith('scenes/')


def destination(path, name, dest):
    p = Path(path)
    if path.startswith('scenes/bodies/models/'):
        return f'{dest}/model/{path[len("scenes/bodies/models/"):]}'
    if path.startswith('scenes/bodies/materials/'):
        return f'{dest}/model/materials/{p.name}'
    if path.startswith('scenes/bodies/meshes/'):
        return f'{dest}/model/{p.name}'
    if path.startswith('data/fx/'):
        sub = path[len('data/fx/'):]
        return f'{dest}/fx/{sub[len("spells/"):] if sub.startswith("spells/") else sub}'
    if path.startswith(('data/audio/wizards/', 'data/audio/creatures/')) and p.stem == name:
        return f'{dest}/{name}_sounds.tres'
    if path.startswith('data/audio/') and p.stem == name:
        return f'{dest}/{name}_{p.parent.name}{p.suffix}'
    if path.startswith('data/audio/'):
        return f'{dest}/sounds/{p.name}'
    if path.startswith('data/look/grass/palettes/') and p.stem == name:
        return f'{dest}/{name}_grass_palette{p.suffix}'
    if path.startswith('data/look/') and p.stem == name:
        return f'{dest}/{name}_look{p.suffix}'
    if path.startswith(('data/buildings/', 'scenes/structures/buildings/')) or (
        dest.startswith('gods/') and path.startswith('scenes/props/meshes/')
    ):
        return f'{dest}/buildings/{p.name}'
    return f'{dest}/{p.name}'


def plan():
    files = tracked()
    refs, back, code = build_graph(files)
    cls_users = class_users(files)
    moves = {}

    def claim(roots, name, dest):
        owned = set(roots)
        frontier = list(roots)
        while frontier:
            cur = frontier.pop()
            for target in sorted(refs.get(cur, ())):
                if target in owned or target in moves or not (ROOT / target).exists() or not movable(target):
                    continue
                users = (back[target] | code.get(target, set())) - {cur}
                if any(u not in owned for u in users):
                    continue
                if target.endswith('.gd') and any(u not in owned for u in cls_users.get(target, ())):
                    continue
                owned.add(target)
                moves[target] = destination(target, name, dest)
                frontier.append(target)
        return owned

    for type_file in sorted((ROOT / 'creatures').glob('*/*.tres')):
        if type_file.stem == type_file.parent.name:
            claim([type_file.relative_to(ROOT).as_posix()], type_file.stem, f'creatures/{type_file.stem}')
    for kind, src in (('spells', 'data/catalog/spells'), ('wizards', 'data/catalog/wizards')):
        for type_file in sorted((ROOT / src).glob('*.tres')):
            rel = type_file.relative_to(ROOT).as_posix()
            name = type_file.stem
            moves[rel] = f'{kind}/{name}/{name}.tres'
            claim([rel], name, f'{kind}/{name}')
    for god in GODS:
        rel = f'data/gods/{god}.tres'
        moves[rel] = f'gods/{god}/{god}.tres'
        roots = [rel]
        for b in sorted((ROOT / 'data/buildings').glob(f'{god}_*.tres')):
            b_rel = b.relative_to(ROOT).as_posix()
            moves[b_rel] = f'gods/{god}/buildings/{b.name}'
            roots.append(b_rel)
        claim(roots, god, f'gods/{god}')

    # 2. systems: whatever is still in data/
    for f in files:
        if f in moves or not f.startswith('data/') or f.endswith(('.uid', '.import', '.md')):
            continue
        for src, dst in DIR_MOVES:
            if f == src or (src.endswith('/') and f.startswith(src)):
                moves[f] = dst + f[len(src):] if src.endswith('/') else dst
                break
    return moves, files


def check(moves):
    problems = []
    dests = defaultdict(list)
    for s, d in moves.items():
        dests[d].append(s)
    for d, srcs in dests.items():
        if len(srcs) > 1:
            problems.append(f'{d} <- {srcs}')
        elif (ROOT / d).exists() and d not in moves:
            problems.append(f'{d} exists ({srcs[0]})')
    return problems


def main():
    moves, files = plan()
    groups = defaultdict(int)
    for s, d in moves.items():
        groups[(d.split('/')[0], '/'.join(s.split('/')[:2]))] += 1
    for k in sorted(groups):
        print(f'{groups[k]:5d}  {k[1]:28s} -> {k[0]}/')
    left = [f for f in files if f.startswith('data/') and f not in moves and not f.endswith(('.uid', '.import'))]
    print(f'{len(moves)} files move; left in data/: {left}')
    problems = check(moves)
    for p in problems:
        print('PROBLEM', p)
    if '--apply' not in sys.argv:
        for s in sorted(moves):
            if 'fireball' in s or 'abraxus' in s or s.startswith('data/gods/pyro') or 'pyro_altar' in s:
                print(f'  {s} -> {moves[s]}')
        return
    if problems:
        sys.exit('not applied: fix the problems first')
    pattern = re.compile('res://(' + '|'.join(re.escape(s) for s in sorted(moves, key=len, reverse=True)) + r')(?=["\s)\]\'>`,]|$)')
    for f in files:
        if Path(f).suffix not in TEXT_EXT or f.split('/')[0] in SKIP:
            continue
        text = read(f)
        new = pattern.sub(lambda m: 'res://' + moves[m.group(1)], text)
        if new != text:
            (ROOT / f).write_text(new, encoding='utf-8')
    for src, dst in sorted(moves.items()):
        (ROOT / dst).parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'mv', src, dst], cwd=ROOT, check=True)
        for side in ('.uid', '.import'):
            if (ROOT / (src + side)).exists():
                if subprocess.run(['git', 'ls-files', '--error-unmatch', src + side], cwd=ROOT, capture_output=True).returncode == 0:
                    subprocess.run(['git', 'mv', src + side, dst + side], cwd=ROOT, check=True)
                else:
                    (ROOT / (src + side)).rename(ROOT / (dst + side))
    print('moved.')


if __name__ == '__main__':
    main()
