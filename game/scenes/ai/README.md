# scenes/ai
What: an AI side plays a seat like one more player: it knows what its bodies saw (Perception), sums up the field (Groups, Stance), picks spells (Brain and its phases) and work for its creatures (Tasks), and gives orders and casts through Port, the same way a human does.
Not: the rules of a spell, a creature or a ritual (they answer through Caster, Orders and the game systems); it never cheats: no extra mana, souls or sight in any difficulty.
Talks to: AiRoster seats an AiSide per seat (ai_side.tscn); Vision -> SightIntake -> Belief; Clock runs the jobs; Brain and Tasks push into Port, which calls Caster and Orders; AiBody reads a body's parts.
Edit: data/ai/difficulty_<id>.tres (how fast and bold) · data/ai/tactics_*.tres (weights) · SpellType ai_use / ai_phase in the inspector · ai_side.tscn children (take a phase or a task out and the side stops doing it).
Check: debug/ai/*.tscn (F6: ai_match, ai_spells_lab, f371-f373) · rules_suite ai_cases, ai_tactics_cases, ai_knowledge_cases, ai_sight_cases, ai_spell_use_cases · `--log=ai_seat,ai_attack,ai_focus,ai_order,ai_summon`.

---

Un cerebro nuevo va en `brains/` como hijo de `ai_side.tscn`; los datos de tipo van en `data/ai/` como `.tres`. Las pruebas de este dominio van en `debug/ai/` y en `debug/suite/ai_*_cases.gd`. El diseño es propio; el Sacrifice original es referencia (citas al final de cada doc, en `## Ref:`).
