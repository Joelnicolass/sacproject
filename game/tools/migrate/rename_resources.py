#!/usr/bin/env python3
"""Rename Godot resource files to human names and rewrite every reference to them (RFC-055 / 055i-a).

Runs without Godot and without the original game: plain Python 3, no dependencies, `git` on the PATH.

  python3 tools/migrate/rename_resources.py --from-display-name data/catalog/wizards --with data/audio/wizards
  python3 tools/migrate/rename_resources.py --csv tools/migrate/some_names.csv --apply

Where the new names come from (one of the two):
  --from-display-name DIR   every DIR/*.tres is renamed to the snake_case of its `display_name` ("The Ragman" -> the_ragman).
  --csv FILE                rows `old,new` with paths relative to res:// (the game/ folder). `#` starts a comment;
                            a first row that reads `old,new` is a header.
Companions:
  --with DIR                (repeatable) the file of DIR with the same name as a renamed one gets the new name too.
                            A missing companion is an error (use --with only for folders that mirror the main one).

What it does with --apply (without it, it only prints the table and the plan):
  1. refuses the rename when two destinations collide, also ignoring case (macOS file names), when a destination
     already exists, or when a new name is not snake_case;
  2. `git mv` of each file together with its `.uid` / `.import` siblings (a uid inside the header travels with the file);
  3. rewrites `res://<old>` (and the bare `<old>` path used by scripts) to the new path in the text files of game/,
     except .godot/, rfcs/, reviews/, changes/, assets/original/ and this tool (history and generated data);
  4. looks for any old path left in those files and exits 1 if one remains.
Exit codes: 0 ok, 1 an old path remains or a step failed, 2 the plan is invalid (nothing was touched).
"""
import argparse
import csv
import os
import re
import subprocess
import sys
import unicodedata

GAME = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEXT_EXT = ('.tres', '.tscn', '.gd', '.json', '.cfg', '.txt', '.sh', '.py', '.gdshader', '.import')
TEXT_NAMES = ('project.godot',)
SKIP_PREFIX = ('.godot/', 'rfcs/', 'reviews/', 'changes/', 'assets/original/',
               'tools/migrate/rename_resources.py')
SIBLINGS = ('.uid', '.import')
NAME_OK = re.compile(r'^[a-z][a-z0-9_]*$')


def git(*args, check=True):
    return subprocess.run(['git', '-C', GAME, *args], capture_output=True, text=True, check=check).stdout


def slug(text):
    """"The Ragman" -> "the_ragman" (ASCII, lower case, runs of other characters become one underscore)."""
    ascii_text = unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode('ascii')
    return re.sub(r'[^a-z0-9]+', '_', ascii_text.lower()).strip('_')


def rel(path):
    return path.replace(os.sep, '/')


def read_display_name(path):
    with open(os.path.join(GAME, path), encoding='utf-8', errors='surrogateescape') as handle:
        for line in handle:
            match = re.match(r'^display_name\s*=\s*"((?:[^"\\]|\\.)*)"', line)
            if match:
                return match.group(1)
    return ''


def rows_from_display_names(folder):
    folder = folder.strip('/')
    directory = os.path.join(GAME, folder)
    if not os.path.isdir(directory):
        sys.exit(f'error: {folder} is not a folder of game/')
    rows = []
    for name in sorted(os.listdir(directory)):
        if not name.endswith('.tres'):
            continue
        old = f'{folder}/{name}'
        display = read_display_name(old)
        if not display:
            sys.exit(f'error: {old} has no display_name; use --csv for it')
        rows.append((old, f'{folder}/{slug(display)}.tres'))
    return rows


def rows_from_csv(path):
    rows = []
    with open(path, encoding='utf-8', newline='') as handle:
        for number, row in enumerate(csv.reader(handle), 1):
            if not row or row[0].strip().startswith('#'):
                continue
            if len(row) < 2:
                sys.exit(f'error: {path}:{number}: expected `old,new`')
            old, new = row[0].strip(), row[1].strip()
            if number == 1 and old == 'old' and new == 'new':
                continue
            rows.append((old.removeprefix('res://'), new.removeprefix('res://')))
    return rows


def add_companions(rows, folders):
    """For each renamed file, the file of the same name in each companion folder is renamed alike."""
    extra = []
    for old, new in rows:
        old_stem, extension = os.path.splitext(os.path.basename(old))
        new_stem = os.path.splitext(os.path.basename(new))[0]
        for folder in folders:
            folder = folder.strip('/')
            found = [name for name in sorted(os.listdir(os.path.join(GAME, folder)))
                     if os.path.splitext(name)[0] == old_stem and not name.endswith(SIBLINGS)]
            if not found:
                sys.exit(f'error: {folder}/ has no companion named {old_stem}.* for {old}')
            for name in found:
                extra.append((f'{folder}/{name}', f'{folder}/{new_stem}{os.path.splitext(name)[1] or extension}'))
    return rows + extra


