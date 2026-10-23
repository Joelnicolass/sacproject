# units
What: every creature on the map: the `Unit` scene (`UnitBody` + Health, Afflictions, Orders, Targeting, one state per mode).
Not: wizards (`scenes/wizards/`), what the AI decides (`scenes/ai/`), how a spell is cast (`scenes/spells/`).
Talks to: `Health.died` goes up to `UnitBody`, which re-emits `died/mode_changed/struck` for match, souls and HUD; `SideVision.revealed` is heard by `TargetPicker`.
Talks to: orders come down from `orders/` and `ai/` through `UnitOrders`; `UnitSpawner` builds each `Unit` from a `CreatureType`.
Edit: `data/catalog/creatures/<tag>.tres` (stats) · `unit.tscn` (parts) · `states/` (one `UnitState` per mode) · `passives/`, `afflictions/`, `abilities/` (one child each).
Debug: `debug/units/*.tscn` (F6; e.g. `creature_cap.tscn`, `ability_spit.tscn`, `f118_stun.tscn`).
Known debt: `unit_body.gd` is far over 150 lines (055c splits it); see `CONVENTIONS.md`.
