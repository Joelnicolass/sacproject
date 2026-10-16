### feature/flying-creatures

**What**: Soporte para criaturas voladoras: movimiento 3D sin gravedad, sin GroundGuard. Detecta `is_flying()` de `CreatureType` (running_speed ≤ 0 y flying_speed > 0). Las voladoras usan `flying_speed` en lugar de `running_speed` y mantienen altura arbitraria.
**Why**: RFC-016 necesita voladoras para Wrath (Persephone) y otros hechizos. La infraestructura existe en datos (6 voladoras: tbsh, pazb, sohf, bobs, sohe, pezH) pero aún no están en los libros de dioses.
**Where**: `scenes/world/unit_body.gd` (_apply_type, _ready, _physics_process)
**Learned**: Voladoras no se sientan en _ready. No reciben gravedad. No usan GroundGuard. Pueden moverse en 3D completo. Los tests de voladoras necesitan que estén en un libro de dios para ser convocadas.

### architecture/style

**What**: Arquitectura estándar, escenas junto al script.
**Why**: El plan aceptado pide una base chica, no Clean.
**Where**: `game/`
**Learned**: No crear `src/domain/`.

### architecture/mp-type

**What**: Multijugador online con servidor dedicado en el mismo proyecto.
**Why**: El usuario eligió internet, no Wi-Fi.
**Where**: `scenes/flow/sacrifice_flow.gd`
**Learned**: Peer 1 no es jugador. Clientes a `127.0.0.1` en local. No usar `host()` como si fuera online.

### feature/f25-flying-summon

**What**: Las invocaciones voladoras ya no responden «No implementado». `Summoner.can_summon` acepta cualquier `CreatureType`. El spawn vuelve al suelo (como `spawnPosition` de sacengine) y `UnitBody` mantiene altura de vuelo sobre terreno.
**Why**: Gargoyle/Shrike quedaban bloqueados aunque el loop de summon ya estaba completo.
**Where**: `scenes/world/spells/summoner.gd`, `scenes/world/unit_body.gd`, `agent/flows/f25_flying_summon.json`
**Learned**: sacengine usa `spawnPosition` al suelo (`state.d:8423`) y sostén en vuelo por AGL (`CreatureStats.flyingHeight = 4.5`, `upwardHoverSpeed = downwardHoverSpeed = 3.0`, `stats.d`). En flow, Gargoyle sube de Y≈17.00 a Y≈19.45 y luego Y≈20.34 al moverse, sin romper `f25_summon`.

### ownership/mp-kit

**What**: MpKit y godot-studio-skills son del usuario. Se puede modificar el plugin si hace falta.
**Why**: Lo pidió explícitamente. El cambio bueno se pushea al repo oficial después.
**Where**: `game/addons/mp_kit/` viene de `godot-studio-skills/addons/mp_kit/`
**Learned**: No meter gameplay de Sacrifice en el kit. Sí corregir el kit y devolver el diff upstream.

### engine

**What**: Godot 4.7.2 en `Downloads/Godot-7.app`.
**Why**: El usuario indicó ese instalador.
**Where**: binario `Contents/MacOS/Godot`

### feature/f4-terrain

**What**: High Noon se exporta a `game/cache/high_noon_terrain.bin` con relieve y paredes de 50.
**Why**: El usuario pidió las paredes en el mismo corte.
**Where**: `game/tools/export_high_noon_terrain.py`, `scenes/world/terrain.gd`
**Learned**: 256×256, 20586 vértices, 508 paredes. El bin no se commitea. El suelo se veía transparente porque las caras de tierra quedaban del lado que Godot descarta; las paredes no. En el export, la tierra no invierte el orden y la normal apunta hacia arriba.

### slice/pair

**What**: F5 pasó. James y el campesino se leen como dos cuerpos.
**Why**: El campesino venía acostado y chico; se paró y se escaló a la altura de James.
**Where**: `scenes/world/high_noon.gd`, `agent/out/high_noon_pair.png`
**Learned**: El campesino se para con un giro de −90° en X y se escala a la altura de James.

### slice/wizard

**What**: F4 y el mago de F5 pasaron el playtest visual.
**Why**: La captura muestra el cañón y a James con báculo en el centro.
**Where**: `agent/out/high_noon_wizard.png`, `scenes/world/wizard.gd`
**Learned**: La criatura todavía no está. La textura del mago tampoco.

### slice/net

**What**: F1, F2 y F3 pasaron el playtest. Unirse muestra «Slot 1» legible.
**Why**: El rótulo estaba al revés; se quitó el giro de 180 grados.
**Where**: `scenes/world/high_noon.gd`, `agent/out/f2_slot_readable.png`
**Learned**: El siguiente corte visible ya está exportado (terreno). Falta el mago.

### feature/f9-move

**What**: F9 cerrado. Una orden move real. El dump sale en el frame 49, en (1507.67, 16.9, 1555.94), a 5.25 del spawn de F8.
**Why**: ObjectState.update ejecuta la orden por controller.run. Godot solo presenta el archivo.
**Where**: `sacengine/source/dagonBackend.d`, `scenes/world/move_order_check.gd`, `debug/move_order.tscn`, `agent/out/f9_coincide.png`
**Learned**: El id del mago va en el puesto del wizard y en el de la criatura. El archivo se escribe en cuanto pasa de 5, así que no recorre los 40 del destino. Colocar al mago en la posición final de una vez es un salto. El jugador no se mueve así.

### feature/f8-state

**What**: F8 cerrado. Tras 60 frames de ObjectState el mago del slot 0 queda en (1502.47, 16.9, 1555.2). Godot solo lo presenta.
**Why**: La posición sale del update que ya corre controller.run, y Godot solo la presenta.
**Where**: `sacengine/source/dagonBackend.d`, `scenes/world/state_tick_check.gd`, `game/cache/tick_state_ref.txt`, `agent/out/f8_coincide.png`
**Learned**: La conversión es Vector3(x, z, y) y no resta la base otra vez. Esos 60 frames no llevan una orden de movimiento: la posición es la de aparición.

### feature/f7-advance

**What**: F7 cerrado. El avance usa speed 3, fps 60, n 60 y step 0.05. Sesenta sumas dejan z = 3 y la vida en 1. El playtest movió al mago de Z 1275 a 1278.
**Why**: Es el mismo paso cinemático del dump idle (speed/fps por tick), sumado en z. No es combate.
**Where**: `sacengine/source/app.d`, `scenes/world/advance_order.tres`, `debug/advance_tick.tscn`, `agent/out/f7_coincide.png`
**Learned**: No llama `ObjectState.update` ni reescribe `state.d`. Si los dos dumps se piden juntos, el idle sigue ganando.

### feature/f6-idle

**What**: F6 cerrado. El tick quieto escribe la referencia en sacengine y Godot muestra «coincide».
**Why**: Comparar posición y vida sin reescribir `state.d`.
**Where**: `sacengine/source/app.d`, `scenes/world/tick_check.gd`, `debug/idle_tick.tscn`, `agent/out/f6_coincide.png`
**Learned**: Velocidad 0 y vida 1 en los dos lados. No llama `ObjectState.update`. No es una pelea.

### architecture/physics

**What**: El mago es un CharacterBody3D y el terreno tiene trimesh. move_and_slide lo apoya y lo camina.
**Why**: El usuario pidió usar el motor, no un integrador propio.
**Where**: `scenes/world/wizard_body.gd`, `scenes/world/terrain.gd`, `debug/walk_order.tscn`
**Learned**: Al sentarlo, el rayo lo deja en y ≈ 11.9, no en 53.4. En 1 s recorre unos 6.4 m en solo. En red el dedicado mueve el cuerpo y el cliente pinta.

### feature/f17-bodies

**What**: `tools/bake_bodies.gd` hornea 84 cuerpos y 70 props (edificios y plantas de Persephone) a `cache/baked/{bodies,props}/*.res`, más `bodies.json` y `props.json`. El autoload `BodyLibrary` y `body_visual.gd` los muestran. `map_props.gd` pone por slot el altar `alt1` y el manantial `pcfn`, más 40 plantas. Se borró `cast.gd`. El mundo carga en 89 ms con ventana.
**Why**: El anillo de 84 OBJ parseados en runtime tardaba más de 10 s. El dedicado no debe cargar mallas.
**Where**: `scenes/world/{obj_mesh,body_library,body_visual,map_props}.gd`, `scenes/world/props/`, `tools/bake_bodies.gd`, `debug/body_gallery.tscn`, `agent/out/f17_dev.png`, `agent/out/f17_world.png`
**Learned**: El OBJ de sacengine sale en (x, z, −y), así que el horneado invierte z y el frente queda en +Z, igual que en sacengine. `REST_FACING` pasó a (0, 0, 1). Hay 16 cuerpos acostados (Trogg, campesinos, Ragman y otros) que se paran con +90° en X; el giro va en `upright_fix`. Cada WIDG y cada MRMM tiene su `M000` y su paleta en su carpeta del WAD; el exportador tomaba la primera y por eso las plantas salían negras. De MRMM solo se dibuja el LOD más alto. La V de WIDG es −v. El altar es grande, de unos 60 m con los pilares a ±20, y va en las posiciones del mapa: slot 0 en (1500, 1570) y slot 1 en (1040, 980). El manantial de Persephone es `pcfn`, no `mana`. Re-hornear: `export_persephone.py`, después `export_bodies.py`, después `bake_bodies.gd`. Desde F89, después `export_stats.py` (clips) correr `tools/bake_clips.gd` (16 633 cuadros, ~163 s, 942 MB, incremental; `-- --force` si cambia `obj_mesh.gd`). Sin hornear, el juego cae a armar el OBJ en runtime (lento pero correcto).
**Fix playtest**: Los WIDG se duplican con la winding opuesta y llevan cull back, como `loadWIDG`. Con `CULL_DISABLED`, Godot invierte la normal en la cara trasera y las rocas PCW5/PCW6 salían negras. Los widgets de suelo (≥70 % del área horizontal: PCF2, PCF3, PCW5, PCW6, PCW8) usan normales suaves por lado; las tarjetas siguen con normales hacia arriba. Los SAXS tienen registros por limb en 0x58 (6 bytes: bit 0 de flags más chroma key RGB); `loadSXTX` vuelve transparente ese color exacto, y en ddiz es negro en la parte 6. `obj_mesh.chroma_keys` lo aplica con alpha scissor. Si el raycast de una planta no encuentra suelo, prueba otra posición con su propia semilla, `hash([plant_seed, name])`.

### feature/f42-multiplayer-suite

