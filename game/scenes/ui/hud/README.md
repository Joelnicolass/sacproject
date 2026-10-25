# ui/hud
What: the match HUD (`match.tscn › Hud`): book, roster, stats, minimap, radial, target box. Every frame, bar and font comes from `data/ui/theme.tres` (variations `Hud*`); Godot scales it (`canvas_items`, base 1280×720).
Not: the wizard's rules (the widgets only show Health, ManaPool, SoulPurse), the lobby and the pickers, the pictures of spells, abilities and creatures (the `icon` of each type).
Talks to: `MatchWorld` calls `bind` on `WizardHud`/`SpellBook`; each widget listens to its own signals; the art is plain textures in the theme.
Edit: theme.tres › `HudManaBar`/`HudHealthBar` (bars), `HudStatsFrame`, `HudRosterFrame`, `HudMinimapFrame`, `HudBookStrip`/`HudBookCap`, `HudSoulCount` (font) · `wizard_stats.tscn › Souls › Spin` (the turning soul).
Check: F6 on `wizard_stats.tscn` (drag `value` of `Mana/ManaBar`), `agent/harness/match_shots` view `hud` · `tools/bake/hud_sheets.gd` rebuilds the 8 sheets and `fn10.fnt` from the sheets in git.
