# RFC-016 — Núcleo de juego de Sacrifice

Plan del tech lead. Las reglas y los números salen de `.studio/RESEARCH.md`. Arquitectura estándar. Online con dedicado: el servidor aplica cada regla y el cliente manda `submit_*` y pinta. Se saltea el reviewer: después de cada corte juega el playtester.

## Decisiones

- **Datos.** `tools/export_stats.py` escribe JSON en `cache/data/`. El autoload `GameData` arma en memoria los Resources (`CreatureType`, `SpellType`, `AbilityType`, `WizardType`). No se commitean `.tres` con estadísticas originales. Los `.tres` commiteados (`MatchRules`, `GodTheme`, `MapLayout`, `ParticleType`) solo llevan constantes del motor citadas en RESEARCH y tags.
- **Escenas de prueba.** Cada `res://debug/*.tscn` instancia `high_noon.tscn` y le cambia `@export var rules: MatchRules` por `debug/rules/*.tres`. Un atajo de debug es otro `.tres`, nunca otro script.
- **Red.** El cuerpo tiene `owner_slot`. El servidor valida `MpKit.slot_for_peer(sender) == owner_slot`. Los valores se replican con `MpReplicate` (`Health:current`, `Mana:current`, `SoulPurse:count`).
- **Almas iniciales:** 12 (`MatchRules.starting_souls`), como sacengine. El valor de WIZD es 0.
- **Cámara:** la del original. Bordes de 100 px: los costados giran y arriba/abajo hacen zoom. Vista libre con el botón central o Ctrl+clic izquierdo. Esto reemplaza el arrastre con el botón derecho de F15.
- **Teclas:** WASD para moverse, a pedido del usuario. El hechizo 5 pasa de W a E.

## Árbol

```
game/
  data/ match_rules.tres · gods/*.tres · layouts/high_noon.tres · fx/*.tres
  debug/ data_book · sky_motion · mana_fount · fx_gallery · cast_heal · summon_unit · melee_duel
         orders_group · rock_hit · ability_spit · soul_pickup · wizard_ghost · biome_pick (.tscn) · rules/*.tres
  scenes/data/ game_data.gd (autoload GameData) · body_library.gd (autoload BodyLibrary)
               creature_type.gd · spell_type.gd · ability_type.gd · wizard_type.gd · match_rules.gd · god_theme.gd · map_layout.gd
  scenes/ui/ character_select · wizard_preview · hud · stat_bar · spell_book
  scenes/world/ world_camera · sky.gd · map_props.gd · selection.gd
     components/ health · mana_pool · soul_purse · mana_source · body_visual
     wizard/ wizard.tscn · caster · ghost_form
     units/ unit.tscn · unit_orders · melee_attack · ranged_attack · active_ability · corpse
     spells/ rock_projectile · wrath_strike · heal_effect · speedup_effect
     props/ manafount.tscn · altar.tscn · souls/soul
  scenes/fx/ particle_type.gd · sprite_particles · fx_bus.gd
  tools/ export_stats.py · bake_bodies.gd · export_particles.py · export_tilesets.py
```

## Cortes

| Corte | Qué entrega | Escena de prueba |
|---|---|---|
| F16 | Datos del instalador | `debug/data_book.tscn` |
| F17 | Mallas horneadas, manantial y altar | `high_noon.tscn` |
| F18 | Cámara original e InputMap completo | `high_noon.tscn` |
| F19 | Cielo en movimiento, sin costuras | `debug/sky_motion.tscn` |
| F20 | Un mago por slot, HUD de vida/maná/almas | dedicado + 2 clientes |
| F21 | Selección de mago y dios | `boot.tscn` |
| F22 | Maná por manantial y altar | `debug/mana_fount.tscn` |
| F23 | Base de partículas | `debug/fx_gallery.tscn` |
| F24 | Libro y lanzamiento (Speedup, Heal, hechizo del dios) | `debug/cast_heal.tscn` |
| F25 | Convocar criaturas del dios | `debug/summon_unit.tscn` |
| F26 | Cuerpo a cuerpo, muerte y cadáver | `debug/melee_duel.tscn` |
| F27 | Órdenes RTS y selección completa | `debug/orders_group.tscn` |
| F28 | Daño de hechizos (Rock, Wrath) | `debug/rock_hit.tscn` |
| F29 | Habilidades de criatura | `debug/ability_spit.tscn` |
| F30 | Almas | `debug/soul_pickup.tscn` |
| F31 | Vida y fantasma del mago | `debug/wizard_ghost.tscn` |
| F32 | Biomas al azar | `debug/biome_pick.tscn` |

Los criterios de cada corte están en `FEATURES.md`.

## Riesgos

- **Dedicado sin pantalla.** La colisión sale de `bodies.json`, no de la malla.
- **Carga de modelos de 10 s.** Se resuelve con mallas `.res` horneadas y la caché de `BodyLibrary`. Los OBJ en crudo van a una carpeta con `.gdignore`.
- **Choques de teclas.** Shift+W, Ctrl+A y Ctrl+Q pisan teclas de movimiento: usar coincidencia exacta de modificadores. En macOS, LAlt es Option.
- **Borde inferior y HUD.** Ignorar los bordes cuando el mouse no está sobre `%View`.
- **Biomas.** Los índices de baldosa de High Noon son del tileset de James; con otro atlas pueden quedar fuera de rango.
- **Fuera de alcance:** Manalito, Guardian, Convert, Desecrate, Teleport, Sac Doctor, victoria y subida de nivel.
