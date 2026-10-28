# Features

Fan game de Sacrifice. Godot 4.7, arquitectura estándar por dominios (`scenes/<dominio>/`), multijugador online con servidor dedicado.

Esta página es el **estado actual por área**. El registro completo, una entrada por feature con su criterio y lo que se midió, está en [`docs/CHANGELOG-features.md`](docs/CHANGELOG-features.md): buscá ahí por id (`### F208`). Cada corte de cada RFC (`rfcs/RFC-NNN-*.md`) cita sus ids. Cómo agregar contenido: [`docs/HOWTO.md`](docs/HOWTO.md).

Estados: **Hecho** (cerrado y probado), **Parcial** (anda, con deuda anotada), **Pendiente**.

## Must

| Feature | Estado | Ids |
|---|---|---|
| Servidor dedicado (`--dedicated`, sin slot de jugador) | Hecho | F1, F12, F46 |
| Unirse por IP / por sala | Hecho | F2, F181-F183 |
| Jugar solo (sin abrir puerto) | Hecho | F3 |

## Should y núcleo de juego, por área

### Red y salas
- **Hecho.** Servidor dedicado con admisión por ticket, servidor de salas, lobby con cuenta regresiva y vuelta a la sala, reconexión y límites, transporte WebSocket opcional, servidor local. F178-F185, F190, F191.
- Lo genérico vive en `addons/mp_kit`; el glue de Sacrifice en `scenes/net/`. RFC-034.
- **RFC-068.** Puerta de arranque (`MpMatchGate`) en todos los caminos de red (host LAN, sala, «Servidor local», dedicado a mano): la partida espera pausada a que carguen sus asientos y arranca en el tick 0; después nadie entra de cero, solo vuelve un asiento caído dentro de la gracia, al mismo slot y con el mismo mago; los demás reciben un motivo (`match_started`, `grace_over`, `full`). Prueba: `agent/runs/run_068_gate.sh`. F392.
- **Pendiente.** Port web (rama `web-port`, RFC-039).

### Modos y equipos (RFC-049)
- **Hecho.** La sala elige el mapa: la opción `world` viaja en el ticket al dedicado y los clientes la reciben en el snapshot; Solo, «Contra la IA» y «Servidor local» también eligen mapa. F290 (049a; el id lo comparte con EF-25, ver el registro).
- **Hecho.** Modos como Resource (`data/modes/`: `1v1` por defecto, `2v2`, `ffa3`, `ffa4`), equipos en la simulación (`SideRelations`), victoria del último equipo en pie (`winner_slots`). F291.
- **Hecho.** Reglas entre aliados por postura: fuego amigo, almas, profanar solo altares enemigos, manahoar con manalitos aliados, visión aliada (`MatchRules.allied_vision`). F292.
- **Hecho.** Mapa de prueba `test_flat4` (4 asientos), validador de inicios contra modos y banco `s2v2_flat4` / `sffa4_flat4`. F293.
- **Hecho.** `max_players` por modo, `--ai-slots` con varios slots, «Contra la IA» llena con IA los demás asientos. F294.
- **Hecho.** Sala con asientos por modo, anfitrión y asientos IA (kit genérico, ticket v2, abandono por equipo). F295.
- **Hecho.** 2v2 de punta a punta por la sala (`run_049g.sh`: cuatro humanos, y dos humanos más dos IA). F296.
- **Hecho.** Pantallas: selector de modo (boot, sala, servidor local), asientos por equipo con «Agregar IA» / «Quitar IA», servidor local con un código por asiento, banner con la línea del equipo. F297.
- **Pendiente playtest.** Cierre: playtest con ventana de una sala 2v2 y `all --no-window`. Guías en `docs/HOWTO.md` («Un mapa», «Un modo», «Jugar 2 contra 2»). F298.

