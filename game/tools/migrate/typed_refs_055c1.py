#!/usr/bin/env python3
"""One-shot migration (RFC-055 / 055c1-b = 055i-b): creature abilities and passives from text tags to typed references.

Runs without Godot and without the original game: plain Python 3, no dependencies.

  python3 tools/migrate/typed_refs_055c1.py --dry-run   # says what it would change, writes nothing
  python3 tools/migrate/typed_refs_055c1.py             # writes the data, the scenes and the bench callers

What it does (every step is idempotent: a file that is already typed is left alone):
  1. Takes a snapshot of how the 72 creatures and 15 wizards read before (tools/migrate/055c1_typed_refs_parity.json), only if there
     is none yet. tools/migrate/typed_refs_055c1.gd compares the typed files against it.
  2. data/catalog/creatures/*.tres: `ranged_attack`, `active_ability`, `on_damage` (ExtResource of data/catalog/abilities/), `passives`
     (the death clouds and on-hit passives the creature listed in `passive_abilities`, in the same order), `melee_width_scale`
     (the Druid) and `peasant` (the five villagers). Removes `god`, `ability_tags`, `is_ranged`, `ranged_attack_tag`,
     `active_ability_tag`, `passive_on_damage` and `passive_abilities`.
  3. data/catalog/wizards/*.tres: removes `spell_tag`.
  4. data/death_clouds, data/passives, data/targeting/slba.tres: `tag` becomes the typed `ability` / `spell` / `attack`.
  5. The scenes of the components (unit.tscn, fire_shield, lightning_charge, protector, call_lightning, devour, breath_of_life,
     halo_of_earth, frost_wave), doctor.tscn and wizard_body.tscn.
  6. Every debug/ and agent/ .tscn that gave a creature or a wizard by tag, and the .gd that wrote `creature_tag` / `wizard_tag`
     (they now set `type` / `wizard_type`).
Delete it in 055z with the other one-shot tools.
"""
import argparse
import json
import os
import re
import sys

GAME = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SNAPSHOT = os.path.join(GAME, 'tools', 'migrate', '055c1_typed_refs_parity.json')
CREATURE_DIR = 'data/catalog/creatures'
ABILITY_DIR = 'data/catalog/abilities'
SPELL_DIR = 'data/catalog/spells'
WIZARD_DIR = 'data/catalog/wizards'
PASSIVE_DIRS = ['data/death_clouds', 'data/passives']
PEASANT_TAGS = ['zepa', 'zepd', 'zepe', 'zepf', 'saep']
WIDE_TAGS = {'nmuh': 1.3}
PASSIVE_SCRIPT = 'res://scenes/units/passives/creature_passive.gd'
# The original data itself points at a passive that is in no table (the Ghost's and Zyzyx's `tsg@`): it stays empty, as it was a null.
KNOWN_DANGLING = ['tsg@']
DRY = False
CHANGED = []


def read(path):
    with open(os.path.join(GAME, path), encoding='utf-8') as handle:
        return handle.read()


def write(path, text):
    if read(path) == text:
        return
    CHANGED.append(path)
    if not DRY:
        with open(os.path.join(GAME, path), 'w', encoding='utf-8') as handle:
            handle.write(text)


def tres_files(folder):
    base = os.path.join(GAME, folder)
    return sorted(os.path.join(folder, name) for name in os.listdir(base) if name.endswith('.tres'))


def field(text, name):
    match = re.search(r'^%s = (.*)$' % re.escape(name), text, re.M)
    return match.group(1).strip() if match else None


def string_field(text, name):
    value = field(text, name)
    if value is None:
        return None
    match = re.match(r'^&?"(.*)"$', value)
    return match.group(1) if match else None


def tag_list(value):
    return re.findall(r'"([^"]*)"', value or '')


def index_by_tag(folder):
    """tag -> 'res://folder/file.tres' of every .tres in `folder` that has a `tag = "x"` line (file names may collide in case)."""
    found = {}
    for path in tres_files(folder):
        tag = string_field(read(path), 'tag')
        if tag:
            if tag in found:
                sys.exit('two files for the tag %s in %s' % (tag, folder))
            found[tag] = 'res://' + path.replace(os.sep, '/')
    return found


