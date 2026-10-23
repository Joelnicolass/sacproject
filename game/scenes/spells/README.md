# spells
What: casting a spell: `Spellbook` (what the wizard knows, cooldowns), `Caster` (checks, mana, timing), one `SpellAction` per spell.
Not: the wizard body (`scenes/wizards/`), the spell data (`data/catalog/spells/<tag>.tres`, a `SpellType`), what the AI wants to cast (`scenes/ai/`).
Talks to: HUD/input call `Caster.request_cast/request_summon/request_structure`; the host runs `submit_*`; `Caster.feedback/cast_fx_changed` go up to the HUD.
Talks to: `Caster` calls down to a `SpellAction` (`check`, `begin`, `finish`), which spawns projectiles/effects through `SpellSpawner` and hits units via `Health`.
Edit: `data/catalog/spells/<tag>.tres` (cost, range, cooldown, `action` scene) · `actions/<name>_action.tscn` (the behaviour) · projectile/effect scenes in this folder.
Debug: `debug/spells/cast_*.tscn` (F6), `guardian_altar.tscn`, `wrath_splash.tscn`.
Known debt: `SpellType` still has raw `flags*` and unit-less fields; 4 actions are at inheritance depth 2 (see `CONVENTIONS.md`).
