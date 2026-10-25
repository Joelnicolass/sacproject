#!/usr/bin/env python3
"""One-shot migration (RFC-055 / 055e, cut e1): SpellType loses its flag words and gains fields with a name.

Runs without Godot and without the original game: plain Python 3, no dependencies.

  python3 tools/migrate/spell_fields_055e.py            # freezes the CSV (once) and rewrites the 53 .tres
  python3 tools/migrate/spell_fields_055e.py --dry-run  # prints what it would change

Before:  flags = 8213, flags1 = 16449, amount2 = 650, count = 8, ai_use = 2
After:   targets_wizards = true, ..., ai_phase = 1, ai_worth = 650, max_targets = 8

The inputs are read from the .tres (flags, flags1, flags2, amount2, count, effect_range_m, ai_use) the first time, and frozen in
debug/suite/spell_bits_055e.csv. Later runs read the CSV, so the script is idempotent. The bits are translated like the
SpellBits tool does when it bakes (tools/bake/spell_bits.gd): the same table, written twice on purpose, because spell_field_cases
proves the two agree. Bits nobody reads (flags 16-20, flags1 0, 1, 5, all of flags2) are lost on purpose; the CSV keeps them.
"""
import csv
import glob
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SPELLS = os.path.join(ROOT, "data", "catalog", "spells")
CSV_PATH = os.path.join(ROOT, "debug", "suite", "spell_bits_055e.csv")
COLUMNS = ["tag", "flags", "flags1", "flags2", "amount2", "count", "effect_range_m", "ai_use_before"]

# SpellType.AiUse / AiPhase are saved as integers; only append.
AI_USE = {"NONE": 0, "SELF_GUARD": 1, "DISABLE_FOE": 2, "HIT_ONE": 3, "HIT_AREA": 4, "HEAL": 5, "SPEEDUP": 6, "CONVERT": 7, "DESECRATE": 8}
AI_PHASE = {"NEVER": 0, "ATTACK": 1, "SUPPORT": 2}

# flags bit -> bool (SpellType, group «AI: who it may land on»)
FLAG_BITS = [("targets_wizards", 0), ("targets_souls", 1), ("targets_creatures", 2), ("targets_corpses", 3), ("targets_structures", 4),
	("only_free_manafounts", 11), ("only_allies", 12), ("never_allies", 13), ("targets_ground", 14)]

# The order the properties have in spell_type.gd (what ResourceSaver would write).
ORDER = ["script", "tag", "display_name", "icon", "mana_cost", "cast_range_m", "cooldown_s", "casting_time_s", "spell_order", "speed_m_s",
	"acceleration_m_s2", "damage", "damage_range_m", "effect_range_m", "duration_s", "is_structure", "action"] \
	+ [name for name, _ in FLAG_BITS] + ["ai_use", "ai_phase", "ai_only_on_self", "ai_worth", "max_targets"]
REMOVED = {"flags", "flags1", "flags2", "amount2", "count"}

# What the plan 055e §8.1 says the bits must give (the check that the derivation is right).
PLAN_USE = {
	"SELF_GUARD": "niks dlhs mrfe mrff rwsp", "DISABLE_FOE": "zerf eniv rapf htel", "HIT_ONE": "kcor ntil mrws ivob pavi",
	"HIT_AREA": "brif oalf clov cnef egar galp grfr laws lawv laww likc lwrf nrot ntlc olah pxef rifd rifr rtem tfir tpre zorf",
	"HEAL": "laeh rter ruah wobr", "SPEEDUP": "pups", "CONVERT": "ccas", "DESECRATE": "ucas",
	"NONE": "deda dnws elet erob htlm mrhc ndrg pcas pmcd taed"}
PLAN_PHASE = {
	"ATTACK": "brif clov cnef egar eniv galp grfr htel ivob kcor laws lawv laww likc lwrf mrhc mrws nrot ntil ntlc oalf olah pavi pxef rapf "
		"rifd rifr rtem taed tfir tpre zerf zorf",
	"SUPPORT": "dlhs elet laeh mrfe mrff ndrg niks pups rter ruah rwsp wobr", "NEVER": "ccas deda dnws erob htlm pcas pmcd ucas"}
PLAN_ONLY_ON_SELF = "dlhs elet mrfe mrff niks olah rwsp"


def parse(path):
	text = open(path, encoding="utf-8").read()
	head, body = text.split("[resource]\n", 1)
	values = {}
	for line in body.strip().split("\n"):
		key, value = re.match(r"^([a-z_0-9]+) = (.*)$", line).groups()
		values[key] = value
	return head, values