**What**: Se agregó una suite de pruebas determinística para asegurar interacciones de unidades, batallas, victoria/derrota, edificios, destrucción y sincronización del estado del match.
**Why**: El usuario pidió una evidencia objetiva para multiplayer y validación del loop crítico con la data del juego real.
**Where**: `debug/multiplayer_suite.gd`, `debug/multiplayer_suite.tscn`, `FEATURES.md`
**Learned**: La suite debe ser data-driven y no depender de red real; con `GameData` + `UnitBody`/`StructureBody` comprobamos el mismo contrato que usa la partida online.

### feature/f18-camera

**What**: `scenes/world/world_camera.gd` en `%Camera` de `high_noon.tscn` (`set_follow`, `is_dragging`, `yaw`, `zoom`, `debug_pointer`). Bordes de 100 px: costados 36°/s, arriba/abajo zoom 0.5/s, rueda ±0.04, teclas = y − también. Vista libre con central o Ctrl+izquierdo. InputMap completo; se quitaron `summon` y `cast_rock` (Q = `creature_1`, C = `spell_3`). En 1 s en el borde izquierdo gira 36.3°.
**Why**: F18 del RFC-016. La cámara de F15 (arrastre derecho, borde de 36 px) no era la del original.
**Where**: `scenes/world/world_camera.gd`, `high_noon.gd`, `match_command.gd`, `walk_order.gd`, `project.godot`, `debug/camera_edges.{tscn,gd}`, `agent/flows/f18_camera.json`, `agent/out/f18_*.png`
**Learned**: Fórmulas de `dagonBackend.d` `focusCamera`/`positionCamera`: h = max(alto, 1.5); distancia `max(4.5, 0.6+2.32h)·(0.6+3.13z)`; altura `(1.75h−1.15)·(0.6+2.8z)` sobre el suelo bajo la cámara; foco `(1.75h−1.15) − 0.3(h−1)`, ×(0.75+2z) si z < 0.125; el ojo va 1 m más arriba. `slowRotationSpeed` 0.2π = 36°/s. Zoom: `pow(0.0001, dt)`. Vista libre ±0.25°/px con el signo del original (arrastrar a la derecha gira a la izquierda; abajo mira arriba). AgentKit no mueve el mouse del sistema: usar `debug_pointer`. `press` encola el evento: poner `wait` 0.1 antes de un `assert`. Con la cámara casi horizontal el centro de pantalla cae a ~240 m. Las teclas Q/C usan coincidencia exacta; `move_forward` todavía se activa con Shift+W (wizard_body no usa exacto).

### feature/f21-pick

**What**: Selección de mago y dios en `boot.tscn` (`scenes/ui/character_select`, `wizard_preview`, `pick_button`). «Jugar» guarda `SacrificeFlow.pick` = `{wizard, model, god}` e imprime `pick <model> <god>`; después aparecen Solo/Unirse.
**Why**: F21 del RFC-016. El mundo (F20) lee `SacrificeFlow.pick_for(slot)` / `slot_picks` y la señal `slot_picks_changed`.
**Where**: `scenes/ui/`, `scenes/flow/sacrifice_flow.gd`, `agent/flows/f21_pick.json`, `agent/out/f21_select.png`
**Learned**: En red se usa el canal genérico de MpKit (`send_custom` en `slot_assigned`, el dedicado valida `slot_for_peer` y hace `broadcast_custom("slot_picks")`); no hizo falta tocar el addon. La elección llega después de que el dedicado ya cargó el mundo: F20 tiene que escuchar `slot_picks_changed`. En solo la clave es `MpKit.local_slot()` (= 1), no 0. Los OBJ de magos vienen con Y arriba (el giro −90° en X es solo del campesino). Los flows que pasan por boot necesitan `click %Play` antes de `%Solo`/`%Join`. Probar el dedicado en otro puerto (`--mp-port=7790`) si el 7777 está ocupado.

### feature/f20-wizards

**What**: Hay un mago por slot de jugador. `%WizardSpawner`, que extiende `MpSlotSpawner`, crea `scenes/world/wizard/wizard_body.tscn` en `%Wizards` con los nombres `Wizard1` y `Wizard2`. El slot 1 va en `MapProps/Slot0` y el 2 en `Slot1`, a 30 m del altar hacia el `Fount`. Cada cuerpo tiene `Health`, `ManaPool` y `SoulPurse` (`scenes/world/components/`), y el HUD `scenes/ui/hud.tscn` va en `Hud/WizardHud`. `HighNoon.local_wizard()` y la señal `local_wizard_changed` son la API para cámara, HUD y `match_command`. `MatchBiome` sortea el bioma, que se envía por el canal `biome`. High Noon usa ACES con exposición 0.85.
**Why**: F20 del RFC-016, más la malla de F21 en el mundo y el sorteo de F32.
**Where**: `scenes/world/wizard/`, `scenes/world/components/`, `scenes/world/{high_noon,match_biome,match_command,walk_order}.gd`, `scenes/ui/hud.*`, `scenes/data/match_rules.gd` (`biome_god`, `biome_seed`), `debug/biome_pick.tscn`, `debug/rules/biome_pyro.tres`, `agent/flows/f20_*.json`
**Learned**: El `MultiplayerSynchronizer` va fijo en el `.tscn` del mago. Si lo agrega `MpReplicate` en diferido, `MpSpawner._hold` no lo ve al entrar el nodo y el spawn puede viajar a un cliente que sigue en boot. El estado de spawn se aplica antes de `_ready`, no en `child_entered_tree`; por eso el mundo detecta al mago local en su `ready`. El servidor toma `wizard_tag`, `model` y `god` de `pick_for(slot)`, escucha `slot_picks_changed` y los replica `on change`; el cliente no lee `slot_picks`. `Input.is_action_pressed(action, true)` evita que Shift+W camine; `action_press` de AgentKit cuenta como exacto. Los flows usan `%Wizards/Wizard1`. Las escenas debug con `subject` ahora reciben `world` y piden `local_wizard()`. Con `--mp-port=7791`, los dos clientes se pasan el puerto por la CLI de AgentKit. Los procesos en segundo plano tienen que lanzarse con `block_until_ms: 0`: un `&` dentro del mismo comando muere al terminar. Al desconectarse un peer, MpKit (`mp_spawner.gd:104 _on_peer_left`) loguea `!peers_info.has(p_peer)`: es del addon y no se tocó. En 1 de 4 corridas online, W de B no movió a su mago y no había trazas; las tres siguientes pasaron.

### feature/f22-mana

**What**: `scenes/world/mana_source.gd` (grupo `mana_source`, `kind` FOUNT/ALTAR/CUSTOM, `rate`, `radius`, `owner_slot`) va en `props/manafount.tscn` y `props/altar.tscn`. FOUNT y ALTAR leen `rules`. `map_props.gd` le pasa las reglas del mundo y le da al altar del marcador n el slot n + 1. El altar trae `owner_slot = 0` (nadie) hasta que lo reclaman. En el servidor (o en solo), cada tick de física la fuente le suma `rate*delta` a cada mago del grupo `wizard` que tenga a menos de `radius`. No hay regeneración pasiva. Medido: lejos 0/s, manantial 33.33/s, altar 16.67/s, los dos 50.00/s.
**Why**: F22 del RFC-016.
**Where**: `scenes/world/{mana_source,map_props}.gd`, `props/{manafount,altar}.tscn`, `components/mana_pool.gd` (`rules`, `start_mana` en `setup`), `wizard/wizard_spawner.gd`, `scenes/data/match_rules.gd` (`start_mana`), `debug/mana_fount.tscn`, `debug/mana_probe.gd`, `debug/rules/mana_fount.tres`, `agent/flows/f22_mana.json`
**Learned**: sacengine (`state.d:28539-28620`, `14409`) usa distancia 3D y radio 50, con el manantial a 1000/30 para cualquiera y el altar a 1000/60 para aliados. Solo cuenta la base del altar (`altarBaseTags`), y el maná se clampea al máximo. Un manantial con manalito encima queda inactivo (`putOnManafount`); eso es de Manalito y está fuera de alcance. sacengine no muestra ningún efecto al recibir maná. En High Noon el altar está a 121.7 m de su manantial, así que nunca se suman. Ahora el spawner mira al manantial desde donde aparece: con `toward_fount` = 241.7 el mago queda 120 m detrás del manantial, mirándolo. El HUD y el flow solo comparan texto: `mana_probe` escribe el nombre de la fuente que coincide con un margen de ±10 %.

### feature/f23-fx

**What**: `tools/export_particles.py` saca 8 atlas TXTR a `cache/look/fx/*.png` y `fx.json`. `ParticleType` (`data/fx/*.tres`, solo constantes y la clave), `SpriteParticles` (CPUParticles3D de una sola ráfaga que se libera sola) y el autoload `FxBus` (`play` local, `broadcast` por RPC desde el servidor).
**Why**: F23 del RFC-016. Lanzamiento, Heal, Speedup, roca y sangre con los sprites originales, sin assets en git.
**Where**: `tools/export_particles.py`, `scenes/fx/`, `data/fx/`, `debug/fx_gallery.tscn`, `agent/out/f23_dev.png`
**Learned**: `cstj`/`cstl` están en `charlie.wad` (`Bloo.WAD!/Jame|Pers.FLDR/tex.FLDR`); `glo2`, `spd6`, `rock`, `dirt`, `blud`, `spir` en `main.wad` (`MAIN.WAD!/bits.FLDR`). La paleta PALT tiene el mismo nombre y carpeta que el TXTR. El encabezado TXTR es de 36 bytes (`txtr.d`); `export_persephone.py` y `export_high_noon_look.py` leían desde el 44; ya están corregidos (ver F19). La energía multiplica el color en HDR: la galería usa ACES; High Noon tiene tonemap lineal y la satura. La caché lleva `.gdignore` y se lee con `Image.load_from_file`.

### feature/f19-sky

**What**: Cielo de mallas como en sacengine (`scenes/world/sky.tscn` + `sky.gd`): cilindro SKYT (radio 5120, alto 2560), anillo SKYB (4096 a −2560 → 5120 a 0) y plano de nubes SKY_ (10240 a 1792, UV 0–4, alfa `1 − r²`). Origen en y −511, sigue a la cámara en X/Z. Gira 2π/512 rad/s; las nubes corren `fract(t/64)·(1, −1)`. A los 16 s imprime `cielo angulo 0.196`.
**Why**: F19. El `shader_type sky` era estático, tenía corte vertical y estiraba las nubes en el cenit.
**Where**: `scenes/world/sky.gd`, `sky.tscn`, `sky_band.gdshader`, `sky_clouds.gdshader`, `high_noon.gd` (`_apply_sky`), `debug/sky_motion.tscn`, `debug/sky_probe.gd`, `tools/export_persephone.py`, `agent/out/f19_dev.png`
**Learned**: El corte venía del exportador: leía los píxeles TXTR desde el byte 44 y no desde el 36, así que la imagen quedaba corrida 8 px y las columnas 120–127 eran basura. Corregido y regenerado SKYT/SKYB/SKY_. SKYT tiene alfa explícito (arriba transparente) y se mezcla con el color de fondo del ENVI de High Noon (255, 180, 120). El espejo va horneado en la U de cada vértice (los pliegues caen justo en vértices), con `repeat_disable`. En `.tscn` el `Transform3D` va por filas.

