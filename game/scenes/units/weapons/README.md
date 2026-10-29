# units/weapons

A creature's weapons are the children of its `Weapons` node (`Melee`, `Ranged`). The first child that wants the foe is
used, so the order of the children is the priority. Add one by dropping `melee_weapon.tscn` or `ranged_weapon.tscn` and
setting `attack_type`. A breath is a `RangedWeapon` whose shot look is a wave.
