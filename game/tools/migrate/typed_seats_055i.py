#!/usr/bin/env python3
"""One-shot migration: AiSeat `wizard` and `god` from text to typed references.

Runs without Godot and without the original game: plain Python 3, no dependencies.

  python3 tools/migrate/typed_seats_055i.py            # rewrites the files
  python3 tools/migrate/typed_seats_055i.py --dry-run  # prints what it would change

Before:  wizard = "cwa0"            god = &"james"
After:   wizard = ExtResource("..") god = ExtResource("..")   (res://data/catalog/wizards/jadugarr.tres, res://data/gods/james.tres)

Rules:
  - the wizard is found by its `tag` field in data/catalog/wizards/*.tres (so the file name does not matter);
  - the god is found by its `tag` field in data/gods/*.tres and keeps its `uid` in the reference;
  - `god = &""` (drawn when the match starts) is deleted: an empty reference means "drawn";
  - a seat that never wrote `wizard` or `god` used the old script defaults ("cwa0", &"james"): they are written out now;
  - the files are data/match_rules.tres and data/ai/seat_vs_ai.tres.
It is idempotent (a seat that already holds an ExtResource is left alone). Delete it with the other one-shot tools.
"""
import argparse
import os
import re
import sys

GAME = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SEAT_SCRIPT = 'res://scenes/ai/data/ai_seat.gd'
DEFAULT_WIZARD_TAG = 'cwa0'
DEFAULT_GOD_TAG = 'james'


def scan_tags(folder):
    """tag -> (res:// path, uid or '') of every .tres in `folder` that has a `tag = "x"` line."""
    found = {}
    base = os.path.join(GAME, folder)
    for name in sorted(os.listdir(base)):
        if not name.endswith('.tres'):
            continue
        with open(os.path.join(base, name), encoding='utf-8') as handle:
            text = handle.read()
        tag = re.search(r'^tag = "([^"]*)"', text, re.M)
        uid = re.search(r'^\[gd_resource[^\]]*uid="([^"]+)"', text)
        if tag:
            found[tag.group(1)] = ('res://%s/%s' % (folder, name), uid.group(1) if uid else '')
    return found


def candidate_files():
    out = [os.path.join(GAME, 'data', 'match_rules.tres'), os.path.join(GAME, 'data', 'ai', 'seat_vs_ai.tres')]
    return [path for path in sorted(set(out)) if os.path.exists(path)]


def ext_line(kind, ref_id, path, uid):
    uid_part = ' uid="%s"' % uid if uid else ''
    return '[ext_resource type="Resource"%s path="%s" id="%s"]' % (uid_part, path, ref_id)


def migrate(text, wizards, gods):
    """Returns (new_text, changes). Works block by block: a block starts at a `[` header line."""
    script_match = re.search(r'^\[ext_resource[^\]]*path="%s"[^\]]*id="([^"]+)"' % re.escape(SEAT_SCRIPT), text, re.M)
    if not script_match:
        return text, 0
    seat_script_id = script_match.group(1)
    lines = text.split('\n')
    refs = {}  # res:// path -> id
    new_ext = []

    def ref_for(kind, tag, table):
        if tag not in table:
            sys.exit('unknown %s tag "%s"' % (kind, tag))
        path, uid = table[tag]
        if path not in refs:
            ref_id = 'seat_%s_%s' % (kind, os.path.splitext(os.path.basename(path))[0])
            refs[path] = ref_id
            new_ext.append(ext_line(kind, ref_id, path, uid))
        return 'ExtResource("%s")' % refs[path]

    out = []
    changes = 0
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        i += 1
        if not line.startswith('['):
            continue
        # collect the body of this block
        body = []
        while i < len(lines) and not lines[i].startswith('['):
            body.append(lines[i])
            i += 1
        if not any(b.strip() == 'script = ExtResource("%s")' % seat_script_id for b in body):
            out.extend(body)
            continue
        has_wizard = any(re.match(r'^wizard = ', b) for b in body)
        has_god = any(re.match(r'^god = ', b) for b in body)
        # A seat that already holds a reference was migrated: an absent `god` there means "drawn", not the old default.
        migrated = any(re.match(r'^wizard = ExtResource', b) for b in body)
        if migrated:
            has_wizard = has_god = True
        rewritten = []
        for b in body:
            m = re.match(r'^wizard = "([^"]*)"$', b)
            if m:
                rewritten.append('wizard = ' + ref_for('wizard', m.group(1), wizards))
                changes += 1
                continue
            m = re.match(r'^god = &"([^"]*)"$', b)
            if m:
                changes += 1
                if m.group(1):
                    rewritten.append('god = ' + ref_for('god', m.group(1), gods))
                continue
            rewritten.append(b)
            if b.strip().startswith('script = ExtResource'):
                if not has_wizard:
                    rewritten.append('wizard = ' + ref_for('wizard', DEFAULT_WIZARD_TAG, wizards))
                    changes += 1
                if not has_god:
                    rewritten.append('god = ' + ref_for('god', DEFAULT_GOD_TAG, gods))
                    changes += 1
        out.extend(rewritten)

    if not new_ext:
        return '\n'.join(out), changes
    # the new references go after the last [ext_resource] line
    last = max(idx for idx, l in enumerate(out) if l.startswith('[ext_resource'))
    out[last + 1:last + 1] = new_ext
    result = '\n'.join(out)
    steps = re.search(r'load_steps=(\d+)', result)
    if steps:
        result = result.replace('load_steps=%s' % steps.group(1), 'load_steps=%d' % (int(steps.group(1)) + len(new_ext)), 1)
    return result, changes


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    wizards = scan_tags('data/catalog/wizards')
    gods = scan_tags('data/gods')
    total = 0
    touched = 0
    for path in candidate_files():
        with open(path, encoding='utf-8') as handle:
            text = handle.read()
        new_text, changes = migrate(text, wizards, gods)
        if changes == 0:
            continue
        touched += 1
        total += changes
        print('%s: %d lines' % (os.path.relpath(path, GAME), changes))
        if not args.dry_run:
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(new_text)
    print('%s %d files, %d lines' % ('would change' if args.dry_run else 'changed', touched, total))


if __name__ == '__main__':
    main()
