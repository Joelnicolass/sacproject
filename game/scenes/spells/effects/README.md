# spells/effects
What: what a spell does to ONE body when its `SpellCarrier` gets there. A `BodyEffect` is a Resource embedded in a `TargetEffect` child of the carrier: `AfflictEffect` (lays a state: Blind Rage's fury), `GibEffect` (the creature bursts, its soul stays), `KillEffect` (Death's blow, with bolts), `SideChangeEffect` (Charm: the creature is the wizard's for good).
Not: when it happens (the carrier's `arrived` / `settled`), who the target is (`SpellTarget`), how long a state lasts (the `Affliction`), the look (the carrier's other children).
Talks to: `TargetEffect` calls `apply(carrier, body)`; the effect reads the carrier's `spell`, `from_slot` and `wizard()`; `Gib` (units/gib.gd) and `Health.kill` do the dying.
Edit: the sub-resource inside `carrier/<spell>.tscn` (`flash`, `hearts`, `beam`, `strike`, `affliction`). A new thing a carrier can do = a new `BodyEffect` script here, one per KIND of effect, never one per spell.