### fix/holes-plants-sky

**What**: El mago ya no cae por los agujeros. Las plantas son los widgets originales de High Noon. Lo negro al mirar arriba es la cara de abajo del techo del altar (`alto`), no el cielo. La cámara expone `view_pitch_deg` (pitch absoluto, de −80 a 85).
**Why**: Playtest pt20. En sacengine, `moveOnGround` (sacmap.d:611-635) proyecta el paso sobre 8 direcciones y, si ninguna tiene suelo, no se mueve. Además `position` no se actualiza si la nueva no tiene suelo (state.d:14823-14833). Un mago que igual cae `gibDepth` = 25 m vuelve a 15 m de su altar (state.d:14800-14821, 10215-10224). Los widgets salen del NTTS (ntts.d:110-155, state.d:31346-31357): High Noon tiene JAW1–5, con 318 a 30–150 m del spawn del slot 1.
**Where**: `scenes/world/ground_guard.gd`, `terrain.gd` (`is_on_ground`, `ground_height`), `wizard/wizard_body.gd`, `map_props.gd`, `high_noon.tscn` (`widget_models`), `tools/export_high_noon_widgets.py` → `cache/high_noon_widgets.json`, `world_camera.gd`, `debug/hole_edge.tscn`, flows `fix_holes`, `fix_plants`, `f12_dedicated_walk`, harness `agent/harness/wizard_travel.gd`.
**Learned**: Recortar la velocidad antes de `move_and_slide` no alcanza: en el labio del cañón la gravedad desliza la cápsula hacia el agujero. Hace falta `GroundGuard.hold_on_ground(self, before)` después. Para las criaturas, en `unit_body.gd` `_physics_process`: `velocity = GroundGuard.keep_on_ground(self, velocity, delta)` antes de `move_and_slide()`, guardar `var before := global_position` antes y llamar `GroundGuard.hold_on_ground(self, before)` después; si `GroundGuard.has_fallen(self)`, la criatura muere (sacengine la revienta). Un harness en `agent/harness/` se monta en TODOS los flows: no dejar sondas ahí. El dedicado imprime `mago N arranca/para en x z`.

### polish/abilities-guard-spellbar

**What**: Ctrl+Q / Shift+B usa la habilidad de la selección desde `match_command` (`_use_ability`, modo `ability` si pide blanco). Las criaturas tienen `GroundGuard` y revientan sin alma si caen al vacío (`UnitBody._gib_fallen`). Rockform usa `Health.damage_factor` (0.05) y se borró el WORKAROUND del `type` duplicado. El libro es el del original: pestañas Criaturas/Hechizos/Estructuras y solo las casillas de la activa, con íconos ICON. Un hechizo armado sigue armado tras un clic rechazado.
**Why**: Pulido pedido después de F24–F29 y fix/holes.
**Where**: `scenes/world/{match_command,unit_body}.gd`, `components/health.gd`, `scenes/ui/spell_{book,slot}.{gd,tscn}`, `tools/export_icons.py` → `cache/look/{icons,hud}/`, `debug/ability_spit.gd`, flows `f24_cast`, `f28_rock`, `f29_spit`, `polish_spellbar`.
**Learned**: sacengine `renderSpellbook` (`renderer.d:4872-4975`) usa `hudScaling = alto/480`: pestañas 48×48 a 80 del borde inferior, páginas 32×32 abajo, marco `max(10, 2n)` segmentos de 16×8 y la tapa `spellbookFrame2` girada 90°; regiones en `renderer.d:4204-4213` (`tabs.TXTR`, `page.TXTR`, `fram.TXTR` de `huds.FLDR`, `spi2` de `bits.FLDR`). El ícono es `Cre8/Spel.icon` (bytes 12-16, ya en `creatures/spells/abilities.json` como `icon`) y el archivo es ese tag invertido `.ICON` bajo `MAIN.WAD!/icon.FLDR/**` (`nttData.d:248`); la paleta va en la misma carpeta. El libro lee la caché con `Image.load_from_file`. La habilidad de la selección es la de mayor `creaturePriority` (`state.d:30231`), que no exportamos: se toma la más nueva. Para que «sigue armado» funcione en red, `match_command` desarma recién cuando el `feedback` del Caster trae el nombre del hechizo. El dev de F31 editó `match_command.gd` a la vez (`wizard_can_cast`) y pisó dos líneas; releer antes de tocar. Con F31 el mago regenera vida: `f24_cast` ya no exige 500 exactos al empezar. No hay flow de una criatura cayendo a un agujero: la mira en `hole_edge` apunta al vacío («Sin suelo»).

### polish/final-pass

**What**: El fantasma oculta el libro, las otras sides no lo ven (`idleGhost`/`movingGhost`), no tira sombra, brilla sin luz y las escoltas lo siguen. `BodySeparation` empuja criaturas y magos antes de `move_and_slide`. La luz usa los colores del ENVI como lineales y el ambiente a π/14 del sol. Las plantas pasan por `fix_alpha_edges`. El suelo por bioma remapea baldosas por papel MAPG en vez de `atlas_filled`. El golpe cuerpo a cuerpo aplica `damage_factor`. Escenas `wrath_splash` y `ability_spit_melee`; flows pt24/pt28 con las rutas nuevas del libro; la casilla ya no muestra la tecla.
**Why**: Pasada final pedida tras F24–F32.
**Where**: `wizard/{ghost_form,wizard_body}.gd`, `scenes/ui/spell_{book,slot}.*`, `scenes/world/{body_separation,unit_body,theme_applier,god_theme,obj_mesh}.gd`, `units/{unit_orders,melee_attack}.gd`, `tools/export_tilesets.py`, `debug/{rock_hit.gd,wrath_splash.tscn,ability_spit.{gd,tscn},ability_spit_{melee,no_regen}.tscn}`, flows `final_separation`, `final_wrath_splash`, `final_spit_melee`, `pt24_*`, `pt28_*`, `pt29_sequence`, `f17_f14_wait_diag`, `f18_pt_world`.
**Learned**: dagon trata `ambientConstant`/`sunColor` como lineales (`renderer.d:1156, 1174-1176`) y Godot lee el `Color` de una luz como sRGB: pasar `linear_to_srgb()`. El ambiente suma `albedo·1` y el sol `albedo/π·energía` (`deferred.d:383, 403`). La roca y el `alto` se ven oscuros también en el original (textura de ~50/255). sacengine nunca cambia la tierra de un mapa (`levl.d:43-52`, `sacmap.d:192-195`): el remapeo es un WORKAROUND. `MGnn.MAPG` (`maps.d:55-76`, 60 bytes): los base traen la banda de altura en floats 0-3 y los de transición (byte 32 ≠ 0) traen dos grupos base y 12 baldosas en orden de marching squares. Los flows `text_*` leen solo `text`; el nombre del hechizo ahora está en `Slots/SpellN/Name`, después de `Tabs/SpellTab`. La IA no apunta a una roca (`isVisibleToAI`, `state.d:93`), así que el arnés fuerza los golpes contra ella. Toda energía shadeless de dagon (textura·energía) pasa a Godot con el mismo π/14 del ambiente: el fantasma ×10 sin convertir era blanco plano (`GhostForm.energy_scale` 0.224). Desde F28 Rock al suelo da «Blanco inválido» y el mago regenera desde F31: los flows viejos (`f17_f14_wait_diag`, `f18_pt_world`, `pt24_rock/ui/heal`) apuntan al Druid con `zoom_out` hasta «mira Druid» y no exigen vida exacta. `pt29_sequence` usa `ability_spit_no_regen.tscn`: fuera de las fuentes el Earthfling no recarga y un Druid con maná lleno se cura más rápido que el daño. Un dedicado lanzado con `&` dentro de una shell en segundo plano muere con ella: lanzarlo con `exec` y `block_until_ms: 0`.

### feature/f32-biomes

**What**: `tools/export_tilesets.py` escribe `cache/look/themes/<dios>/` (skyt, skyb, sky, undr, sun, edge, atlas y `theme.json`) para persephone, pyro, james, stratos y charnel. `GodTheme` (`scenes/world/god_theme.gd`, `data/themes/*.tres`) y `ThemeApplier` (`scenes/world/theme_applier.gd`) cambian el cielo, el fondo, el ambiente, el sol, la niebla y el atlas del terreno. `debug/biome_gallery.tscn` los recorre con Enter e imprime `bioma <dios>`.
**Why**: F32 del RFC-016, parte de datos y galería. Falta elegir al azar por partida y replicar.
**Where**: `tools/export_tilesets.py`, `scenes/world/{god_theme,theme_applier}.gd`, `sky.gd` (`set_textures`), `terrain.gd` (`tileset_dir`, `set_tileset_dir`), `agent/flows/f32_biomes.json`, `agent/out/f32_*.png`
**Learned**: Cada carpeta LAND (`prsc.LAND`, `PY_A.LAND`, `JA_A.LAND`, `ST_A.LAND`, `char.LAND`) trae su propio ENVI de 428 bytes (`envi.d`, colores en BGR) con los nombres del cielo, además de `LAND.PALT` y los MAPT; el ENVI del land de James coincide con el de High Noon (fondo 255, 180, 120). SKY_ se lee por nombre literal (el ENVI de Pyro apunta a `atad`, un smk). Los colores siguen `renderer.d setupEnvironment`: ambiente = `sunAmbientStrength * ambient/255`, sol = mezcla ambiente/sol por fuerza, niebla lineal `fogNearZ`–`fogFarZ` (en Godot, `FOG_MODE_DEPTH`). La dirección del sol del ENVI es casi horizontal en varios dioses: queda en `theme.json` y no se aplica. Los índices de baldosa de High Noon son del atlas de James: faltan 33 MAPT en Persephone, 25 en Pyro, 29 en Stratos y 16 en Charnel; el exportador rellenaba cada uno con el índice presente más cercano (`atlas_filled`), lo que ponía agua azul en Persephone; desde polish/final-pass se remapea por papel MAPG (`atlas_remap`). Cómo conectarlo: el dedicado llama `ThemeApplier.pick_random(seed)` una vez por partida, replica `theme.god` (canal custom de MpKit, como `slot_picks`), y cada peer, incluido el dedicado si quiere los colores, llama `ThemeApplier.apply(ThemeApplier.theme_for(god), world)` después de `HighNoon._ready` (el cielo y el `WorldEnvironment` existen recién ahí). El dedicado no necesita texturas.