### Mundo y mapa
- **Hecho.** High Noon como `terrain.glb` editable, suelo PBR, aldeas, edificios, plantas y NPC como nodos de la escena, rotación en el transform, referencias tipadas (`MapBuilding.building`, `NpcSpawn.creature`). F4, F17, F48, F52, F68, F73, F172, F192-F196, F199, F240, F241.
- **Hecho.** Navegación con navmesh de Godot horneado y versionado por hash, sin grilla propia. F200-F204.
- **Hecho.** Biomas y temas de dioses. F32, F171.
- **Hecho.** RFC-044: `match.tscn` (sistemas, HUD, cámara) carga un mapa de `scenes/map/maps/<mapa>/` según su `MapDefinition` (`data/maps/`); `--map=<tag>`. Mapa de prueba `test_flat` sin tocar código. F260-F263.
- **Hecho.** RFC-050: mapas del original por parámetro (`import_map.py --map=`, `scaffold_map.py`): `peaks`, `peasantville`, `roads` (chicos, 1v1) y `winter_wonder` (grande, 4 asientos para el 2v2). F320-F324.

### Cámara, órdenes y entrada
- **Hecho.** Cámara original, InputMap, selección sin tope, órdenes RTS, formaciones como Resources, menú radial en el botón derecho, marcador de orden del original. F15, F18, F27, F78, F216-F220.

### Magos, dioses y libros
- **Hecho.** Un mago por slot, selección de personaje, estadísticas del original, nivel del mago y libro por nivel, fantasma, aturdido y petrificado. F20, F21, F31, F92, F113-F115, F138.
- **Hecho.** Dioses y libros como Resources (`data/gods/`, `GodBook`). F250.

### Hechizos
- **Hecho.** Lanzador (maná, enfriamiento, tiempo de lanzamiento), daño, estructuras del libro, Guardian, Teleport, Manalith. Cada hechizo con procedimiento propio es una escena `SpellAction` más un `SpellType.tres`. F24, F28, F33, F34, F62-F64, F230.
- **RFC-056.** Caída de torres y edificios en todos los peers: estallido por parte (esferas, rocas, partículas, sonido), ruina, manantial libre en el mismo tick y la torre 1 s en pie antes de salir; cada reacción nueva es un nodo hijo que escucha `damaged`/`destroyed`. Prueba: `debug/structures/structure_break.tscn` (K), rules_suite `structure_break_cases`, `agent/flows/f391_structure_break.json`. F391.

### Criaturas y habilidades
- **Hecho.** Convocar, melé, muerte y cadáver, almas, bestiario completo con sus habilidades (aliento, disparos, congelar, veneno, aturdir, drenaje, empuje, pasivas, nubes de muerte…). F25, F26, F29, F30, F41, F112, F116-F166, F177, F205.
- Cada criatura es un `data/catalog/creatures/<tag>.tres`; las habilidades se componen con nodos y `.tres` en `data/abilities/`.

### Sacrificio (Sac Doctor, ritual, fin de partida)
- **Hecho.** Convert, Desecrate, altar con estado, ritual con rondas, drenaje y victoria, partida que cierra. F38, F39, F57-F61.

### IA
- **Hecho.** Semilla y banco IA contra IA, navegación y visión, mago IA, economía, captura y profanación, dificultades y perfiles por dios, partida completa contra la IA. F71-F77.

### HUD y minimapa
- **Hecho.** Panel de unidades seleccionadas, iconos, escala del HUD, menú de pausa, opciones (gráficos y jugabilidad), HUD e iconos como assets. F79, F80, F84, F141-F143, F170.
- **Hecho.** Minimapa: terreno horneado en vivo, marcadores, entrada y sigilo replicado, más fiel al original. F212-F215, F223.

### Cuerpos y animación
- **Hecho.** Modelos esqueletales del original, una escena por modelo (`scenes/bodies/models/`, `BodyModel`) con `AnimationTree` y eventos de clip; reposo con stance, cápsula en tierra y en vuelo, voladoras híbridas. F35, F36, F47, F53, F94, F134-F135, F176, F208.
- **Hecho.** `UnitBody` con una máquina de estados (FsmKit). F221.
- **Hecho.** Evasión de Godot en lugar del empuje propio. F207.

