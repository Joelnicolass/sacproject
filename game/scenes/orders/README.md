# orders

Player input and orders: selection, commands, formations, the radial menu and `world_input`. Input calls `Orders`; it
never simulates. `MatchCommand` (in `match.tscn`) only coordinates: each child (`CommandInput`, `PointerRay`,
`ArmedCommand`, `SpellCommand`, `OrderCommand`, `GroupKeys`, `MinimapPointing`, `ArmedPreview`…) owns one kind of input.