### feature/f27-orders

**What**: `Selection` (`scenes/world/selection.gd`, `%Selection`, señal `changed(units)`; API `click`, `select_rect`, `define_group`, `extend_group`, `select_group`, `add_summoned`, `can_select`) y `%SelectionBox` en el HUD. `Orders` (`scenes/world/orders.gd`, `%Orders`, `request(units, command, point, target, facing)` / RPC `submit_order`) arma la formación en línea. Cada criatura lleva el hijo `Orders` (`units/unit_orders.gd`, `give/clear`, comandos MOVE/ATTACK/GUARD/GUARD_AREA/ADVANCE/RETREAT). `UnitBody` suma `ordered`, `idle_aggro` (debug: quieta sin orden), `engage`, `halt`, `is_foe` y `closest_foe(center)`; se quitó `request_walk`/`submit_walk` de la unidad. `UnitHealthBar.set_selected`. `Hud.show_selection`. `match_command.gd` reescrito: rectángulo, clic derecho por blanco, Ctrl+R/Ctrl+A armados, Ctrl+Espacio y grupos.
**Why**: F27 del RFC-016.
**Where**: `scenes/world/{selection,orders,match_command,unit_body}.gd`, `units/{unit_orders.gd,unit.tscn,unit_health_bar.gd}`, `high_noon.tscn`, `scenes/ui/hud.gd`, `debug/orders_group.{tscn,gd}`, `debug/rules/orders_group.tres`, `agent/flows/f27_orders.json`, `f25_summon.json`, `f13_playable.json`, `f14_controls.json`
**Learned**: sacengine: `canSelect` (`state.d:1134`) = mismo lado, no mago, vivo; `numCreaturesInGroup` 12; el rectángulo exige 3 px y no se dibuja con Ctrl (vista libre) (`dagonBackend.d:1173-1198`); doble clic = `selectAll` del tipo a 50 m (`state.d:29867`); las convocadas entran a la selección y a `groups[$-1]` (`state.d:29959`). Clic derecho (`dagonBackend.d:1215-1233`): enemigo ataca, propio escolta, suelo mueve. Retirada ordena a todo el lado, no a la selección (`state.d:29174`). Formación `getFormationOffsets` (`state.d:417`, separación `min(1.25·max(tamaño)+0.85, 10)`), girada por el facing de la cámara, con asignación golosa (`state.d:29205`). Un ataque a criatura re-elige a cada unidad el enemigo más cercano a su lugar (`attackDistance`, `state.d:13609`). `moveTo` ignora enemigos y para a 0.5 m (`state.d:12386`); escolta/guardia `patrolAround` a 50 m (`state.d:13003`, `sacobject.d:103`); retirada a radio+10 (`state.d:13608`). Las barras propias se dibujan solo seleccionadas (`renderer.d:3890`). En GDScript no nombrar métodos `add_to_group` ni `_set` en un Node: pisan a `Node`/`Object` y rompen el parseo en cascada. La acción `order_units` (teclado/AgentKit) apunta a la mira, que cae sobre la cabeza del mago: ese camino ignora al mago propio para seguir dando «Orden». AgentKit `drag` sirve para el rectángulo vacío; el rectángulo sobre las unidades del flow pasa por `check_tick` → `Selection.select_rect`. Con F28, Rock al suelo da «Blanco inválido»: f13/f14 ya no lanzan Rock, solo arman. Pendiente: xmenu radial, otras formaciones, encolar órdenes, almas/Manalith con clic derecho, red.

Implementado en esta iteración: `order_menu` ya no queda muerto; `scenes/world/match_command.gd` lo usa para abrir el menú de órdenes y rotar por `attack/guard/advance/guard_area/retreat`, respetando el flujo existente de selección y clic del RTS.

### feature/f29-abilities

**What**: Cada criatura tiene `ManaPool` (CRE8 `mana`), `RangedAttack` (genérico por `AbilityType`, modo `SHOOT`, señal `fired(target, damage, mana_before, mana_after)`) y `ActiveAbility` (Rockform `dihk`, modo `ROCK_FORM`). `UnitBody.request_ability(pos, foe)` / RPC `submit_ability` (validado por `owner_slot`) / `use_ability` en el servidor; `ability_status`, `enter_rock_form`, `is_rock_form`, `can_take_mana`. El proyectil `units/ranged_shot.gd` (look `ShotLook` en `data/shots/<tag>.tres`) se replica con `ShotSpawner` (`%Shots` en `high_noon.tscn`). `export_stats.py` agrega `ranged`, `ranged_attack`, `active_ability` y `shoot_animations` (`shoot_ticks`) a `creatures.json`. `ManaSource` alimenta también al grupo `unit`.
**Why**: F29 del RFC-016.
**Where**: `scenes/world/units/{ranged_attack,ranged_shot,shot_spawner,shot_look,active_ability}.gd`, `units/unit.tscn`, `unit_body.gd`, `mana_source.gd`, `high_noon.tscn`, `scenes/data/{creature_type,game_data}.gd`, `tools/export_stats.py`, `data/shots/ekba.tres`, `data/fx/spit_{rock,dirt,trail}.tres`, `debug/ability_spit.{tscn,gd}`, `agent/flows/f29_spit.json`
**Learned**: sacengine: `ranged` sale de nttData (`sacobject.d:424`) y define el índice de la activa (`abilities[1]` si dispara, si no `[0]`, 444). Alcance `max(0.8·range, range−30)` (`state.d:12468`); prefiere disparar salvo pegado dentro de la caja ×0.8 a ≤ 0.5 m (12849-12855). El maná se cobra por tick de disparo (costo/ticks) y el cooldown arranca tras el primer tiro (12774). El slot de animación de disparo está en `Cre8 + 176 + 22·4` y el evento del SKEL es `lrba`. Las criaturas recargan maná solo en fuentes (14409) y la vida regenera ×maná/máximo (14400). Earthfling: 200 de maná, Spit rock `ekba` cuesta 5, 120 de daño, 42 m/s, cooldown 1.5 s, gravedad 30 (10 en `dkba`). Druid tiene resistencia a distancia 0.9 → 108. Rockform cuesta 13. WORKAROUND: el ×0.05 de daño en roca (`state.d:8964`) va cambiando `type` por un duplicado con resistencias ×0.05, porque `health.gd` lee de `type` y no se podía tocar (borrado en polish: ahora es `Health.damage_factor`). El origen del tiro es aproximado (sin hueso de mano) y la predicción es velocidad·tiempo. `match_command.gd` no tiene hook de habilidad: F27 tiene que llamar a `request_ability`. f25_summon falla al final («2 unidades») por el `add_summoned` de la selección de F27, no por F29. No se probó en red.

### feature/f26-melee

**What**: `UnitBody` (`scenes/world/unit_body.gd`, `class_name` y ruta iguales) es la criatura: `creature_tag`, `owner_slot`, `mode` (IDLE/MOVE/CHASE/ATTACK/DEAD) y `swings`, más `units/unit.tscn` con `Tilt/Mesh`, `Health`, `MeleeAttack`, `Corpse`, `HealthBar` y el `MultiplayerSynchronizer` fijo. Señales: `died(tag, owner_slot, at)`, emitida en diferido para F30, y `struck(target, amount, hit_chance, roll)`. `tools/export_stats.py` agrega `melee_animations` (attack0..2: frames, framerate, attack_ticks) a `creatures.json`. `CreatureType.melee_animations`. `WizardType` suma `melee_evasion` y `melee_resistance`.
**Why**: F26 del RFC-016.
**Where**: `scenes/world/unit_body.gd`, `scenes/world/units/{unit.tscn,melee_attack.gd,corpse.gd,unit_health_bar.*}`, `scenes/data/{creature_type,wizard_type,game_data}.gd`, `tools/export_stats.py`, `debug/melee_duel.{tscn,gd}`, `agent/flows/f26_duel.json`
**Learned**: El Trogg (`eorc`) y el Druid (`humn`) usan las animaciones humanoides `HUa1/HUa2/HUa3` de `sxr1.WAD!/humn.FLDR`: `getSaxsAnim` elige por tag el archivo con el prefijo de ruta más largo. El slot de ataque está en `Cre8 + 176 + 11·4`. Por golpe: `facing·frames/(fps·ticks)·meleeStrength·0.4·meleeRes`. El golpe cae en el tick del SKEL y el swing dura `frames/30` s. sacengine no sangra al golpear (TODO en `state.d:8971`) y en una muerte normal no hay estallido; acá se pidió el gib (`state.d:8310`) al morir. El alcance es `defaultMeleeHitbox` con width = depth = 2·`reach` de `bodies.json`; la caja se escala ×0.8 para empezar el swing y sin escala para que el golpe acierte. Al Druid se le agranda ×1.3. El WORKAROUND de `UnitBody.new()` / `_ensure_parts` se borró en F25: ahora `UnitSpawner` instancia `unit.tscn`. La cámara de duelo es un `Camera3D` propio de la escena debug. No se probó en red.

### feature/f25-summon

**What**: Convocar va por el `Caster`: `request_summon(tag)` / RPC `submit_summon`, con `summon_status` (almas → maná → cooldown) y sin blanco. `Spellbook` es un solo libro de criaturas y hechizos ordenado por `spell_order`, con pestañas (`creature_count/creature_at/creature_cooldown` y la API vieja de hechizos); `apply_cooldown(tag)` cubre todo el libro. El componente `Summoner` del mago ubica y cobra. `UnitSpawner` (`units/unit_spawner.gd`, nodo en `high_noon.tscn`) instancia `unit.tscn` en `%Units` con nombres `Trogg1`, `Manahoar1`… `UnitBody` tiene el modo `SUMMONING` (al final del enum), `begin_summon`, `finish_summon`, `is_summoning` y la señal `summoned`. El HUD muestra `%Unit` «Trogg 960/960» y la barra los espacios `Creature1..N`, antes de `Spell1..N`. `SoulPurse.spend`.
**Why**: F25 del RFC-016.
**Where**: `scenes/world/spells/{caster,spellbook,summoner}.gd`, `wizard/wizard_body.tscn`, `units/unit_spawner.gd`, `unit_body.gd`, `match_command.gd`, `high_noon.tscn`, `components/soul_purse.gd`, `scenes/ui/{hud,spell_book,spell_slot}.*`, `debug/summon_unit.tscn`, `debug/rules/summon_unit.tres`, `agent/flows/f25_summon.json`, `f25_online_client.json`
**Learned**: sacengine (`state.d:9891`, `8423`, `15199`): la criatura se crea al empezar el lanzamiento, 6 m delante del mago con su mismo facing, translúcida (0.36); el maná se drena como en un hechizo; al terminar se cobran las almas (si faltan, se borra) y entra a la selección. No hay clic en el suelo. `manaCost = max(1, …)`, así que el Manahoar cuesta 1. El cooldown es por libro: Trogg 0.43 + 2 + 1.5 = 3.93 s, y el resto 2.93 s, así que Rock no se puede lanzar justo después de convocar. Con `spellOrder`, Q es Manahoar (117) y Shift+Q es Trogg (122): el criterio «Q convoca un Trogg» no coincide con el original. Los flows f13, f14, f18 y f17_diag usan `creature_2` y esperan el cooldown antes de Rock. Los voladores (Gargoyle, Shrike) dicen «No implementado» hasta que haya un cuerpo que vuele. En la cámara por defecto el Trogg queda detrás del mago.