def ext_ref_path(text, ref_id):
    match = re.search(r'^\[ext_resource [^\]]*path="([^"]+)"[^\]]*id="%s"\]' % re.escape(ref_id), text, re.M)
    return match.group(1) if match else None


def add_ext(text, kind, path, ref_id):
    """Adds `[ext_resource ...]` after the last ext_resource (or the header) unless the path is already there; returns (text, id)."""
    existing = re.search(r'^\[ext_resource [^\]]*path="%s"[^\]]*id="([^"]+)"\]' % re.escape(path), text, re.M)
    if existing:
        return text, existing.group(1)
    line = '[ext_resource type="%s" path="%s" id="%s"]\n' % (kind, path, ref_id)
    lines = list(re.finditer(r'^\[ext_resource [^\n]*\]\n', text, re.M))
    at = lines[-1].end() if lines else text.index('\n') + 2
    text = text[:at] + line + text[at:]
    text = re.sub(r'(load_steps=)(\d+)', lambda m: m.group(1) + str(int(m.group(2)) + 1), text, count=1)
    return text, ref_id


# ---------------------------------------------------------------- snapshot

def take_snapshot(abilities, spells):
    if os.path.exists(SNAPSHOT):
        return json.load(open(SNAPSHOT, encoding='utf-8'))
    snap = {'creatures': {}, 'wizards': {}, 'passives': {}, 'abilities': sorted(abilities), 'spells': sorted(spells)}
    for path in tres_files(CREATURE_DIR):
        text = read(path)
        if field(text, 'ranged_attack_tag') is None and field(text, 'ability_tags') is None:
            sys.exit('%s is already typed and there is no snapshot: restore the old files first' % path)
        tag = string_field(text, 'tag')
        snap['creatures'][tag] = {
            'file': os.path.basename(path),
            'god': string_field(text, 'god') or '',
            'ability_tags': tag_list(field(text, 'ability_tags')),
            'is_ranged': field(text, 'is_ranged') == 'true',
            'ranged_attack_tag': string_field(text, 'ranged_attack_tag') or '',
            'active_ability_tag': string_field(text, 'active_ability_tag') or '',
            'passive_on_damage': string_field(text, 'passive_on_damage') or '',
            'passive_abilities': tag_list(field(text, 'passive_abilities')),
        }
    for path in tres_files(WIZARD_DIR):
        text = read(path)
        snap['wizards'][string_field(text, 'tag')] = {'file': os.path.basename(path), 'spell_tag': string_field(text, 'spell_tag') or ''}
    for folder in PASSIVE_DIRS + ['data/targeting']:
        for path in tres_files(folder):
            tag = string_field(read(path), 'tag')
            if tag:
                snap['passives']['res://' + path.replace(os.sep, '/')] = tag
    if not DRY:
        with open(SNAPSHOT, 'w', encoding='utf-8') as handle:
            json.dump(snap, handle, indent=1, sort_keys=True)
            handle.write('\n')
    CHANGED.append('tools/migrate/055c1_typed_refs_parity.json')
    return snap


# ---------------------------------------------------------------- data

def passive_paths(snap, abilities, spells):
    """passive tag -> res:// path of the .tres that holds it (death clouds by ability, on-hit by spell)."""
    out = {}
    for path, tag in snap['passives'].items():
        text = read(path[len('res://'):])
        script = re.search(r'script_class="([^"]+)"', text).group(1)
        if script in ('DeathCloudType', 'OnHitPassiveType'):
            out[tag] = path
    return out


