#!/usr/bin/env python3
"""RFC-048: apply a path-move map to the game tree (git mv + reference rewrite + checks).

  python3 tools/move_map.py <csv> [--cut b] [--dry-run] [--diff] [--apply] [--check] [--lint] [--rewrite-only]

CSV rows are `old,new,cut` relative to res:// (the game/ folder). A row ending in "/" moves a folder (every tracked
file under it keeps its relative path); other rows move one file together with its `.uid` / `.import` siblings.
Comment lines start with `#`. Directives (one per line, space separated):

  @require-empty <dir/> <cut>       every tracked file under dir must be covered by some row (validation), and once
                                    the cut is applied the dir must hold no tracked file (check)
  @require-empty-flat <dir/> <cut>  same but only for the files directly in dir (README.md is allowed)
  @forbid <text> <cut>              once the cut is applied, the text must not appear in the live files (check)
  @fix-root <glob> <cut>            after the cut, `dirname "$0")/..` becomes `dirname "$0")/../..` in matching files

Rules: no file is renamed (only the directory changes); a folder row must not contain file rows. A row is "applied"
when its old path is gone and its new path exists, so the script is idempotent. History folders (rfcs/, reviews/,
changes/) and addons/ are never rewritten. See rfcs/RFC-048-folder-structure.md.
"""
import argparse
import difflib
import fnmatch
import os
import re
import subprocess
import sys

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(GAME)
TEXT_EXT = ('.gd', '.tscn', '.tres', '.gdshader', '.gdshaderinc', '.godot', '.cfg', '.json', '.txt', '.sh', '.py',
            '.md', '.service', '.import')
SKIP_PREFIX = ('docs/AUDIT-editor-first.md', '.studio/', 'rfcs/', 'reviews/', 'changes/', 'addons/', 'tools/move_map/', 'tools/move_map.py')
EXTRA_FILES = ('../README.md', '../.gitattributes', '../.gitignore')
MAX_BYTES = 20 * 1024 * 1024
DANGLING_BASELINE = os.path.join(GAME, 'tools', 'move_map', 'dangling_baseline.txt')
LINT_BASELINE = os.path.join(GAME, 'tools', 'move_map', 'lint_baseline.txt')


def git(*args, check=True):
    return subprocess.run(['git', '-C', GAME, *args], capture_output=True, text=True, check=check).stdout


def tracked():
    return [p for p in git('ls-files', '-z').split('\0') if p]


class Row:
    def __init__(self, old, new, cut):
        self.old, self.new, self.cut = old, new, cut
        self.is_dir = old.endswith('/')
        if self.is_dir != new.endswith('/'):
            sys.exit(f'row {old} -> {new}: folder rows must end both sides in "/"')

    def pending(self, tset, dirs_old):
        if self.is_dir:
            return any(p.startswith(self.old) for p in tset) or os.path.isdir(os.path.join(GAME, self.old)) and \
                any(True for _ in os.scandir(os.path.join(GAME, self.old)) if _.name not in ('__pycache__', '.DS_Store'))
        return self.old in tset or os.path.exists(os.path.join(GAME, self.old))


def load(csv_path):
    rows, dirs = [], []
    with open(csv_path) as f:
        for ln, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if line.startswith('@'):
                parts = line.split()
                dirs.append((parts[0], parts[1:]))
                continue
            parts = line.split(',')
            if len(parts) != 3:
                sys.exit(f'{csv_path}:{ln}: expected old,new,cut')
            rows.append(Row(*[p.strip() for p in parts]))
    return rows, dirs


def siblings(path):
    """The path plus its .uid/.import siblings that exist on disk."""
    out = [path]
    for ext in ('.uid', '.import'):
        if os.path.exists(os.path.join(GAME, path + ext)):
            out.append(path + ext)
    return out


def expand(row, tset):
    """[(old_file, new_file)] for a row, siblings included (tracked and on-disk)."""
    pairs = []
    if row.is_dir:
        base = os.path.join(GAME, row.old)
        seen = set()
        for p in sorted(tset):
            if p.startswith(row.old):
                seen.add(p)
        if os.path.isdir(base):
            for root, ds, fs in os.walk(base):
                ds[:] = [d for d in ds if d != '__pycache__']
                for fn in fs:
                    if fn == '.DS_Store':
                        continue
                    seen.add(os.path.relpath(os.path.join(root, fn), GAME))
        for p in sorted(seen):
            pairs.append((p, row.new + p[len(row.old):]))
    else:
        for s in siblings(row.old):
            pairs.append((s, row.new + s[len(row.old):]))
    return pairs


