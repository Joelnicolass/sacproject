#!/usr/bin/env python3
"""One-shot migration (RFC-055 / 055e, cut e6): AbilityType loses flags/flags1/flags2/amount2/args and spell_order becomes level + position.

Runs without Godot and without the original game: plain Python 3, no dependencies.

  python3 tools/migrate/ability_fields_055e6.py            # freezes the old values (once) and rewrites the .tres
  python3 tools/migrate/ability_fields_055e6.py --dry-run  # prints what it would change

Abilities (data/catalog/abilities/*.tres):
  Before:  flags = 16405, flags1 = 16417, amount2 = 500, args = {"ires": 1000.0, "freg": 0.0, ...}
  After:   targets_wizards = true, targets_creatures = true, targets_structures = true, targets_ground = true,
           ai_attack = true, ai_worth = 500, poison_resistance_debuff = 1000, poison_regen_factor = 0.0
Books (data/catalog/creatures, data/catalog/spells, data/templates/creature.tres):
  Before:  spell_order = 238        After:  book_level = 2, book_slot = 38

Only what the game reads becomes a field (the readers: ability_command, ai_rater, poison_cloud, poison_impact). The rest of the
words and args is lost on purpose; the frozen copies keep it:
  debug/suite/ability_bits_055e6.txt   file, tag, flags, flags1, flags2, amount2, ires, freg  (empty ires/freg = the key was not in args)
  debug/suite/book_order_055e6.txt     kind, file, spell_order
The first run reads the old .tres and freezes them; later runs read the frozen copies, so the script is idempotent.
"""
import csv
import glob
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ABILITIES = os.path.join(ROOT, "data", "catalog", "abilities")
BOOK_FOLDERS = [("creature", os.path.join(ROOT, "data", "catalog", "creatures")), ("spell", os.path.join(ROOT, "data", "catalog", "spells"))]
TEMPLATE = os.path.join(ROOT, "data", "templates", "creature.tres")
BITS_PATH = os.path.join(ROOT, "debug", "suite", "ability_bits_055e6.txt")
ORDER_PATH = os.path.join(ROOT, "debug", "suite", "book_order_055e6.txt")
BITS_COLUMNS = ["file", "tag", "flags", "flags1", "flags2", "amount2", "ires", "freg"]
ORDER_COLUMNS = ["kind", "file", "spell_order"]

# flags bit -> bool: the target kinds the game reads (spells.d targetSouls / targetCorpses, targetCreatures) and the ones that make `flags != 0`.
FLAG_BITS = [("targets_wizards", 0), ("targets_souls", 1), ("targets_creatures", 2), ("targets_corpses", 3), ("targets_structures", 4),
	("targets_ground", 14)]
ATTACK_BIT = 0x4000  # in flags1
REMOVED = {"flags", "flags1", "flags2", "amount2", "args"}
# The order the properties have in ability_type.gd (what ResourceSaver would write).
ABILITY_ORDER = ["script", "effect", "tag", "display_name", "icon", "mana_cost", "cast_range_m", "cooldown_s", "casting_time_s", "speed_m_s",
	"acceleration_m_s2", "damage", "damage_range_m", "effect_range_m", "duration_s"] + [name for name, _ in FLAG_BITS] \
	+ ["ai_attack", "ai_worth", "poison_resistance_debuff", "poison_regen_factor"]


def split_resource(path):
	"""(head, entries) of a .tres; a multi-line `args = { ... }` is one entry."""
	text = open(path, encoding="utf-8").read()
	head, body = text.split("[resource]\n", 1)
	entries = []
	lines = body.rstrip("\n").split("\n")
	i = 0
	while i < len(lines):
		line = lines[i]
		if line.rstrip().endswith("{"):
			block = [line]
			while not lines[i].startswith("}"):
				i += 1
				block.append(lines[i])
			entries.append("\n".join(block))
		else:
			entries.append(line)
		i += 1
	return head, entries


def key_of(entry):
	return entry.split(" = ", 1)[0]


def value_of(entry):
	return entry.split(" = ", 1)[1]


def args_of(entry):
	found = {}
	for line in entry.split("\n")[1:-1]:
		m = re.match(r'^"([^"]+)": (.*?),?$', line)
		found[m.group(1)] = m.group(2)
	return found