def migrate_passives(snap, abilities, spells):
    for path, tag in sorted(snap['passives'].items()):
        rel = path[len('res://'):]
        text = read(rel)
        klass = re.search(r'script_class="([^"]+)"', text).group(1)
        if klass == 'OnHitPassiveType':
            name, source, kind = 'spell', spells, 'spells'
        elif klass in ('DeathCloudType', 'DamagePassiveType'):
            name, source, kind = 'ability', abilities, 'abilities'
        elif klass == 'WoundedAllyPolicy':
            name, source, kind = 'attack', abilities, 'abilities'
        else:
            continue
        if not re.search(r'^tag = ', text, re.M):
            continue
        if tag not in source:
            sys.exit('%s: no %s for the tag %s' % (rel, kind, tag))
        text, ref = add_ext(text, 'Resource', source[tag], 'typed_%s' % tag.replace('@', '_').replace('!', '_'))
        text = re.sub(r'^tag = .*\n', '%s = ExtResource("%s")\n' % (name, ref), text, count=1, flags=re.M)
        write(rel, text)


def migrate_creatures(snap, abilities, spells):
    clouds = passive_paths(snap, abilities, spells)
    problems = []
    for path in tres_files(CREATURE_DIR):
        text = read(path)
        if field(text, 'ranged_attack_tag') is None and field(text, 'ability_tags') is None:
            continue
        tag = string_field(text, 'tag')
        old = snap['creatures'][tag]
        ranged = old['ranged_attack_tag']
        active = old['active_ability_tag']
        damage = old['passive_on_damage']
        # The old redundant fields must say what the three slots say (the plan checked it by hand; the tool checks it again).
        slots = [t for t in (ranged, active, damage) if t]
        if slots != old['ability_tags']:
            problems.append('%s: ability_tags %s are not [ranged, active, on_damage] %s' % (tag, old['ability_tags'], slots))
        if old['is_ranged'] != bool(ranged):
            problems.append('%s: is_ranged %s but ranged_attack_tag %r' % (tag, old['is_ranged'], ranged))
        lines = []
        for name, value in (('ranged_attack', ranged), ('active_ability', active), ('on_damage', damage)):
            if not value:
                continue
            if value not in abilities:
                if value in KNOWN_DANGLING:
                    print('NOTE %s: %s %s is in no table of the original (left empty)' % (tag, name, value))
                else:
                    problems.append('%s: %s %s has no AbilityType (left empty)' % (tag, name, value))
                continue
            text, ref = add_ext(text, 'Resource', abilities[value], 'typed_%s' % value.replace('@', '_').replace('!', '_'))
            lines.append('%s = ExtResource("%s")' % (name, ref))
        passives = []
        for value in old['passive_abilities']:
            if value not in clouds:
                problems.append('%s: passive %s has no resource' % (tag, value))
                continue
            passives.append(clouds[value])
        if passives:
            text, script_ref = add_ext(text, 'Script', PASSIVE_SCRIPT, 'typed_passive_script')
            refs = []
            for index, passive_path in enumerate(passives):
                text, ref = add_ext(text, 'Resource', passive_path, 'typed_passive_%d' % index)
                refs.append('ExtResource("%s")' % ref)
            lines.append('passives = Array[ExtResource("%s")]([%s])' % (script_ref, ', '.join(refs)))
        if tag in WIDE_TAGS:
            lines.append('melee_width_scale = %s' % WIDE_TAGS[tag])
        if tag in PEASANT_TAGS:
            lines.append('peasant = true')
        for name in ('god', 'is_ranged', 'ranged_attack_tag', 'active_ability_tag', 'passive_on_damage', 'passive_abilities'):
            text = re.sub(r'^%s = .*\n' % name, '', text, flags=re.M)
        block = '\n'.join(lines) + '\n' if lines else ''
        text = re.sub(r'^ability_tags = .*\n', lambda _m: block, text, count=1, flags=re.M)
        write(path, text)
    for line in problems:
        print('PROBLEM ' + line)
    return problems


def migrate_wizards():
    for path in tres_files(WIZARD_DIR):
        text = read(path)
        write(path, re.sub(r'^spell_tag = .*\n', '', text, flags=re.M))


def report_gods(snap):
    """Info only: a creature in a god's book whose own `god` is another one would cast with another particle after the change."""
    odd = []
    for god in tres_files('data/gods'):
        text = read(god)
        god_tag = string_field(text, 'tag') or os.path.basename(god)[:-4]
        for ref in re.findall(r'path="res://data/catalog/creatures/([^"]+)\.tres"', text):
            creature = read('%s/%s.tres' % (CREATURE_DIR, ref))
            tag = string_field(creature, 'tag')
            own = snap['creatures'][tag]['god']
            if own not in (god_tag, 'none', ''):
                odd.append('%s in the book of %s has god %s' % (tag, god_tag, own))
    print('GOD BOOK CHECK ' + ('every creature of a book is of that god or of none' if not odd else '; '.join(odd)))


