# units/passives

What a creature has all the time (Firefist's fury, Phoenix's fire shield, Manahoar's mana aura…). Each passive is a
`UnitPassive` node with its numbers in the inspector, inside `creatures/<creature>/<creature>_passives.tscn`. The body frame
instances that scene as `Passives`, and `PassiveMount` (`Unit/Passives` in `unit.tscn`) builds it on every peer when the
creature type is set. Add one: put the node in that creature's `_passives.tscn` (create it and instance it in the frame if
the creature has none).
