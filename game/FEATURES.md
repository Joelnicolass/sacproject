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
- **Pendiente.** Port web (rama `web-port`, RFC-039).

### Mundo y mapa
- **Hecho.** High Noon como `terrain.glb` editable, suelo PBR, aldeas, edificios, plantas y NPC como nodos de la escena, rotación en el transform, referencias tipadas (`MapBuilding.building`, `NpcSpawn.creature`). F4, F17, F48, F52, F68, F73, F172, F192-F196, F199, F240, F241.
- **Hecho.** Navegación con navmesh de Godot horneado y versionado por hash, sin grilla propia. F200-F204.
- **Hecho.** Biomas y temas de dioses. F32, F171.
- **Hecho.** RFC-044: `match.tscn` (sistemas, HUD, cámara) carga un mapa de `scenes/map/maps/<mapa>/` según su `MapDefinition` (`data/maps/`); `--map=<tag>`. Mapa de prueba `test_flat` sin tocar código. F260-F263.

### Cámara, órdenes y entrada
- **Hecho.** Cámara original, InputMap, selección sin tope, órdenes RTS, formaciones como Resources, menú radial en el botón derecho, marcador de orden del original. F15, F18, F27, F78, F216-F220.

### Magos, dioses y libros
- **Hecho.** Un mago por slot, selección de personaje, estadísticas del original, nivel del mago y libro por nivel, fantasma, aturdido y petrificado. F20, F21, F31, F92, F113-F115, F138.
- **Hecho.** Dioses y libros como Resources (`data/gods/`, `GodBook`). F250.

### Hechizos
- **Hecho.** Lanzador (maná, enfriamiento, tiempo de lanzamiento), daño, estructuras del libro, Guardian, Teleport, Manalith. Cada hechizo con procedimiento propio es una escena `SpellAction` más un `SpellType.tres`. F24, F28, F33, F34, F62-F64, F230.

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

### Determinismo y pruebas
- **Hecho.** `MatchClock` por tick, un dueño del azar, plazos en ticks de partida, banco de determinismo (`agent/run_determinism.sh quick|all`) y `rules_suite` sin ventana. F6-F11, F42, F144-F147, F187, F188.
- Las pruebas de cada dominio van en `debug/<dominio>/`; los flows de playtest en `agent/flows/`.

### Catálogo, herramientas y estructura
- **Hecho.** Catálogo en `.tres` por tipo (`data/catalog/`), sin JSON en runtime, validador de contenido (`debug/suite/catalog_cases.gd`). F173, F198, F224, F225.
- **Hecho.** Sin caché de instalación: todo es asset del repo (LFS). F167-F175.
- **Hecho.** Carpetas por dominio con README en cada una. F251.
- **Hecho.** Plugin «Sacrifice» del editor (Project > Tools: validar, re-hornear navmesh, hornear modelos que faltan), `bake_body_scenes` que no pisa lo editado, guías en `docs/HOWTO.md`. F270-F274.

## Won't (este corte)

Campaña, audio original, Steam, fork de Godot, fork de MpKit. El port web está planeado aparte (RFC-039).