def validate(rows, dirs, tset):
    errs = []
    olds = {}
    news = {}
    for r in rows:
        if r.is_dir:
            for r2 in rows:
                if not r2.is_dir and r2.old.startswith(r.old):
                    errs.append(f'folder row {r.old} contains file row {r2.old}')
        for (a, b) in expand(r, tset) if r.pending(tset, None) else []:
            if a in olds:
                errs.append(f'{a} mapped twice ({olds[a]} and {r.new})')
            olds[a] = b
            if b in news:
                errs.append(f'two files map to {b}: {news[b]} and {a}')
            news[b] = a
            if os.path.exists(os.path.join(GAME, b)):
                errs.append(f'target already exists: {b} (from {a})')
        if not r.pending(tset, None) and not (os.path.exists(os.path.join(GAME, r.new))):
            errs.append(f'row {r.old} -> {r.new}: neither old nor new exists')
    covered = lambda p: p in olds or any(p.startswith(r.old) for r in rows if r.is_dir) or \
        any(p == s for r in rows if not r.is_dir for s in siblings(r.old))
    for name, args in dirs:
        if name in ('@require-empty', '@require-empty-flat'):
            d = args[0]
            for p in sorted(tset):
                if not p.startswith(d):
                    continue
                if name == '@require-empty-flat' and ('/' in p[len(d):] or os.path.basename(p) == 'README.md'):
                    continue
                if not covered(p):
                    errs.append(f'unmapped file under {d}: {p}')
    return errs, olds


def entries_for(rows):
    """[(old_prefix_or_file, new, is_dir)] used to rewrite references."""
    out = []
    for r in rows:
        if r.is_dir:
            out.append((r.old.rstrip('/'), r.new.rstrip('/'), True))
        else:
            out.append((r.old, r.new, False))
    return out


def build_regex(entries):
    mapping = {o: n for o, n, _ in entries}
    alts = []
    for o, n, is_dir in sorted(entries, key=lambda e: -len(e[0])):
        tail = r'(?![\w.-])' if is_dir else r'(?!\w)'
        alts.append(re.escape(o) + tail)
    rx = re.compile(r'(?<![\w.-])(res://)?(' + '|'.join(alts) + ')')
    # the lookahead is inside the group; recover the matched path by stripping nothing (lookaheads consume nothing)
    return rx, mapping


def live_files():
    out = []
    for p in tracked():
        if p.startswith(SKIP_PREFIX) or not (p.endswith(TEXT_EXT) or p in ('project.godot',)):
            continue
        full = os.path.join(GAME, p)
        if not os.path.isfile(full) or os.path.getsize(full) > MAX_BYTES:
            continue
        out.append(p)
    for e in EXTRA_FILES:
        if os.path.isfile(os.path.join(GAME, e)):
            out.append(e)
    return out


def read(path):
    with open(os.path.join(GAME, path), 'r', encoding='utf-8', errors='surrogateescape', newline='') as f:
        return f.read()


def write(path, text):
    with open(os.path.join(GAME, path), 'w', encoding='utf-8', errors='surrogateescape', newline='') as f:
        f.write(text)


def rewrite_text(text, rx, mapping):
    count = [0]

    def sub(m):
        count[0] += 1
        return (m.group(1) or '') + mapping[m.group(2)]
    return rx.sub(sub, text), count[0]


def do_moves(olds):
    for a, b in sorted(olds.items()):
        os.makedirs(os.path.dirname(os.path.join(GAME, b)), exist_ok=True)
        r = subprocess.run(['git', '-C', GAME, 'mv', a, b], capture_output=True, text=True)
        if r.returncode != 0:  # untracked/ignored sibling (.import)
            os.rename(os.path.join(GAME, a), os.path.join(GAME, b))
    # drop emptied source dirs
    dirs = sorted({os.path.dirname(a) for a in olds}, key=len, reverse=True)
    for d in dirs:
        cur = d
        while cur and cur != '.':
            full = os.path.join(GAME, cur)
            if not os.path.isdir(full):
                cur = os.path.dirname(cur)
                continue
            for junk in ('__pycache__', '.DS_Store'):
                jp = os.path.join(full, junk)
                if os.path.isdir(jp):
                    subprocess.run(['rm', '-rf', jp])
                elif os.path.exists(jp):
                    os.remove(jp)
            try:
                os.rmdir(full)
            except OSError:
                break
            cur = os.path.dirname(cur)