### feature/f30-souls

**What**: `SoulSystem` (`scenes/world/souls/soul_system.{gd,tscn}`, un nodo en `high_noon.tscn` con `Souls`, `SoulSpawner` y `%SoulMessage`) y el alma `souls/soul.{gd,tscn}` (+ `soul.gdshader`). El servidor (o solo) crea el alma cuando cae el cadáver (`Corpse.settled`), la entrega al mago cercano y suelta una con P (`submit_drop` validado por slot). Señales `message(text)` y `soul_spawned(soul)`. `UnitBody.soul_anchor()`, `Corpse.dissolve()`. `MatchRules.enable_drop_soul`.
**Why**: F30 del RFC-016.
**Where**: `scenes/world/souls/`, `unit_body.gd`, `units/corpse.gd`, `match_rules.gd`, `high_noon.tscn`, `debug/soul_pickup.tscn`, `debug/rules/soul_pickup.tres`, `debug/melee_duel.gd`, `agent/flows/f30_{souls,duel_soul}.json`
**Learned**: sacengine (`state.d:1580-1630`, `8382`, `9501`, `14904-15010`): el alma nace con `Cre8.souls` al pasar de dying a dead, crece en 3 s y solo se junta en `normal`; distancia horizontal y vertical ≤ 5 contra el centro del mago; prioridad dueño > sin lado > enemigo y un empate la deja. El color es por espectador: sin lado (suelta y sin colector) o propia = azul, si no roja; una roja pegada a su cadáver no se junta. Al juntarla el cadáver se disuelve en 2.5 s. P suelta 1 en los pies del mago (`object.position`), no adelante, y con 0 no hace nada ni avisa: «Sin almas» lo pide FEATURES. No hay balanceo: el sprite va a 1.25·1.6 m sobre la posición. Con energía 20 (dagon) el alma sale blanca con ACES: se usa 2. Los magos están en la capa 1 del suelo: los rayos al suelo tienen que excluirlos o el alma queda sobre la cabeza. `SoulPurse.spend` ya lo había agregado F25. No se probó en red. Pendiente: Convert/Sac Doctor (`owner_slot` y `attached` quedan), fantasmas (F31: `_can_collect` solo mira la vida), `soulDisplacement` de `nttData` no se exporta, el sonido `rips`.

### feature/f31-ghost

**What**: `GhostForm` (`scenes/world/wizard/ghost_form.gd`, nodo del mago, `stage` ALIVE/DYING/RISING/GHOST/UNGHOSTING/GONE replicado) y la regeneración del mago (`wizard_body._regenerate`). API del mago: `is_targetable`, `is_ghost`, `can_cast`, `can_take_mana`, `can_collect_souls`, `spellbook_visible`. `ManaPool.given(amount)`, `Health._can_be_damaged`, `Caster.wizard_can_cast` e `_interrupt`, `%GhostState` en el HUD. `SacrificeFlow` acepta `--world=` para jugar una escena debug en red.
**Why**: F31 del RFC-016.
**Where**: `scenes/world/wizard/{ghost_form.gd,wizard_body.gd,wizard_body.tscn,wizard_spawner.gd}`, `components/{health,mana_pool}.gd`, `spells/{caster,rock_projectile}.gd`, `units/{ranged_attack,ranged_shot}.gd`, `unit_body.gd`, `souls/soul_system.gd`, `match_command.gd`, `scenes/ui/hud.*`, `scenes/data/{wizard_type,game_data}.gd`, `tools/export_stats.py`, `scenes/flow/sacrifice_flow.gd`, `debug/wizard_ghost.tscn`, `debug/rules/wizard_ghost.tres`, `agent/flows/f31_{ghost,online_client}.json`
**Learned**: sacengine: `deadToGhost` pone el maná en 0 (`state.d:8067`); el fantasma recibe maná aunque esté lleno (`||isGhost`, 14409) y `giveMana` lo cura 4.2·cantidad antes del tope (8831), así que en el manantial son 140/s y 1500 tardan 10.7 s. Revive donde está, no en el altar ni en el manantial (13959). Duraciones = cuadros de `death0..2`/`corpseRise`/`float2Stance` (slots 19-21, 57, 60 de `Animations` en WIZD+176) / 30. Las otras sides no lo ven (`renderer.d:1412`); `isValidGuardTarget` sí acepta al fantasma, pero `unit_orders._alive` mira `Health.is_dead` y una escolta lo suelta mientras tiene vida 0. Un Druid estático en la escena debug se sincroniza bien en red si el dedicado y el cliente cargan la misma escena (`--world=`). Pendiente: ocultar el libro (`spellbookVisible`, `spell_book.gd` lo estaba editando otro), energía 10 del fantasma, partículas `ghost`/`ghostTransition`, animaciones de muerte reales, sombra del fantasma, `GhostKill`.

### fix/late-join-spawn

**What**: `MpSpawner` (kit, genérico) retiene en el servidor todos los `MultiplayerSynchronizer` del mundo, es decir del nodo bajo `/root` que contiene al spawner. Eso incluye los que se agregan después (`node_added`). A cada peer se los muestra recién con `client_world_ready` y se los oculta con `peer_left`. Con `gate_unsynced_spawns`, a un actor sin sincronizador se le agrega un `MpSpawnGate` vacío en `child_entered_tree`, en los dos lados. `UnitSpawner`, `ShotSpawner`, `SpellSpawner` y `SoulSpawner` ahora extienden `MpSpawner`. Ranged shot, rock y wrath crean su sync en `setup()`, antes de entrar al árbol. Un cadáver que llega con el join ya aparece tirado (`Corpse.lay_down(..., animate=false)`).
**Why**: Un `MultiplayerSpawner` común manda el spawn a un peer que todavía está en el boot. Eso daba «Node not found: HighNoon/UnitSpawner», «ID n not found in cache» y «Should have been consumed».
**Where**: `addons/mp_kit/mp_spawner.gd`, `units/{unit_spawner,shot_spawner,ranged_shot}.gd`, `spells/{spell_spawner,rock_projectile,wrath_strike}.gd`, `souls/soul_system.tscn`, `unit_body.gd`, `units/corpse.gd`, `debug/late_join.tscn`, `agent/flows/late_join_{a,b}.json`, `late_join_ghost_{a,b}.json`
**Learned**: El paquete de spawn lista los sincronizadores que el actor tiene al mandarse: si un sync se agrega en diferido, el que entra tarde se queda con IDs sin consumir. La visibilidad de spawn es un OR entre los syncs del nodo y un nodo sin syncs es visible para todos. Para probarlo: dedicado + A + B por pares. B arranca cuando A imprime su marcador, con `--world=res://debug/late_join.tscn` para el caso fantasma. El Druid de `late_join.tscn` está a 60 m: ve a 100 m y corre a 11 m/s. A 14 m mataba al mago antes de que A convocara. El «pick doble» del server no era un reenvío: A fallaba, salía (`peer_left`) y B tomaba el slot 1. Una guarda en `_store_pick` contra un pick idéntico se probó y se quitó: no arreglaba nada. El primer Q se perdía porque el flow esperaba `%Stats` con «Vida», y el placeholder del `hud.tscn` ya lo trae mientras el HUD está oculto, antes de que llegue el mago. `match_command._caster` era null, se mostraba «Sin mago» y no se mandaba nada (comportamiento correcto). Ahora la espera exige además `visible_in_tree` (el HUD se muestra en `bind`), con un solo Q y sin reintento.

### fix/camera-edge-pointer

**What**: El scroll de borde de `WorldCamera` usa el último puntero que el viewport recibió como evento (`_input`, `InputEventMouse.position`), no `get_viewport().get_mouse_position()`. `final_online_a/b` mantienen `zoom_out` 2.2 s apretado apenas carga el mundo.
**Why**: `final_online` fallaba 3 de 3 (B: Heal «Sin blanco»; A: el ping a 70 m y el mago deambulando), y no era por las paredes, el remapeo ni el spawn gate. `get_mouse_position()` lee el cursor real del SO: en las corridas que pasaban, el cursor físico estaba quieto en el borde de abajo de la ventana de Godot y alejaba la cámara hasta zoom 1. Los flows se habían ajustado con esa cámara, y la mira apunta al centro de la pantalla. Con el cursor en otra app, la cámara quedaba en 0.125 y la mira caía en otro lado.
**Where**: `scenes/world/world_camera.gd` (`_pointer`, `_edge_pointer`), `agent/flows/final_online_{a,b}.json`
**Learned**: `push_input` de AgentKit mueve el hover de la GUI pero no `get_mouse_position()`. Todo lo que dependa de la posición del puntero tiene que leerla de los eventos. Con zoom 1 el ping de A cae exacto donde caía antes (1506.791, 16.509, 1529.257). Los «click missed» ocasionales también son el cursor real moviéndose sobre las ventanas. Para diagnosticar la cámara alcanza con imprimir `has_focus`, `_mouse_inside`, `gui_get_hovered_control()` y el puntero.

### fix/persephone-tiles