def old_ability_row(path):
	head, entries = split_resource(path)
	values = {key_of(e): value_of(e) for e in entries if " = " in e}
	args = {}
	for e in entries:
		if key_of(e) == "args":
			args = args_of(e)
	return {"file": os.path.basename(path)[:-5], "tag": values["tag"].strip('"'), "flags": int(values.get("flags", 0)),
		"flags1": int(values.get("flags1", 0)), "flags2": int(values.get("flags2", 0)), "amount2": int(values.get("amount2", 0)),
		"ires": "" if "ires" not in args else str(int(float(args["ires"]))), "freg": "" if "freg" not in args else repr(float(args["freg"]))}


def fields_of(row):
	flags, flags1 = int(row["flags"]), int(row["flags1"])
	fields = {name: bool(flags & (1 << bit)) for name, bit in FLAG_BITS}
	fields["ai_attack"] = bool(flags1 & ATTACK_BIT)
	fields["ai_worth"] = int(row["amount2"])
	fields["poison_resistance_debuff"] = int(row["ires"]) if row["ires"] != "" else 0
	fields["poison_regen_factor"] = float(row["freg"]) if row["freg"] != "" else 1.0
	return fields


def text_of(value):
	if value is True:
		return "true"
	if isinstance(value, float):
		return repr(value)
	return str(value)


def rewrite_ability(path, row, dry):
	head, entries = split_resource(path)
	merged = {key_of(e): value_of(e) for e in entries if " = " in e and key_of(e) not in REMOVED}
	for name, value in fields_of(row).items():
		default = 1.0 if name == "poison_regen_factor" else (0 if name in ("ai_worth", "poison_resistance_debuff") else False)
		if value != default:
			merged[name] = text_of(value)
	keys = [k for k in ABILITY_ORDER if k in merged] + [k for k in merged if k not in ABILITY_ORDER]
	text = head + "[resource]\n" + "\n".join("%s = %s" % (k, merged[k]) for k in keys) + "\n"
	if not dry:
		open(path, "w", encoding="utf-8").write(text)


def rewrite_order(path, spell_order, dry):
	"""spell_order = N  ->  book_level = N // 100 and book_slot = N % 100 (a zero is left out, as the engine does)."""
	text = open(path, encoding="utf-8").read()
	lines = []
	for line in text.split("\n"):
		m = re.match(r"^spell_order = (\d+)$", line)
		if m:
			lines.extend(["%s = %d" % (k, v) for k, v in (("book_level", spell_order // 100), ("book_slot", spell_order % 100)) if v != 0])
		else:
			lines.append(line)
	if not dry:
		open(path, "w", encoding="utf-8").write("\n".join(lines))


def read_csv(path):
	with open(path, encoding="utf-8") as f:
		return list(csv.DictReader(f))


def write_csv(path, columns, rows, dry):
	if dry:
		return
	with open(path, "w", encoding="utf-8", newline="") as out:
		w = csv.writer(out, lineterminator="\n")
		w.writerow(columns)
		for r in rows:
			w.writerow([r[c] for c in columns])


def book_paths():
	paths = []
	for kind, folder in BOOK_FOLDERS:
		paths += [(kind, p) for p in sorted(glob.glob(os.path.join(folder, "*.tres")))]
	paths.append(("template", TEMPLATE))
	return paths


def main():
	dry = "--dry-run" in sys.argv
	files = sorted(glob.glob(os.path.join(ABILITIES, "*.tres")))
	if os.path.exists(BITS_PATH):
		rows = {r["file"]: r for r in read_csv(BITS_PATH)}
	else:
		rows = {}
		for f in files:
			row = old_ability_row(f)
			rows[row["file"]] = row
		write_csv(BITS_PATH, BITS_COLUMNS, [rows[k] for k in sorted(rows)], dry)
	for f in files:
		rewrite_ability(f, rows[os.path.basename(f)[:-5]], dry)
		print("%s %s" % ("would write" if dry else "wrote", os.path.relpath(f, ROOT)))
	if os.path.exists(ORDER_PATH):
		orders = {(r["kind"], r["file"]): int(r["spell_order"]) for r in read_csv(ORDER_PATH)}
	else:
		orders = {}
		for kind, p in book_paths():
			m = re.search(r"^spell_order = (\d+)$", open(p, encoding="utf-8").read(), re.M)
			if m:
				orders[(kind, os.path.basename(p)[:-5])] = int(m.group(1))
		write_csv(ORDER_PATH, ORDER_COLUMNS, [{"kind": k, "file": f, "spell_order": v} for (k, f), v in sorted(orders.items())], dry)
	for kind, p in book_paths():
		value = orders.get((kind, os.path.basename(p)[:-5]))
		if value is not None:
			rewrite_order(p, value, dry)
			print("%s %s" % ("would write" if dry else "wrote", os.path.relpath(p, ROOT)))


if __name__ == "__main__":
	main()