def validate(rows):
    """Returns a list of problems; empty means the plan is safe to apply."""
    problems = []
    olds = [old for old, _ in rows]
    new_by_lower = {}
    for old, new in rows:
        if old == new:
            problems.append(f'{old}: the new name is the same')
            continue
        if not os.path.isfile(os.path.join(GAME, old)):
            problems.append(f'{old}: the file does not exist')
        stem = os.path.splitext(os.path.basename(new))[0]
        if not NAME_OK.match(stem):
            problems.append(f'{new}: "{stem}" is not snake_case (a-z, 0-9, _; starts with a letter)')
        key = new.lower()
        if key in new_by_lower:
            other = new_by_lower[key]
            case_only = dict(rows)[other] != new
            problems.append(f'{new}: collides with the destination of {other}' + (' (only the case differs)' if case_only else ''))
        new_by_lower[key] = old
        for suffix in ('',) + SIBLINGS:
            target = os.path.join(GAME, new + suffix)
            if os.path.lexists(target) and not (old.lower() == new.lower() and suffix == ''):
                problems.append(f'{new + suffix}: the destination already exists')
    if len(set(olds)) != len(olds):
        problems.append('a source file is listed twice')
    for old in olds:
        if old.lower() in {n.lower() for o, n in rows if o != old}:
            problems.append(f'{old}: is also the destination of another row (chains and swaps are not supported)')
    return problems


def text_files():
    """Tracked or untracked-but-not-ignored text files of game/ that may hold references."""
    listing = git('ls-files', '-co', '--exclude-standard', '-z').split('\0')
    found = []
    for path in listing:
        if not path or path.startswith(SKIP_PREFIX):
            continue
        if path.endswith(TEXT_EXT) or os.path.basename(path) in TEXT_NAMES:
            if os.path.isfile(os.path.join(GAME, path)):
                found.append(path)
    return found


def pattern_for(rows):
    ordered = sorted((old for old, _ in rows), key=len, reverse=True)
    body = '|'.join(re.escape(old) for old in ordered)
    # Not preceded by a path character (so `data/x.tres` does not match inside `other_data/x.tres`), optional res:// or game/ prefix.
    return re.compile(r'(?<![A-Za-z0-9_.\-/])(res://|game/)?(' + body + r')(?![A-Za-z0-9_])')


def rewrite(rows, files):
    mapping = dict(rows)
    regex = pattern_for(rows)
    touched = {}
    for path in files:
        full = os.path.join(GAME, path)
        with open(full, encoding='utf-8', errors='surrogateescape', newline='') as handle:
            text = handle.read()
        count = [0]

        def replace(match):
            count[0] += 1
            return (match.group(1) or '') + mapping[match.group(2)]

        new_text = regex.sub(replace, text)
        if count[0]:
            with open(full, 'w', encoding='utf-8', errors='surrogateescape', newline='') as handle:
                handle.write(new_text)
            touched[path] = count[0]
    return touched


def move(old, new):
    for suffix in ('',) + SIBLINGS:
        source, target = old + suffix, new + suffix
        if not os.path.lexists(os.path.join(GAME, source)):
            continue
        if source.lower() == target.lower():  # case-only rename: two steps so a case-insensitive file system accepts it
            temp = source + '.rename_tmp'
            git('mv', source, temp)
            git('mv', temp, target)
        else:
            os.makedirs(os.path.dirname(os.path.join(GAME, target)), exist_ok=True)
            git('mv', source, target)


def leftovers(rows):
    """Old paths still referenced in the text files (same boundaries as the rewrite, so `other_data/x` is not a hit)."""
    found = []
    regex = pattern_for(rows)
    for path in text_files():
        with open(os.path.join(GAME, path), encoding='utf-8', errors='surrogateescape') as handle:
            text = handle.read()
        for match in regex.finditer(text):
            found.append(f'{path}: {match.group(2)}')
    for old, _ in rows:
        if os.path.lexists(os.path.join(GAME, old)):
            found.append(f'{old}: the file is still there')
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--from-display-name', metavar='DIR', help='rename DIR/*.tres from their display_name')
    source.add_argument('--csv', metavar='FILE', help='rows `old,new` relative to res://')
    parser.add_argument('--with', dest='companions', action='append', default=[], metavar='DIR',
                        help='companion folder whose same-named files are renamed too (repeatable)')
    parser.add_argument('--apply', action='store_true', help='write; without it only the plan is printed')
    args = parser.parse_args()

    rows = rows_from_display_names(args.from_display_name) if args.from_display_name else rows_from_csv(args.csv)
    rows = add_companions(rows, args.companions)
    if not rows:
        sys.exit('error: nothing to rename')

    width = max(len(old) for old, _ in rows)
    print(f'{"old".ljust(width)}  new')
    for old, new in rows:
        print(f'{old.ljust(width)}  {new}')

    problems = validate(rows)
    if problems:
        print('\nPLAN INVALID, nothing was touched:', file=sys.stderr)
        for problem in problems:
            print('  ' + problem, file=sys.stderr)
        return 2

    files = text_files()
    if not args.apply:
        hits = {}
        regex = pattern_for(rows)
        for path in files:
            with open(os.path.join(GAME, path), encoding='utf-8', errors='surrogateescape') as handle:
                count = len(regex.findall(handle.read()))
            if count:
                hits[path] = count
        print(f'\nDry run: {len(rows)} files to move, {sum(hits.values())} references in {len(hits)} files to rewrite.')
        for path, count in sorted(hits.items()):
            print(f'  {count}x {path}')
        print('Run again with --apply to write.')
        return 0

    for old, new in rows:
        move(old, new)
    touched = rewrite(rows, text_files())
    print(f'\nMoved {len(rows)} files; rewrote {sum(touched.values())} references in {len(touched)} files.')
    for path, count in sorted(touched.items()):
        print(f'  {count}x {path}')
    left = leftovers(rows)
    if left:
        print('\nFAIL: an old path remains:', file=sys.stderr)
        for line in left:
            print('  ' + line, file=sys.stderr)
        return 1
    print('OK: no old path remains.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
