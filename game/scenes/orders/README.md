# orders

Player input and orders. The rules of a group order (who of the slot obeys, the formation, each unit's place) are the
RtsKit's `RtsOrders` (`Input/Orders` in `match.tscn`); Sacrifice's commands (`commands.tres`: the kit's plus
`attack_body`, an attack on a wizard or a building with no retarget) and formations (`formations.tres` and its eight
`.tres`) are data here. `scenes/net/order_link.gd` connects them to the game: the retreat anchor, the retarget, the
local slot and the network. Each creature carries the order out in `UnitOrders` (`scenes/units/unit_orders.gd`).

`MatchCommand` (in `match.tscn`) only coordinates input: each child (`CommandInput`, `PointerRay`, `ArmedCommand`,
`SpellCommand`, `OrderCommand`, `GroupKeys`, `MinimapPointing`, `ArmedPreview`…) owns one kind of input.