### FX y apariencia
- **Hecho.** Partículas de sprite con pool, luces de efectos, rayos, shader moderno, cielo, pasto en James/Stratos/Charnel (apagado provisorio en los presets). F23, F54, F65-F69, F95-F98, F108, F210.
- **Parcial.** Flora de los mapas (RFC-054, F380-F387). Hecho: la flora de cada mapa son nodos `FloraLayer` (una especie + un PNG de densidad en `scenes/map/maps/<mapa>/flora/`, RFC-055 055d-d3; antes `FloraMap`/`flora.res`) y `VegetationPatch` para grupos sueltos, con `FloraPlacement` determinista; `CellRing` compartido con el pasto; `FloraField` (`Look/Layers/Flora`) dibuja las plantas del original en los cinco mapas, también en el editor; High Noon y Peasantville con sus JAW1–5 reales y sin nodos `Plants`. Opciones → Gráficos → «Vegetación» la apaga. F380, F381, F382, F383, F385. Falta: el presupuesto (054e, con ventana).
- **Hecho (falta la pasada con ventana).** Sangre y golpe (RFC-060): todo cuerpo que pierde vida (criaturas y magos, cualquier daño) salpica rojo y deja manchas `blud` permanentes en el pool de «Cantidad de marcas»; el gib deja un charco; destello sutil de 0,12 s; Opciones → Jugabilidad → «Sangre» apaga todo. Solo presentación. `scenes/fx/blood/`, `debug/fx/blood_lab.tscn`. F390.
- **Hecho.** Relieve de los modelos (RFC-067): cada textura (`scenes/bodies/materials/*.tres`) lleva un normal map en `assets/surfaces/` (LFS), generado desde su albedo con el addon de editor `addons/surface_maps` (inspector «Relieve desde albedo», Project > Tools > «Generar relieve…», `tools/bake/bake_relief.gd`; recetas `default` y `foliage`); piedra y revelado lo conservan; el PNG es la fuente y se retoca. 821/822 (falta `pct6_M000_cutout`). Prueba: rules_suite `surface_refs_cases` y `surface_maps_cases`, `debug/look/surface_lab.tscn`. F393.

### Determinismo y pruebas
- **Hecho.** `MatchClock` por tick, un dueño del azar, plazos en ticks de partida. F6-F11, F42, F144-F147, F187, F188.
- Sin banco versionado (2026-10-27): `debug/` y `agent/` se borraron; las pruebas se regeneran con AgentKit cuando hacen falta.

### Catálogo, herramientas y estructura
- **Hecho.** Catálogo en `.tres` por tipo (`data/catalog/`), sin JSON en runtime. F173, F198, F224, F225.
- **Hecho.** Sin caché de instalación: todo es asset del repo (LFS). F167-F175.
- **Hecho.** Carpetas por dominio con README en cada una. F251.
- **Hecho.** Plugin «Sacrifice» del editor (Project > Tools: validar, re-hornear navmesh, hornear modelos que faltan), `bake_body_scenes` que no pisa lo editado, guías en `docs/HOWTO.md`. F270-F274.
- **Hecho.** Criaturas propias desde un `.glb` de Blender (`assets/custom/models/`): `tools/bake/new_creature.gd` (y la entrada «Nueva criatura desde modelo…» del plugin) saca roles, tiempos, golpe y tamaño del propio `.glb`, sin datos del original. F330-F334.

### Sonido (RFC-052)
- **Hecho.** Buses (Master > Music, SFX, Voice, Ambience), Opciones → Sonido y `SoundBus` con pools, límites y azar propio; nada en el dedicado ni en headless. F360.
- **Hecho.** Importador del audio del original (`tools/import/import_audio.py`, versionado por LFS) y sets horneados en `data/audio/`. F361.
- **Hecho.** Sonidos de criaturas y magos, FX, hechizos y edificios en bucle, voces del jugador y del consejero, música por dios con batalla y sacrificio, ambiente, clics de la UI y sacrificio. F362-F367.
- **Hecho.** Sonidos propios sin el original: `assets/custom/sounds/<tipo>/<tag>/<evento>_N.wav|ogg` → «Hornear sonidos» (y «Nueva criatura desde modelo…») → `data/audio/custom/`. F368.
- **Pendiente.** Cierre: el banco `all` igual; falta la partida de 5 min con ventana. F369.

## Won't (este corte)

Campaña, Steam, fork de Godot, fork de MpKit. El port web está planeado aparte (RFC-039).