**What**: El remapeo de baldosas de High Noon a otro dios (`export_tilesets.py`, `base_mapping`) busca un mapeo de grupos base de James que respete el orden de alturas. Entre todos, se queda con el que deja fundidas más celdas de transición del mapa: o la otra tierra tiene ese par, o los dos lados caen en el mismo grupo. Si empatan, elige las bandas más cercanas. Un grupo sin rol de altura (banda de ancho 0: `[0,0,0,0]`, o MG05 `[1,1,1,1]` de James) toma el destino del grupo con el que más limita en el mapa. Las paredes del vacío usan el `edge.png` del tema, con UV 0→1 por quad como `sacmap.d appendEdgeWall`. `theme.json` guarda `atlas_groups`.
**Why**: Con Persephone se veían cuadrados planos gris y gris azulado de unos 15 m. La banda más cercana sola mandaba la roca (MG03) y MG05 a MG00 de Persephone, que tiene una sola baldosa casi blanca (0000, que además es el relleno bajo el vacío). Persephone es una cadena 0-1-2-3-4-5, así que perdía 2118 celdas de transición. Las paredes tomaban la baldosa de la celda, estirada.
**Where**: `tools/export_tilesets.py`, `scenes/world/terrain.gd` (`_color_wall`), `sacrifice_ground.gdshader` (`edge`, `has_edge`, alfa 0 = pared), `debug/biome_gallery.gd` (`close_at`), `debug/biome_gallery_close.tscn`, `agent/flows/biome_close.json`, `agent/out/biome_{before,after}/`
**Learned**: Mapeos nuevos: Persephone {0:2, 1:1, 2:2, 3:1, 5:2}, Pyro {0:1, 1:3, 2:0, 3:3, 5:1}, Stratos {0:0, 1:1, 2:2, 3:1, 5:0}, Charnel {0:2, 1:1, 2:2, 3:1, 5:2}. Las costuras duras bajaron a 0 en todos (antes eran 2118, 1130, 121 y 1130): Pyro y Charnel también tenían cuadrados. James no cambia. El shader muestrea el lightmap con `VERTEX` del fragment, que en Godot 4 está en espacio de vista. Pasarlo a mundo (`MODEL_MATRIX`) sobreexpone a James con el `0.62 + light·1.6` actual: queda pendiente recalibrar contra dagon, no se tocó.

### feature/f24-spells

**What**: `Spellbook` (libro del dios ordenado por `spell_order`, cooldowns que cuentan en cada peer y el servidor empuja al dueño) y `Caster` (RPC `submit_cast` validado por `slot_for_peer`; orden de chequeo maná → blanco → alcance → cooldown, como `spellStatus`) en el mago. Speedup, Heal y Rock implementados (`speedup_effect`, `heal_effect`, `rock_projectile` + `SpellSpawner`); el resto dice «No implementado». Barra de hechizos en el HUD abajo a la izquierda (`scenes/ui/spell_book`, `spell_slot`). `MatchRules.start_health`.
**Why**: F24 del RFC-016.
**Where**: `scenes/world/spells/`, `scenes/ui/spell_{book,slot}.*`, `wizard/wizard_body.{gd,tscn}`, `wizard_spawner.gd`, `components/health.gd`, `match_command.gd`, `high_noon.{gd,tscn}`, `debug/cast_heal.tscn`, `debug/rules/cast_heal.tres`, `agent/flows/f24_cast.json`, `agent/flows/f24_online_client.json`
**Learned**: sacengine aplica el cooldown al empezar (`applyCooldown`): el lanzado espera casting + cooldown + 1.5 y los demás casting + 1.0 + 1.5; nunca acorta. El maná se drena por cuadro en `min(cuadros, ceil(costo·60/500))` cuadros. `Spellbook.addSpell` ordena por `spellOrder`, así que James queda X=Speedup, R=Rock, C=Heal (no Rock en C). Heal cura 240/s hasta llenar (no usa la duración 4.5 de `sacspell.d`); Speedup dura `duration·0.2+0.5` en magos. Rock: `floating = min(7, …)` envuelve también el warmup, así que vuela a 7 m los primeros 15 cuadros. La cámara rota con el mouse real en los bordes: la escena debug fija `debug_pointer`. Los flows viejos esperaban `%Slot` y `Units/Peasant1`; ahora esperan `%Stats` con «Vida» y `Units/Trogg1`. En red el dedicado regenera maná (F22), así que el flow online no compara 700 exacto.

### feature/f28-damage

**What**: `Health.damage_typed(amount, kind, from_slot)` aplica `amount·max(0, res)` limitado a la vida, sin daño a aliados, y emite `hurt(taken, kind, from_slot)`. `kind` puede ser `melee`, `direct_spell`, `splash_spell`, `direct_ranged` o `splash_ranged`, y la resistencia sale de `CreatureType`/`WizardType` (`<kind>_resistance`). Rock exige blanco vivo no aliado y sale del suelo durante el lanzamiento: nace enterrado 1 m a reach + 1.5, sube, sale con escombros y polvo, persigue al blanco y explota con 650 de daño directo y `rock`/`dirt`. Usa la malla `rock.MRMM`. Wrath (Persephone, `oalf`) vuela desde la mano a 0.5 m del suelo y explota en el blanco con 550 de daño de salpicadura. Al resto le hace `550·(1−d/5)` por distancia a la caja. En `debug/rock_hit.tscn`: Druid 800→150 y el Trogg imprime `dano Trogg 0 vida 960 (inmune)`.
**Why**: F28 del RFC-016.
**Where**: `components/health.gd`, `spells/{rock_projectile,wrath_strike,spell_spawner,caster}.gd`, `data/wizard_type.gd`, `game_data.gd`, `data/fx/{dirt_cast,rock_*,wrath_*}.tres`, `tools/export_{particles,persephone}.py`, `debug/rock_hit.{tscn,gd}`, `debug/cast_heal.tscn`, `agent/flows/f28_rock.json`, `f24_cast.json`
**Learned**: sacengine `dealDamage` (`state.d:8948-8972`) usa `splashSpellResistance` si el daño trae `DamageMod.splash`, si no `directSpellResistance`; `dealRawDamage` (`9001-9050`) hace `min(health, dmg)`. Las resistencias se cargan ×1e-3 (`sacobject.d:156-160`): el Trogg tiene 0 en CRE8, así que la inmunidad es de datos y no un caso especial. Los magos tienen 0.5. Rock tiene flags 8213, sin targetGround: `isApplicable` (`sacspell.d:43-65`) rechaza el suelo y da «Blanco inválido». Para sacar la roca: `export_persephone.py` exporta `rock` a `cache/look/persephone/models/rock/` y después hay que correr `bake_bodies.gd`. Si aparece «GroundGuard not declared», correr `--headless --import` una vez. El flow solo clica el centro de la ventana (1024×576); se apunta repitiendo `zoom_out`/`zoom_in` hasta que `%HitLog` dice «mira Druid». El Druid regenera 29.17/s. AgentKit monta **todo** `agent/harness/*.gd` en cada flow: un probe roto de otro agente rompe todos los flows.

### feature/f16-data

**What**: `tools/export_stats.py` decodifica CRE8, WIZD, SPEL y STRC de `spells.wad` a `cache/data/*.json`. El autoload `GameData` arma `CreatureType`, `SpellType`, `AbilityType` y `WizardType` en memoria, junto con los libros por dios.
**Why**: Las reglas del RFC-016 leen las estadísticas del instalador. No se commitean `.tres` con números originales.
**Where**: `tools/export_stats.py`, `scenes/data/*.gd`, `data/match_rules.tres`, `debug/data_book.tscn`, `project.godot`
**Learned**: SpellTag = nombre de archivo del WAD invertido = bytes crudos del registro (`ycro`, `kcor`). Las habilidades también usan esa forma (`ekba`). El modelo se guarda legible (`eorc`). Los WIZD se guardan como `cwa0` y llevan `spell_tag` `0awc`. Las habilidades son SPEL de `@ABI.SCAT`. Los nombres salen de `nttData.d` y el texto del juego de `lang_english.wad`, que dice «Speed up». Trogg: 960 de vida, 8.25 m/s, 1 alma. Rock: 300 de maná, alcance 125, 8 s. Los scripts usan `preload`, no `class_name`.

### feature/f15-persephone

**What**: WASD mueve a James. El mouse orbita la cámara. El cielo, las plantas y las estructuras son de Persephone. Hay 84 modelos de magos y criaturas en el anillo.
**Why**: El usuario pidió la cámara con el mouse, WASD en lugar de ESDF, y el look de Persephone, no el de James.
**Where**: `project.godot`, `scenes/world/high_noon.gd`, `scenes/world/sacrifice_sky.gdshader`, `scenes/world/cast.gd`, `cache/look/persephone/`, `cache/look/bodies/`, `agent/out/f15_sky.png`
**Learned**: SKYT y SKYB van en el cilindro; SKY_ es el plano de nubes. Repetir la textura 8 veces dejaba cortes. Una sola vuelta no. El botón derecho arrastrado gira la cámara; un clic corto sigue ordenando a la criatura. En 1 s con W, James recorre unos 10 m.

### feature/f14-controls

**What**: James se maneja en tercera persona con E/D/S/F (y las flechas). El clic derecho manda solo a la criatura seleccionada. Q convoca al Trogg y C lanza Rock; el clic izquierdo confirma el blanco o selecciona.
**Why**: El mago no es una unidad de RTS. Las teclas salen de `defaultHotkeys` en `hotkeys_.d`.
**Where**: `project.godot`, `scenes/world/wizard_body.gd`, `scenes/world/match_command.gd`, `scenes/world/wizard.gd`, `agent/out/f14_walk.png`
**Learned**: En 1 s con E, James pasa de (1275, 11.9, 1275) a (1280.3, 12.8, 1283.2), unos 10 m/s. El Trogg camina con la orden y James se queda. Las texturas son los `.SXTX` por `bodypart`. En el libro completo Q es Manahoar y Trogg es Shift+Q; este corte solo tiene Trogg, así que Q lo convoca. Rock es el tercer hechizo (C), después de Speedup (X) y Heal (R).

### feature/f12-net

**What**: F12 cerrado. El cliente Slot 1 manda order_move y el mago camina unos 7 m sobre el suelo. La Y pasa de 11.89 a 12.53.
**Why**: El dedicado simula el CharacterBody3D. El cliente no corre move_and_slide.
**Where**: `scenes/world/wizard_body.gd`, `agent/out/f12_despues.png`
**Learned**: El replicador se agrega en diferido. Si se engancha en el _ready del padre, Godot rechaza el add_child.

### feature/f10-walk

**What**: F10 cerrado. El clic guarda la meta y el mago avanza 5.25/49 por tick. En 1 s recorre unos 6.4 m de 12 y la Y se queda en 53.4.
**Why**: El salto de F9 no es caminar.
**Where**: `scenes/world/walk_order.gd`, `walk_step.tres`, `debug/walk_order.tscn`, `agent/out/f10_caminando.png`
**Learned**: Si el rayo cae a otro piso, se conserva la Y. Un tick no puede bajarlo de 53.4 a 10.6.

## 2026-10-08

F9 compara un dump y, en Godot, salta al mago a la posición final. Eso no es caminar. F10 quedó cerrado: una orden del jugador, un paso por tick, y al segundo sigue a mitad de camino.