def cmd_apply(args, rows, dirs):
    tset = set(tracked())
    errs, olds_all = validate(rows, dirs, tset)
    if errs:
        print('\n'.join('ERROR ' + e for e in errs))
        return 1
    cut_rows = [r for r in rows if r.cut == args.cut and r.pending(tset, None)]
    if args.rewrite_only:
        cut_rows = [r for r in rows if r.cut == args.cut]
        olds = {}
    else:
        olds = {}
        for r in cut_rows:
            for a, b in expand(r, tset):
                olds[a] = b
    if not cut_rows:
        print(f'cut {args.cut}: nothing pending')
        return 0
    entries = entries_for([r for r in rows if r.cut == args.cut]) if args.rewrite_only else entries_for(cut_rows)
    rx, mapping = build_regex(entries)
    dry = not args.apply
    print(f'cut {args.cut}: {len(olds)} files to move, {len(entries)} path entries ({"dry run" if dry else "apply"})')
    if dry and not args.rewrite_only:
        for a, b in sorted(olds.items()):
            if not a.endswith(('.uid', '.import')):
                print(f'  mv {a} -> {b}')
    if not dry and not args.rewrite_only:
        do_moves(olds)
    total = 0
    per_file = []
    for p in live_files():
        # in a dry run files have not moved yet: read them at the old place
        full_old = p
        if dry:
            text = read(p)
        else:
            text = read(p)
        new_text, n = rewrite_text(text, rx, mapping)
        if n:
            total += n
            per_file.append((p, n))
            if args.diff:
                sys.stdout.writelines(difflib.unified_diff(text.splitlines(True), new_text.splitlines(True),
                                                           'a/' + p, 'b/' + p, n=0))
            if not dry:
                write(p, new_text)
    if dry:
        # moved files would also be rewritten: they are in live_files already (old paths), nothing else to do
        pass
    for p, n in sorted(per_file, key=lambda x: -x[1])[:15]:
        print(f'  {n:4d} rewrites in {p}')
    print(f'  {total} reference rewrites in {len(per_file)} files')
    if not dry and not args.rewrite_only:
        for name, a in dirs:
            if name == '@fix-root' and a[1] == args.cut:
                fix_root(a[0])
    return 0


def fix_root(glob):
    n = 0
    rx = re.compile(r'(dirname "\$0"\)/)\.\.(?!/?\.)')
    for p in tracked():
        if fnmatch.fnmatch(p, glob):
            t = read(p)
            t2 = rx.sub(r'\1../..', t)
            if t2 != t:
                write(p, t2)
                n += 1
    print(f'  @fix-root {glob}: {n} files')


def applied_cuts(rows, tset):
    by = {}
    for r in rows:
        by.setdefault(r.cut, []).append(r)
    return {c: rs for c, rs in by.items() if all(not r.pending(tset, None) for r in rs)}


LITERAL = re.compile(r'res://[^\s"\'()\[\]{},;:`|\\<>%*?^]*')


def comment_at(line, idx):
    q = 0
    for i, ch in enumerate(line[:idx]):
        if ch == '"':
            q ^= 1
        elif ch == '#' and not q:
            return True
    return False