# ---------------------------------------------------------------- scenes

def migrate_components(abilities, spells):
    def ab(tag):
        return abilities[tag]
    # The properties go right after the `script = ...` line of the root node of each scene.
    for path, props in (
        ('scenes/units/passives/fire_shield.tscn', [('passive', 'Resource', ab('rifl')), ('fire', 'Resource', spells['mrff'])]),
        ('scenes/units/passives/lightning_charge.tscn', [('passive', 'Resource', ab('gcil'))]),
        ('scenes/units/abilities/protector.tscn', [('life_shield', 'Resource', ab('hsba'))]),
        ('scenes/units/abilities/call_lightning.tscn', [('spell', 'Resource', spells['ntil'])]),
        ('scenes/units/abilities/devour.tscn', [('healing', 'Resource', spells['wobr'])]),
        ('scenes/units/abilities/breath_of_life.tscn', [('default_ability', 'Resource', ab('filb'))]),
        ('scenes/units/abilities/halo_of_earth.tscn', [('default_ability', 'Resource', ab('HRba'))]),
    ):
        text = read(path)
        for name, kind, res_path in props:
            if re.search(r'^%s = ' % name, text, re.M):
                continue
            text, ref = add_ext(text, kind, res_path, 'typed_' + name)
            script = re.search(r'^script = ExtResource\("[^"]+"\)\n', text, re.M)
            text = text[:script.end()] + '%s = ExtResource("%s")\n' % (name, ref) + text[script.end():]
        write(path, text)
    # FreezeTouch is a child node of frost_wave.tscn
    path = 'scenes/units/attacks/frost_wave.tscn'
    text = read(path)
    if not re.search(r'^freeze = ', text, re.M):
        text, ref = add_ext(text, 'Resource', spells['zerf'], 'typed_zerf')
        script = re.search(r'^script = ExtResource\("2_touch"\)\n', text, re.M)
        text = text[:script.end()] + 'freeze = ExtResource("%s")\n' % ref + text[script.end():]
        write(path, text)
    # unit.tscn
    path = 'scenes/units/unit.tscn'
    text = read(path)
    text = re.sub(r'^types = Array\[ExtResource\("f158_type"\)\]\(.*\)\n', '', text, flags=re.M)
    text = re.sub(r'^types = Array\[ExtResource\("f118_type"\)\]\(.*\)\n', '', text, flags=re.M)
    for dead in ('f158_type', 'f158_zerf', 'f159_eniv', 'f118_type', 'f118_goc', 'f118_cen', 'f118_tum'):
        line = re.search(r'^\[ext_resource [^\n]*id="%s"\]\n' % dead, text, re.M)
        if line and text.count('ExtResource("%s")' % dead) == 0:
            text = text[:line.start()] + text[line.end():]
            text = re.sub(r'(load_steps=)(\d+)', lambda m: m.group(1) + str(int(m.group(2)) - 1), text, count=1)
    if 'source = ExtResource' not in text:
        text, ref = add_ext(text, 'Resource', ab('hmba'), 'typed_hmba')
        needle = 'script = ExtResource("f41_mana_support")\n'
        text = text.replace(needle, needle + 'source = ExtResource("%s")\n' % ref, 1)
    write(path, text)


def migrate_owners(creatures, wizards):
    path = 'scenes/sacrifice/doctor.tscn'
    text = read(path)
    if not re.search(r'^type = ExtResource', text, re.M):
        text, ref = add_ext(text, 'Resource', creatures['dcas'], 'typed_dcas')
        needle = 'script = ExtResource("1_body")\n'
        text = text.replace(needle, needle + 'type = ExtResource("%s")\n' % ref, 1)
        write(path, text)
    path = 'scenes/wizards/wizard_body.tscn'
    text = read(path)
    if re.search(r'^wizard_tag = "cwa0"\n', text, re.M):
        text, ref = add_ext(text, 'Resource', wizards['cwa0'], 'typed_cwa0')
        text = text.replace('wizard_tag = "cwa0"\n', 'wizard_type = ExtResource("%s")\n' % ref, 1)
        write(path, text)