### feature/f33-god-spells

**What**: Se implementaron Fireball (Pyro), Lightning (Stratos) e Insect Swarm (Charnel) como hechizos jugables del libro inicial del dios.
**Why**: Pendiente explícito del RFC-016 para cerrar el tercer hechizo por dios con paridad de comportamiento.
**Where**: `scenes/world/spells/{caster,spell_spawner,fireball_projectile,swarm_projectile}.gd`, `debug/cast_{pyro,stratos,charnel}.tscn`, `agent/flows/pt33_{fireball,lightning,swarm}.json`
**Learned**: En estos dioses el spell de daño va en slot 2 por `spellOrder` (R), no en slot 3 (C): `pups=124`, `brif=131`, `ntil=133`, `mrws=134`, `laeh=136`. Fireball/Swarm comparten pipeline guiado con splash; Lightning conviene resolverlo instantáneo para evitar falsos positivos de colisión.

### validation/pt33

**What**: Playtester ejecutado para Fireball/Lightning/Swarm y regresión de summons.
**Why**: Asegurar cierre de iteración con evidence real de AgentKit, no solo revisión de código.
**Where**: `agent/out/pt33_*`, flows `pt33_fireball`, `pt33_lightning`, `pt33_swarm`, `f25_summon`, `f25_flying_summon`
**Learned**: Los cinco flows cerraron con `AGENT_OK` y sin `AGENT_FAIL`. En esta máquina no existe `godot` en PATH; la validación se corre por `addons/agent_kit/cli.sh . flow --flow=...`, que sí resuelve el binario.

### feature/f37-structure-visibility

**What**: Robustez de estructuras y visibilidad en editor: fallback visible para modelos faltantes de estructura + warnings de configuración en `BodyVisual` y `ClipPosePlayer`.
**Why**: Se construía Manalith pero podía quedar invisible si faltaba el modelo por dios en `cache/baked`; además faltaban señales tempranas en el inspector.
**Where**: `scenes/world/structures/structure_body.gd`, `scenes/world/body_library.gd`, `scenes/world/body_visual.gd`, `scenes/world/components/clip_pose_player.gd`
**Learned**: El catálogo de modelos debe unir `bodies` y `props`; los fallos de wiring (`mesh_path`) hay que exponerlos en editor con `_get_configuration_warnings` para evitar errores silenciosos de runtime.

### feature/f38-convert-sac-doctor

**What**: Implementación base de Convert (`ccas`) con Sac Doctor autoritativo: aparece en altar, va al alma roja, la toma y vuelve para acreditar almas al jugador.
**Why**: Bloqueador central del loop de Sacrifice: robo poblacional de almas enemigas.
**Where**: `scenes/world/spells/caster.gd`, `scenes/world/match_command.gd`, `scenes/world/souls/{soul,soul_system,sac_doctor}.{gd,tscn}`
**Learned**: Para targetear almas con mouse hizo falta una hitbox dedicada (`Area3D` en layer 4) separada de unit/wizard/structure. El courier se replica limpio usando `MultiplayerSpawner` + `MultiplayerSynchronizer`, manteniendo simulación solo en servidor.

### feature/f39-desecrate-altar

**What**: Implementación base de Desecrate (`ucas`) con doctor ritual: sacrifica unidad aliada cercana al altar enemigo, doctor viaja/canta y destruye el altar al terminar.
**Why**: Avanzar el segundo bloqueador del loop central (condición de victoria por profanación).
**Where**: `scenes/world/desecration/{desecration_system,desecration_doctor}.{gd,tscn}`, `scenes/world/{map_props,high_noon,match_command}.gd`, `scenes/world/spells/caster.gd`, `scenes/world/high_noon.tscn`
**Learned**: Para cast sobre altar fue necesario marcar altares explícitamente (`group altar`, `owner_slot`) y resolver el target por raycast dedicado en command/caster. Mantener el ritual encapsulado en un sistema propio evita ensuciar input o netcode compartido. El cierre de partida mínimo quedó en `match_over` cuando el mago del lado sin altar llega a estado `GONE`.
## 2026-10-11 — F41 unit parity + Manahoar support
- La cache F37 de clips de malla ya no se limita a magos+Trogg: ahora exporta todas las criaturas convocables del libro activo (neutral + top 3 por dios).
- Se agregó auditoría `tools/audit_unit_parity.py` para corroborar paridad de clips por unidad contra `nttData.d` + `books.json` + `creatures.json` + `anim_mesh_clips_f37.json`.
- `Unit` ahora tiene `ManaSupport` reutilizable (`unit_mana_support.gd`) para la habilidad `hmba` del Manahoar, server-authoritative y configurable por `MatchRules`.
- `unit_parity_gallery` quedó source-driven por libro y con sonda de maná del Manahoar (`probe manahoar mana`).
- Pendiente: correr playtest visual con screenshots en un host que tenga binario de Godot disponible en PATH (en este entorno CLI local no existe `godot`).

### feature/f43-world-hygiene

**What**: `terrain.gd` ya no deja la malla ni el material del terreno en escenas guardadas; `high_noon.tscn` bajó de 5,2 MB a 9,5 KB.
**Why**: B1 de `reviews/AUDIT-2026-10-12.md`. RULES prohíbe commitear texturas y modelos originales y un `@tool` los embebía al guardar.
**Where**: `scenes/world/terrain.gd` (`_validate_property`), `scenes/world/high_noon.tscn`, `scenes/world/high_noon.gd`, `RULES.md`
**Learned**: Para un recurso que genera un `@tool`, quitarle `PROPERTY_USAGE_STORAGE` es más simple que limpiar en PRE_SAVE. El guardado del editor se prueba sin UI con `Godot --headless --editor -s script.gd` (instanciar con `GEN_EDIT_STATE_MAIN`, `pack`, `ResourceSaver.save`) y conviene correr el script viejo como control. Godot está en `/Applications/Godot.app`. `%Creature`, `wizard.gd` y `tick_order.gd` no son código muerto.
**Next**: Fase 1 de la auditoría (RFC-017, red que cierra la partida): plan del tech lead pendiente del OK del usuario.

### feature/f46-net-hygiene

**What**: `structure.tscn` replica `Health`; los cinco `submit_*` validan con `MpAuthority.accept_command` o con el nuevo `MpAuthority.command_slot`; `debug/multiplayer_suite` pasó a `debug/rules_suite` (`RULES SUITE PASS`); escena `debug/structure_siege.tscn`.
**Why**: RFC-017c. La vida de las estructuras no llegaba a los clientes, había cinco copias a mano de la validación y la suite prometía red sin abrir un peer.
**Where**: `scenes/world/structures/{structure.tscn,structure_body.gd}`, `addons/mp_kit/mp_authority.gd` (+README), `wizard_body.gd`, `unit_body.gd`, `spells/caster.gd`, `orders.gd`, `souls/soul_system.gd`, `debug/rules_suite.*`, `agent/flows/rules_suite_playtest.json`
**Learned**: El motor aplica el spawn state antes de `_ready`: un `_ready` que inicializa un valor replicado lo pisa en el cliente; va con guarda de servidor. `MpSpawner` agrega un `MpSpawnGate` en runtime a los actores sin sincronizador. Un cuerpo a cuerpo no daña un Manalith. Manalith: pestaña Estructuras + `spell_1`, 11,1 s de casteo, 800 de maná. Los flows de AgentKit necesitan ventana y fallan con `click missed` si la máquina está en uso. Los dedicados de prueba van con `--mp-port=` distinto de 7777.
**Next**: playtest de dos clientes de `structure_siege` (`rfc017c_siege_a/_b`) cuando la máquina esté libre; subir `command_slot` al kit.

### feature/f47-models-in-editor

**What**: `BodyCatalog` (`@tool`, estático) lee `cache/baked`; `BodyLibrary` es su fachada; `BodyVisual` se ve en el editor con `model` desplegable y sin guardar malla ni pose; los pilares del altar son `Node3D > Visual`. En el editor el terreno se muestra centrado sin guardar el desplazamiento.
**Why**: RFC-018a. El usuario pidió que el mapa y todo su contenido se vean y se editen en el editor para el technical artist. Los autoloads sin `@tool` son `Nil` en el editor.
**Where**: `scenes/world/{body_catalog,body_library,body_visual,terrain,sky}.gd`, `props/altar.tscn`, `components/clip_pose_player.gd`
**Learned**: Un `BodyVisual` nunca se coloca: la colocación va en un padre `Node3D`. Un `@tool` con `_physics_process` también corre en el editor. No llamar `reload` a un método estático de GDScript (`Script.reload` lo tapa). `node_paths=` sobre un `@export` de tipo `NodePath` lo deja vacío. En el editor la raíz está desplazada: para consultar el suelo, convertir con el terreno. El índice de git está atrasado: no sirve como «antes».
**Next**: 018b (inicios y 5 manantiales como nodos), después 017a.

### feature/f48-starts-and-founts

**What**: Altares y manantiales de High Noon son nodos de `high_noon.tscn` (`MapProps/Starts/Start1..2`, `MapProps/Founts/Fount*` ×5). Piezas: `PlayerStart` y `GroundSnap`.
**Why**: RFC-018b. Que el technical artist vea y mueva inicios y fuentes con el gizmo. El mapa original trae 5 manantiales y el port tenía 2.
**Where**: `scenes/world/props/player_start.{gd,tscn}`, `components/ground_snap.gd`, `props/manafount.tscn`, `high_noon.tscn`, `map_props.gd`, `wizard/wizard_spawner.gd`, `debug/hole_edge.tscn`
**Learned**: `terrain.ground_height` da la misma altura que el rayo viejo, sin esperar un frame, igual en dedicado y clientes. Una vista previa de editor dentro de una packed hay que vaciarla en `EDITOR_PRE_SAVE`. Un editor headless con `-s` restaura la última escena abierta: las búsquedas por grupo global ven dos mapas. El usuario edita la escena en el editor mientras corren los agentes: un cambio inesperado en un `.tscn` puede ser suyo; no revertir sin preguntar. Desecrate ya estaba roto antes: el altar sin script no guarda `owner_slot`.
**Next**: RFC-019 (fidelidad visual, pedido del usuario); decidir la fidelidad del ritual (`.studio/RESEARCH-doctors.md`) antes de 017a/017b; después 018c.

### feature/f53-body-poses

