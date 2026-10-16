# REVIEW RFC-019c (VFX de manantiales)

Veredicto: **PASS con observaciones**. Sin bloqueantes. Una pasada, solo lectura.

## Evidencia ejecutada
- `--script res://debug/fount_fx_probe.gd`: 7 ok, `RESULT PASS`.
- Carga headless 300 frames de `debug/{fx_gallery,teleport_home,guardian_manalith,structure_siege,mana_fount}.tscn`: sin errores ni warnings.
- Suite `debug/rules_suite.tscn --fixed-fps 600 --quit-after 600000`: exit 0, `RULES SUITE PASS`.
- `rg "func agent_" scenes`: vacio. No quedan `fx_name`, `fx_interval_s`, `ClipPose` ni `FxBus` en `scenes/world/props/manafount*`.
- Procesos Godot headless: ninguno vivo.

## Criterios de 019c
1. Chorro continuo `elec` desde el tope, sube y cae, visible en el editor: PASS. `scenes/fx/sprite_emitter.gd` es `@tool`, `FreeFx` con `start_active = true` en `scenes/world/props/manafount.tscn`. La vista real en ventana queda para el playtest (la sonda no la prueba).
2. Con Manalith: chorro off, columna `fb_g` teñida con el dueño; al destruirse vuelve: PASS. `manafount_body.gd:_set_active` conmuta y tiñe. Camino de vuelta: `structure_body.gd:50` (`_exit_tree`) y `:157` (`_on_died`) llaman `release(get_path())`; en clientes el despawn del `MultiplayerSpawner` dispara `_exit_tree`, asi que un Manalith destruido libera el manantial en clientes.
3. Efecto = nodo de escena con `ParticleType` `.tres`: PASS. `data/fx/manafount.tres`, `manalith.tres`; todo `@export` con fuente en los comentarios.
4. Servidor sin red extra, dedicado sin partículas: PASS. Sin `FxBus` ni RPC en el manantial. `SpriteEmitter._apply`/`set_active` no emiten en `DisplayServer == headless`. El `FxBus.broadcast("summon")` de `manalith_action.gd:70` es previo a 019c.
5. Sonda y estados iniciales no pre-cumplidos: PASS. `ManalithFx` nace apagado y `FreeFx` prendido; la sonda ejercita occupy/release de verdad.

## Fuentes (verificadas contra sacengine/source)
- `state.d:27769-27811`: 4 particulas/frame (240/s), disco 0,5 m, vel 20±5, vida cuadratica; manalith 4/frame, disco 3,5 m, vel 15±5. Coincide con `.tres`.
- `state.d:27984-27991` (tope = centro + 0,75), `30104-30116` (`manaColor`/`manaEnergy`), `sacobject.d:1393-1400`, `1818-1820`, `1885-1887`, `sids.d:9-16`: `side_colors.gd` reproduce paleta y `manaColor` bien.

## Red / late-join
- `manafount_path` viaja en los datos de spawn (`manalith_action.gd:67` -> `structure_spawner.gd:39` en `_make`, que corre en todos los peers antes de `add_child`) y `_ready` del Manalith llama `_claim_manafount()` (`structure_body.gd:47`). Un cliente tardío recibe el replay del spawn con el mismo diccionario, así que ve el estado correcto por código. No hay prueba (los flows `f54c_net_*` no cubren late-join): verificado por lectura, no por ejecución.

## Reglas
- `@tool` sin autoloads: `SpriteEmitter`, `FxAtlas`, `SideColors` no tocan autoloads. PASS.
- `manafount.tscn` sin texturas/mallas embebidas, `emitting` no se guarda (`start_active`). PASS.
- Composición: emisor = packed scene reusable; `manafount_body.gd` solo conmuta. PASS.
- Regla RFC-022 (~l.231): energía solo vía `ParticleType.energy` (`fx_atlas.gd` -> uniform `energy`); `SideColors.mana_energy_scale` es un multiplicador del tinte, no un glow propio. PASS (ver obs. 1).
- No rompe usuarios de `FxAtlas`/`SpriteParticles`: `sprite_particles.gd` delega, `guardian_tether.gd`, `tether.gd`, `portal_disc.gd` siguen con `FxAtlas.texture`. Carga headless sin errores.

## Observaciones (no bloquean)
1. Desvíos documentados y razonables: energía 2 (no 20), ×2 (no ×8), spread 0-27° (original 14-27°), vida uniforme en vez de cuadratica, anillo uniforme en vez de `^2` en el manalith. Registrar en el RFC como aproximación visual.
2. `fx_atlas.gd:72-88`: `_materials` se cachea por instancia de `ParticleType`; editar `energy`/`atlas_key`/`additive` en el inspector no actualiza el material (solo size/rate/etc. son "en vivo"). El criterio "se ve en vivo" vale para rate y size; matizar o invalidar la cache en `changed`.
3. `SideColors`: paleta por slot `% 8` es provisional (slot 0 = blanco). Falta el color real por bando.
4. `FreeFx` en `y = 2.75` y `ManalithFx` en `y = 15` hardcodeados en la escena; el original usa el hitbox del modelo. Aceptable para un solo modelo (`pcfn`).
5. Alcance: `git diff` muestra `scenes/world/props/altar.tscn` modificado (+50 líneas); no es de 019c según el informe. Confirmar que corresponde a otro corte.
6. Late-join y `_exit_tree` en cliente no tienen prueba automatizada; considerar un caso en `f54c_net_*`.
7. La sonda asserta flags (`is_active`), no render: el look (cantidad, brillo AgX, color) queda para `studio-playtester` / `studio-visual`. GUT/sonda no es playtest.

## Cierre
019c se puede dar por cerrado a nivel código, sujeto al playtest con ventana y capturas (regla del proyecto).