def legacy_ai_use(tag, flags1, effect_range_m):
	"""The ai_use the old rating_fn chain gave (ai_spell_eval.gd before 055e), by tag first, then by the flags1 chain."""
	if tag in ("ccas", ):
		return "CONVERT"
	if tag in ("ucas", ):
		return "DESECRATE"
	if tag == "laeh":
		return "HEAL"
	if tag == "pups":
		return "SPEEDUP"
	if tag in ("omna", "ndrg", "elet", "taed"):
		return "NONE"
	if flags1 & 0x4000:
		return "HIT_AREA" if ((flags1 & 0x40) != 0 and effect_range_m > 0.0) else "HIT_ONE"
	if flags1 & 0x8000:
		return "HEAL"
	return "NONE"


def derive(row):
	flags, flags1 = row["flags"], row["flags1"]
	attack = flags1 & 0x5800 != 0   # bits 11, 12, 14: the old ATTACK_MASK 0x58000000 >> 16
	support = flags1 & 0xA400 != 0  # bits 10, 13, 15: the old SUPPORT_MASK 0xa4000000 >> 16
	assert not (attack and support), row["tag"]
	fields = {name: bool(flags & (1 << bit)) for name, bit in FLAG_BITS}
	fields["ai_use"] = legacy_ai_use(row["tag"], flags1, row["effect_range_m"])
	# the old rating_fn gave GUARD / DISABLE by the baked ai_use of 023/041, which the bits do not carry
	if row["ai_use_before"] == 1:
		fields["ai_use"] = "SELF_GUARD"
	elif row["ai_use_before"] == 2:
		fields["ai_use"] = "DISABLE_FOE"
	fields["ai_phase"] = "ATTACK" if attack else ("SUPPORT" if support else "NEVER")
	fields["ai_only_on_self"] = bool(flags1 & 0x10)
	fields["ai_worth"] = row["amount2"]
	fields["max_targets"] = row["count"]
	return fields


def check_plan(derived):
	problems = []
	for table, key in ((PLAN_USE, "ai_use"), (PLAN_PHASE, "ai_phase")):
		for value, tags in table.items():
			for tag in tags.split():
				if derived[tag][key] != value:
					problems.append("%s: %s = %s, plan says %s" % (tag, key, derived[tag][key], value))
	for tag, fields in derived.items():
		if fields["ai_only_on_self"] != (tag in PLAN_ONLY_ON_SELF.split()):
			problems.append("%s: ai_only_on_self = %s, plan disagrees" % (tag, fields["ai_only_on_self"]))
	return problems


def lines_of(values, fields):
	merged = {k: v for k, v in values.items() if k not in REMOVED and k not in ("ai_use",)}
	for name, value in fields.items():
		if value is True:
			merged[name] = "true"
		elif value is False or value == 0 or value in ("NONE", "NEVER"):
			continue
		elif name == "ai_use":
			merged[name] = str(AI_USE[value])
		elif name == "ai_phase":
			merged[name] = str(AI_PHASE[value])
		else:
			merged[name] = str(value)
	keys = [k for k in ORDER if k in merged] + [k for k in merged if k not in ORDER]
	return "\n".join("%s = %s" % (k, merged[k]) for k in keys) + "\n"


def main():
	dry = "--dry-run" in sys.argv
	files = sorted(glob.glob(os.path.join(SPELLS, "*.tres")))
	rows = {}
	if os.path.exists(CSV_PATH):
		for r in csv.DictReader(open(CSV_PATH, encoding="utf-8")):
			rows[r["tag"]] = {"tag": r["tag"], "flags": int(r["flags"]), "flags1": int(r["flags1"]), "flags2": int(r["flags2"]),
				"amount2": int(r["amount2"]), "count": int(r["count"]), "effect_range_m": float(r["effect_range_m"]), "ai_use_before": int(r["ai_use_before"])}
	else:
		for f in files:
			head, v = parse(f)
			tag = v["tag"].strip('"')
			rows[tag] = {"tag": tag, "flags": int(v.get("flags", 0)), "flags1": int(v.get("flags1", 0)), "flags2": int(v.get("flags2", 0)),
				"amount2": int(v.get("amount2", 0)), "count": int(v.get("count", 0)), "effect_range_m": float(v.get("effect_range_m", 0)),
				"ai_use_before": int(v.get("ai_use", 0))}
		if not dry:
			with open(CSV_PATH, "w", encoding="utf-8", newline="") as out:
				w = csv.writer(out, lineterminator="\n")
				w.writerow(COLUMNS)
				for tag in sorted(rows):
					w.writerow([rows[tag][c] for c in COLUMNS])
	assert len(rows) == 53 == len(files), (len(rows), len(files))
	derived = {tag: derive(row) for tag, row in rows.items()}
	problems = check_plan(derived)
	if problems:
		print("\n".join(problems))
		sys.exit("the derivation disagrees with the plan; nothing written")
	for f in files:
		head, values = parse(f)
		tag = values["tag"].strip('"')
		text = head + "[resource]\n" + lines_of(values, derived[tag])
		if not dry:
			open(f, "w", encoding="utf-8").write(text)
		print("%s %s" % ("would write" if dry else "wrote", os.path.relpath(f, ROOT)))


if __name__ == "__main__":
	main()