**What**: Los modelos SAXS se hornean desde el cuadro 0 de su idle; las correcciones a mano están en `data/bodies/pose_overrides.tres`; auditoría `tools/audit_body_pose.gd`; banco `debug/body_pose_bench.tscn`.
**Why**: RFC-019b. El usuario vio criaturas de costado y personajes flotando fuera de la cápsula: 26 de 31 modelos mal, 3 sin animar.
**Where**: `tools/{bake_bodies.gd,export_stats.py,audit_body_pose.gd}`, `scenes/world/{body_catalog,body_visual}.gd`, `scenes/data/body_pose_override*.gd`, `data/bodies/pose_overrides.tres`, `debug/{capsule_preview.gd,body_pose_bench.tscn,gallery_body.tscn,unit_parity_gallery.gd}`
**Learned**: El exportador de sacengine escala solo la z del desplazamiento del clip; el juego escala todo el vector por `zfactor/referenceHeight`. Los `class_name` nuevos piden `Godot --headless --import` antes de que `--script` los vea. Un clip puede traer un desplazamiento legítimo (Brainiac): va al `.tres`, no al exportador. `export_stats.py` y `bake_bodies.gd` completos tardan segundos. La cápsula y el alcance salen de `bodies.json` + el `.tres`, iguales en dedicado y clientes.
**Next**: RFC-020 (sacrificios fieles): 020a y 020b en paralelo; después 019a y 019c.

### session/2026-10-13-sacrificios-base

**What**: Cerrados con review y playtest: F57 (altar con estado, `MatchState`, `DefeatRule`, cartel), F58 (Sac Doctor: `doctor.tscn`, `DoctorBody` con `fsm_kit`, `Attackable`, `class_name Health`; corregido el modelo `sacd` acostado y ahora anima) y F62 (despacho de la pestaña Estructuras por `SpellAction`; `ManalithAction`).
**Why**: RFC-020a, 020b y RFC-021a. Base para Desecrate (020c), ritual (020d), Convert (020e), Guardian y Teleport (021b, 021c).
**Where**: `scenes/world/props/altar*.gd`, `ritual_site.gd`, `scenes/world/match/`, `scenes/ui/match_result.*`, `scenes/world/sacrifice/`, `scenes/world/attackable.gd`, `scenes/world/spells/actions/`, `tools/export_stats.py` (`GAME_ACTOR_CREATURES`), `.studio/RESEARCH-doctors.md`, `.studio/RESEARCH-victory.md`.
**Learned**: La victoria es por profanación: el ritual drena al mago sin tope de rondas hasta matarlo y esa muerte destruye el altar (ReadMe 7.7 del original); matar a un doctor lo cancela y los cuerpo a cuerpo no pasan la barrera. Un playtest con ventana encontró lo que las sondas headless no ven (el doctor acostado). Un `@tool` que llama a un autoload en `_physics_process` tira errores en el editor: guarda `Engine.is_editor_hint()`. Los subagentes con trabajo en segundo plano se despiertan a reenviar su informe: detenerlos con TaskStop. `rules_suite` tarda minutos por `doctor_melee`: `--fixed-fps 600`. Rock es `spell_2` para James. Sin pathfinding los cuerpos se traban contra manantiales. Usuario: no saltear playtests; no asumir reglas, investigar con varias fuentes; subagentes en Sonnet y tech lead en Opus.
**Next**: 020c (Desecrate como `DesecrateAction`, vórtice, portador). Después 020d, 020e, 021b, 021c, 019a, 019c, 018c–e. Pendientes: voladoras con vista lateral; Brainiac como en el original; separar `doctor_melee` de la suite rápida; subir `command_slot` al kit; regla del fantasma (25 % de maná según el ReadMe).

### session/2026-10-13-desecrate-terreno-plan-grafico

**What**: Cerrados con review y playtest F59 (Desecrate hasta el portador frente al altar, con aro, cuerda y vórtice) y F52 (suelo suavizado y lightmap en coordenadas de mapa, con `light_base` / `light_gain` en el inspector). Planificado RFC-022 (mejora gráfica por capas) y RFC-021 (Guardian y Teleport; 021a hecho).
**Why**: Pedidos del usuario: botones de la pestaña Estructuras sin implementar; terreno facetado; «god rays, cielo más llamativo, iluminación más actual sin perder la esencia».
**Where**: `scenes/world/sacrifice/`, `scenes/world/units/captive.gd`, `scenes/fx/{portal_disc,tether,fx_atlas}.*`, `scenes/world/terrain.gd`, `sacrifice_ground.gdshader`, `rfcs/RFC-022-graphics-upgrade.md`, `.studio/RESEARCH-sacdoc-vfx.md`
**Learned**: Entendí mal un reporte del usuario («la criatura volando») y lo traté como bug de físicas: era el comportamiento correcto sin su efecto visual; ante un reporte ambiguo, preguntar qué se vio antes de mandar a corregir. Para lo visible, exigir al developer capturas con ventana y mirarlas antes de pasar a review. La energía 10–15 de sacengine quema a blanco en Godot. `VERTEX` en `fragment()` está en espacio de vista. Un `free()` sobre un nodo ya liberado aborta Godot y le muestra diálogos de crash al usuario: en pruebas usar `is_instance_valid`. No más de dos subagentes a la vez: la sesión chocó cuatro veces con el límite de uso. Decisiones de RFC-022: intensidad media, haces de autor + volumétrica en alto, AgX, gradiente de color por dios; faltan referencias visuales del usuario.
**Next**: 020d (ritual de 4 doctores, drenaje sin tope de rondas, victoria por profanación; cancelar con tiradores o hechizos, no cuerpo a cuerpo), 020e, 021b, 021c, 019c, RFC-022, 018c–e. Pendientes: clips `thrash` para la criatura tomada; voladoras con vista lateral; Brainiac como en el original; `unit.tscn` embebe texturas al guardar desde el editor; subir `command_slot` al kit; separar `doctor_melee` de la suite rápida.

### session/2026-10-14-ritual-cerrado-plan-remaster

**What**: Cerrado F60 (ritual de profanación: victoria de punta a punta en red y cancelación por Druids y Rangers). Replanificado RFC-022 v2 como remaster por capas y escrito `VISUAL.md` con las cuatro referencias de `visual/refs/`.
**Why**: RFC-020d. El usuario pidió una estética mucho más ambiciosa (bloom, volumétrica, PBR, normales, AO, shaders propios).
**Where**: `debug/{desecrate_ritual,ritual_push,ritual_cancel}.tscn`, `rfcs/RFC-022-graphics-upgrade.md` (sección 17 con decisiones), `VISUAL.md`.
**Learned**: Las escenas de cancelación en solo necesitan un mago blanco fijo: sin él el ritual completa en la primera ronda y no prueba nada. Mover un `PlayerStart` puede dejar el punto de aparición sobre un pilar del altar y `_seat()` asienta al mago encima. Decisiones de RFC-022: Persephone como bioma de prueba, Charnel noche, Stratos altura, cielo como capas sobre el cilindro original, texturas 2K–4K con Git LFS (no instalado aún), rocas `.glb` CC0, 60 fps con presets.
**Next**: 020e (Convert), 021b, 021c, 019c, RFC-022 (022a…), 018c–e. Antes de 022c: instalar git-lfs con OK del usuario.
- 2026-10-14: cerrado F61 (Convert fiel, RFC-020e) con review y playtest en solo y en red. RFC-020 completo. El alma pasó de `Area3D` a `StaticBody3D` (capa 4) porque el raycast del puntero no ve áreas. Recurrente en capturas: doctores y bombeo ilegibles bajo la sombra de la losa → RFC-022 (luz de relleno). Siguiente: 021b (Guardian).
- 2026-10-14: cerrado F63 (Guardian, 021b) con review, correcciones (haz con `grdn` real, cliente tardío) y playtest en solo y red. Siguiente: 021c (Teleport).
- 2026-10-14: cerrado F64 (Teleport, 021c). RFC-021 completo: la pestaña Estructuras tiene acción en todas sus casillas. Siguiente: 019c (VFX de manantiales) o su absorción en RFC-022.
- 2026-10-14: cerrado F54 (VFX de manantiales, RFC-019c). Chorro libre sobreexpuesto: calibrar en 022h/022l. Siguiente: RFC-022a (andamiaje y medición).
- 2026-10-14: cerrado F65 (022a). Metal no da tiempos de GPU: el banco estima con 9 vistas (±1 ms). Hallazgo de rendimiento: 60 cuerpos animados = 5 fps / 7,7 GB de video.
- 2026-10-14: cerrado F66 (rendimiento: 60 cuerpos de 5 a 120 fps, 7,6 GB a 330 MB). Causas: textura/material por superficie y malla por cuadro por instancia; BodySeparation con asignaciones por par. Siguiente: 022b (luz base).
- 2026-10-14: cerrado F67 (022b luz). La volumétrica con densidad por defecto (0,05) vela todo al subir el sol: fijarla por bioma. SSIL ~3,5 ms en alto. Siguiente: 022c (terreno PBR) — requiere git-lfs y descargas CC0 con OK del usuario.
- 2026-10-14: cerrado F68 (022c terreno PBR + terreno de doble cara). Material Maker por consola funciona (tools/mm_export.sh); sirve para variación macro y materiales sin escaneo, no reemplaza el detalle CC0. Siguiente: 022d (cielo: capas sobre el original, §17).
- 2026-10-14: cerrado F69 (022d cielo legacy fiel). Pendiente: banco de cielos (legacy/Swirl/volumétricas) con la máquina libre; pase de paleta de la pradera contra visual/refs/original/.
- 2026-10-14: cielo de Charnel: se dejó el original; iterar en otro corte (suavizado por grado no convenció, revertido). Pyro original usa cielo animado pyro_a.smk (pendiente).
- 2026-10-14: RFC-023 (animación esquelética) aprobado con decisiones; arranca después del pasto y del pase de paleta.
- 2026-10-16: MpKit 0.6.0 del kit (rc/v0.9.0) integrado en `addons/mp_kit`; se conservan `MpBoot.role()` y los roles de `mp_flow.gd`. `MpSpawner` ahora revela por handshake de cada spawner (`rpc_spawner_ready`), retiene también los nodos estáticos con sync (incluidos los que quedan al lado del mundo instanciado, como el Druid de `late_join.tscn`), sin errores `peers_info` al irse un peer; `MpReplicate` ya no crea su sync en runtime. Batería de red con dedicado verde: f54c, f63, f64, f78, pt46, pt57, pt59b, pt60, pt61, pt61b, pt63, pt73_net, pt80_net y late_join (servidores y clientes sin errores de red). `pt59b_net_b4.json`: B camina a posición antes del acarreo y espera la muerte del doctor (la Rock lo mata de un golpe). Pendiente de gameplay, no de red: `late_join_ghost` falla igual en solo — el Manahoar invocado bloquea al Druid (sin pathfinding) y el mago regenera, nunca hay fantasma.
