# ui/hud

The match HUD (`match.tscn › Hud`). Every frame, bar and font comes from `scenes/ui/theme.tres` (type variations `Hud*`);
Godot scales it from a 1280×720 base. Widgets only show state (`Health`, `ManaPool`, `SoulPurse`); `MatchWorld` binds them.
`tools/bake/hud_sheets.gd` rebuilds the HUD sheets and `fn10.fnt`.