# ---------------------------------------------------------------- benches

def walk(folder, suffix):
    for root, dirs, files in os.walk(os.path.join(GAME, folder)):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for name in sorted(files):
            if name.endswith(suffix):
                yield os.path.relpath(os.path.join(root, name), GAME)


def migrate_bench_scenes(creatures, wizards):
    for folder in ('debug', 'agent'):
        for path in walk(folder, '.tscn'):
            text = read(path)
            if not re.search(r'^(creature_tag|wizard_tag) = "', text, re.M):
                continue
            for prop, new_prop, index, kind in (('creature_tag', 'type', creatures, 'c'), ('wizard_tag', 'wizard_type', wizards, 'w')):
                for tag in sorted(set(re.findall(r'^%s = "([^"]*)"$' % prop, text, re.M))):
                    if tag not in index:
                        print('PROBLEM %s: %s %s has no file' % (path, prop, tag))
                        continue
                    text, ref = add_ext(text, 'Resource', index[tag], 'typed_%s_%s' % (kind, re.sub(r'\W', '_', tag)))
                    text = re.sub(r'^%s = "%s"$' % (prop, re.escape(tag)), '%s = ExtResource("%s")' % (new_prop, ref), text, flags=re.M)
            write(path, text)


ASSIGN_CREATURE = re.compile(r'^(\s*)([\w\.\[\]\(\)"]+?)\.creature_tag = (.+)$')
SET_CREATURE = re.compile(r'\.set\("creature_tag", ([^)]*(?:\([^)]*\))?[^)]*)\)')
ASSIGN_WIZARD = re.compile(r'^(\s*)([\w\.\[\]\(\)"]+?)\.wizard_tag = (.+)$')
SET_WIZARD = re.compile(r'\.set\("wizard_tag", ([^)]*(?:\([^)]*\))?[^)]*)\)')


def migrate_bench_scripts():
    for folder in ('debug', 'agent'):
        for path in walk(folder, '.gd'):
            text = read(path)
            if 'creature_tag' not in text and 'wizard_tag' not in text:
                continue
            out = []
            for line in text.split('\n'):
                if 'GameData.creature(' not in line and 'GameData.wizard(' not in line:
                    match = ASSIGN_CREATURE.match(line)
                    if match and not match.group(3).startswith('='):
                        line = '%s%s.type = GameData.creature(%s)' % (match.group(1), match.group(2), match.group(3))
                    else:
                        line = SET_CREATURE.sub(lambda m: '.set("type", GameData.creature(%s))' % m.group(1), line)
                    match = ASSIGN_WIZARD.match(line)
                    if match and not match.group(3).startswith('='):
                        line = '%s%s.wizard_type = GameData.wizard(%s)' % (match.group(1), match.group(2), match.group(3))
                    else:
                        line = SET_WIZARD.sub(lambda m: '.set("wizard_type", GameData.wizard(%s))' % m.group(1), line)
                out.append(line)
            write(path, '\n'.join(out))


def main():
    global DRY
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    DRY = parser.parse_args().dry_run
    abilities = index_by_tag(ABILITY_DIR)
    spells = index_by_tag(SPELL_DIR)
    snap = take_snapshot(abilities, spells)
    creatures = index_by_tag(CREATURE_DIR)
    wizards = index_by_tag(WIZARD_DIR)
    report_gods(snap)
    migrate_passives(snap, abilities, spells)
    problems = migrate_creatures(snap, abilities, spells)
    migrate_wizards()
    migrate_components(abilities, spells)
    migrate_owners(creatures, wizards)
    migrate_bench_scenes(creatures, wizards)
    migrate_bench_scripts()
    print('%s %d files%s' % ('WOULD CHANGE' if DRY else 'CHANGED', len(CHANGED), ''))
    for path in CHANGED:
        print('  ' + path)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