def cmd_check(args, rows, dirs):
    fails = []
    tset = set(tracked())
    errs, _ = validate(rows, dirs, tset)
    fails += [f'validate: {e}' for e in errs]
    done = applied_cuts(rows, tset)
    files = live_files()
    texts = {p: read(p) for p in files}
    # 1) no old path left (every applied cut)
    entries = []
    for c, rs in done.items():
        entries += entries_for(rs)
    if entries:
        rx, _m = build_regex(entries)
        for p, t in texts.items():
            for m in rx.finditer(t):
                line = t.count('\n', 0, m.start()) + 1
                fails.append(f'old path {m.group(2)} still in {p}:{line}')
        # binary resources (.res/.scn) keep ext_resource paths that the text rewrite cannot reach: tools/move_map/patch_res.py
        for p in sorted(tset):
            if p.endswith(('.res', '.scn')) and os.path.getsize(os.path.join(GAME, p)) < MAX_BYTES:
                with open(os.path.join(GAME, p), 'rb') as bf:
                    bt = bf.read().decode('latin-1')
                for m in rx.finditer(bt):
                    fails.append(f'old path {m.group(2)} inside binary {p} (use tools/move_map/patch_res.py)')
    for name, a in dirs:
        if name == '@forbid' and a[1] in done:
            for p, t in texts.items():
                if a[0] in t:
                    fails.append(f'forbidden text "{a[0]}" in {p}')
        if name in ('@require-empty', '@require-empty-flat') and a[1] in done:
            left = [p for p in tset if p.startswith(a[0]) and not (name.endswith('flat') and (
                '/' in p[len(a[0]):] or os.path.basename(p) == 'README.md'))]
            fails += [f'{a[0]} should be empty: {p}' for p in left[:5]]
    # 2) dangling res:// literals
    base = set()
    if os.path.exists(DANGLING_BASELINE):
        base = set(open(DANGLING_BASELINE).read().split('\n'))
    dang = {}
    for p, t in texts.items():
        for m in LITERAL.finditer(t):
            s = m.group(0).rstrip('.')
            nxt = t[m.end():m.end() + 1]
            rel = s[6:]
            if not rel:
                continue
            if nxt in ('%', '{', '+', '$') or s.endswith('/'):
                target = rel if s.endswith('/') else os.path.dirname(rel)
                ok = os.path.isdir(os.path.join(GAME, target)) if target else True
            else:
                ok = os.path.exists(os.path.join(GAME, rel))
            if not ok and s not in base:
                dang.setdefault(s, []).append(p)
    for s, ps in sorted(dang.items()):
        fails.append(f'dangling {s} (in {ps[0]}{" +%d" % (len(ps) - 1) if len(ps) > 1 else ""})')
    if args.write_baseline:
        allb = set(base) | set(dang)
        open(DANGLING_BASELINE, 'w').write('\n'.join(sorted(x for x in allb if x)) + '\n')
        print(f'dangling baseline written ({len(allb)} entries)')
        fails = [f for f in fails if not f.startswith('dangling ')]
    # 3) every .gd in product/dev folders has its .uid
    for p in tset:
        if p.endswith('.gd') and p.startswith(('scenes/', 'tools/')) and p + '.uid' not in tset:
            if os.path.exists(os.path.join(GAME, p + '.uid')) is False:
                fails.append(f'missing uid for {p}')
    # 4) autoloads and main scene
    proj = read('project.godot')
    for m in re.finditer(r'^[A-Za-z_]\w*="\*?(res://[^"]+)"', proj, re.M):
        if not os.path.exists(os.path.join(GAME, m.group(1)[6:])):
            fails.append(f'project.godot points to missing {m.group(1)}')
    m = re.search(r'run/main_scene="(res://[^"]+)"', proj)
    if m and not os.path.exists(os.path.join(GAME, m.group(1)[6:])):
        fails.append(f'main_scene missing {m.group(1)}')
    if args.lint:
        fails += lint(rows, dirs, tset, done, texts)
    for f in fails:
        print('FAIL', f)
    print(f'check: {"FAIL (%d)" % len(fails) if fails else "clean"}; applied cuts: {"".join(sorted(done)) or "-"}')
    return 1 if fails else 0


def lint(rows, dirs, tset, done, texts):
    fails = []
    base = set()
    if os.path.exists(LINT_BASELINE):
        base = set(open(LINT_BASELINE).read().split('\n'))
    hits = set()
    for p, t in texts.items():
        if not p.startswith(('scenes/', 'data/')):
            continue
        for m in re.finditer(r'res://(agent|tools)/[^\s"\'<>]*', t):
            ls = t.rfind('\n', 0, m.start()) + 1
            le = t.find('\n', m.start())
            line = t[ls:le if le >= 0 else len(t)]
            if p.endswith('.gd') and comment_at(line, m.start() - ls):
                continue
            hits.add(f'{p}: {m.group(0)}')
    for h in sorted(hits - base):
        fails.append(f'lint: product references dev folder: {h}')
    for name, a in dirs:
        if name == '@require-empty-flat' and a[1] in done:
            pass  # covered by check
    return fails


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('csv')
    ap.add_argument('--cut')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--diff', action='store_true')
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--lint', action='store_true')
    ap.add_argument('--rewrite-only', action='store_true')
    ap.add_argument('--write-baseline', action='store_true', help='record current dangling literals as pre-existing')
    args = ap.parse_args()
    rows, dirs = load(args.csv)
    if args.check or args.lint:
        return cmd_check(args, rows, dirs)
    if args.dry_run or args.apply or args.rewrite_only or args.diff:
        if not args.cut:
            sys.exit('--cut <letter> is required')
        return cmd_apply(args, rows, dirs)
    ap.print_help()
    return 2


if __name__ == '__main__':
    sys.exit(main())
