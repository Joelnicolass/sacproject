# CHANGE-REQUEST-001 — Modo single player contra IA, con poblados y NPC

Fecha: 2026-10-14 · Origen: pedido del usuario («el modo single player. Necesitamos que la IA juegue también») y adición del usuario («también los poblados: matar a los NPC es parte de la economía de almas»). Plan técnico: `docs/archive/rfcs/RFC-024-single-player-ai.md` + `docs/archive/rfcs/RFC-024-addendum-poblados.md`. Investigación de poblados (con REA, sacengine y web): `docs/archive/rfcs/research/poblados-npc.md` (en curso; donde difiera de la adenda, manda la investigación).

## 1. Resumen
Se suma al producto el modo **1 humano contra 1 mago controlado por IA** en High Noon (los 5 dioses), con la IA portada de la del original (`sacengine/source/bots/shiny.d`), más los **poblados y NPC del mapa** como fuente de almas. La IA es un jugador más: sin trampa, mismas reglas de maná y almas. Recomendación: **aceptar**, como cambio de **alcance** que se implementa por cortes (F71–F77), detrás del trabajo ya en curso del pasto.

## 2. Clasificación
| Cambio | Categoría | Tamaño | Prioridad |
|---|---|---|---|
| IA de mago y de criaturas (RFC-024) | New Feature | Large | Must have |
| Navegación (pathfinding), visión por bando, elección de blanco | New Feature / Technical Change (también cambia el movimiento del jugador) | Large | Must have |
| Poblados y NPC (26 Farmers, 6 Taurocks, 69 edificios neutrales, almas por Convert) | New Feature | Medium–Large | Must have (decisión del usuario) |
| Semilla y banco IA contra IA sin ventana | Technical Change | Medium | Must have |
| Dificultades Fácil/Normal/Difícil sin trampa | New Feature | Small | Should have |
| Botón «Contra la IA» y partida con dedicado (`--ai-slots`) | Feature Modification (modo solo y dedicado) | Medium | Must have |
| Cambio de «Fantasía» del PRD (de dos magos humanos a también contra IA) | Scope Change | Small | Must have |

## 3. Análisis de impacto
### 3.1 Chequeo de conflicto (antes que nada)
- **RULES.md** (no tiene IDs numerados; se cita por sección):
  - «Red»: «Online = dedicado… `play_solo()` no abre servidor». **No viola.** La IA corre en el proceso que simula (solo o dedicado); en solo no hay servidor.
  - «Red»: «Puntuación, textos y victoria viven fuera de `addons/mp_kit`». **No viola**, siempre que la IA también viva fuera (RFC-024 §4: sin RPC nuevos en el addon).
  - «Datos»: nada del original se commitea. **Riesgo, no violación**: posiciones de NPC y edificios salen de `cache/` (exportador nuevo); las casas usan el modelo del instalador en caché; si falta, placeholder.
  - «Datos»: «sacengine aporta los datos y los números… el movimiento usa el motor (`CharacterBody3D`, `move_and_slide`)». **Tensión a vigilar**: el pathfinding no reescribe un integrador (solo da waypoints a `begin_walk`), pero el reviewer debe confirmar que no hay un integrador paralelo.
  - «Idioma»: textos en español, nombres en inglés. Se respeta.
  - Arquitectura estándar: se respeta.
- **PRD, decisiones**:
  - «Sin fork de `addons/mp_kit`». **No viola**; el único glue es de juego (`SacrificeFlow`: `max_players = 1` y asiento IA en el dedicado con `--ai-slots=2`). Si resultara imposible sin tocar el addon, vuelve a esta lista como conflicto explícito.
  - «El peer 1 no es un jugador». **No viola**: el asiento IA no es un peer.
- **PRD, «Fuera del primer corte»**: Campaña, libro de hechizos completo, audio, export web, arte nuevo, modificar el motor. **La IA no estaba excluida ni incluida.** No revierte decisión. Se mantienen fuera: campaña y arte nuevo.
- **PRD, Fantasía**: «Dos magos en High Noon. Cada uno manda desde su cliente.» **Contradicción parcial**: pasa a «Dos magos… cada uno manda desde su cliente, o uno de ellos lo controla la IA». Es el Scope Change; la racional original (primer corte mínimo de red) sigue valiendo para el modo en red, que no cambia.
- Diferenciador de producto declarado: ninguno se contradice.

### 3.2 Componentes, RFCs y features afectados
- RFC-024 y adenda (nuevos). Reutiliza F22 (maná por fuente), F30 (almas), F31 (fantasma), F57/F59/F60 (derrota y profanación), F61 (Convert), F66 (cuerpos y separación).
- Se modifican: `high_noon.tscn`, `unit.tscn`, `wizard_body.tscn`, `unit_body.gd`, `orders.gd`, `match_rules.gd`, `sacrifice_flow.gd`, `boot.*`, `body_separation.gd`, `soul_system.gd`, `convert_action.gd`, `side_colors.gd`, `unit_spawner.gd`.
- Cascada: supuestos de dos jugadores `{1, 2}` en colores, HUD, `DefeatRule.kill_creatures`, selección y almas (los NPC usan slots 3 y 4); semillas en 4 fuentes de azar sin semilla.

### 3.3 Cronograma y recursos
Siete cortes (F71–F77). El más riesgoso es el pathfinding (F72). Un solo proceso de Godot de prueba a la vez (regla de seguridad del proyecto): los cortes que corren Godot esperan a que termine el pasto (F70) en curso.

### 3.4 Trabajo ya completado
- **Rendimiento (F66):** `BodySeparation` es O(N²) (~7 ms/tick con 60 cuerpos; ~16 ms estimados con ~92 al sumar 32 NPC). Se mitiga con grilla espacial en F73.
- **Movimiento:** el pathfinding cambia el movimiento del jugador (pregunta 3 aprobada: sí, como en sacengine). Regresión de flows obligatoria.
- **UX/coherencia:** sin cambios visibles hasta F77, salvo la aldea (F73).

## 4. Estrategia de implementación
Fase separada, por cortes, cada uno developer → reviewer (que repite los mismos comandos y compara el `digest`) → playtester con ventana → cierre en FEATURES.md:
1. F71 / 024a — semilla y banco IA contra IA (sin IA).
2. F72 / 024b — navegación, visión, elección de blanco.
3. F73 / 024b2 — poblados y NPC.
4. F74 / 024c — cerebro mínimo del mago (convoca, ataca, defiende).
5. F75 / 024d — economía, Manaliths, profanación.
6. F76 / 024e — dificultades y perfiles por dios.
7. F77 / 024f — partida completa contra la IA y prueba en el dedicado.
F70 queda reservada para el cierre del pasto (RFC-022e §12). Testing: banco reproducible con semilla, informe JSON con `digest`, libro de almas exacto, criterios numéricos por corte (RFC-024 §6 y adenda).

## 5. Decisiones del usuario que fijan el alcance (2026-10-14)
- Dificultades Fácil/Normal/Difícil **sin trampa**; Normal = números del original; Normal por defecto.
- **Un** rival IA (High Noon es de 2 jugadores); arquitectura lista para N.
- Pathfinding también para el jugador.
- IA en el dedicado solo como prueba de humo (un humano contra la IA).
- Almas de los habitantes: **se matan y se convierten con el Sac Doctor** (opción A, como sacengine); el alma queda roja y pegada al cadáver.
- La IA **no** caza aldeanos a propósito (opción A, como el original): sus criaturas los atacan al verlos y el mago convierte las almas.

## 6. Alternativas rechazadas y razones
- **IA nueva inventada** en lugar de portar `shiny.d`: rechazada. sacengine trae la IA del original con direcciones citadas; portar con fidelidad es verificable y respeta «el original manda».
- **Dificultad con bonificación de recursos** (trampa): rechazada; el original no hace trampa y el usuario eligió dificultades sin trampa.
- **Almas de NPC azules recogibles caminando** (opción B): rechazada por el usuario; es un desvío del original.
- **Reventar cadáveres con daño de área** (opción C): descartada por ahora; se reabre solo si REA confirma que el original lo hace.
- **`HuntTask` (la IA caza aldeanos a propósito)**: rechazada por el usuario; si los criterios de economía de F75 no alcanzan, vuelve como propuesta con evidencia.
- **IA solo local, sin dedicado**: rechazada como alcance; se pide la prueba de humo con `--ai-slots=2`.
- **Más de un rival (mapas de 3 y 4 jugadores)**: diferida a otro RFC.
- **Campaña, alianzas, modos `slaughter`/`domination`/`soul-harvest`, `DangerGrid`, experiencia**: fuera de alcance.

## 7. Ediciones por artefacto (todas deben ir en un solo commit)
- `PRD.md`: Fantasía; Fuera del primer corte (aclaración); nueva sección «Modo solo contra la IA»; Slice jugable (punto 5).
- `FEATURES.md`: F71–F77 agregadas como pendientes (IDs append-only; F70 sigue reservada para el pasto).
- `RULES.md`: nueva sección «IA» (jugador más, sin trampa, fuera de `mp_kit`, determinismo con semilla).
- `docs/archive/rfcs/RFC-024-single-player-ai.md` y `docs/archive/rfcs/RFC-024-addendum-poblados.md`: ya escritos; aprobados por el usuario con las decisiones de §5.
- `RFCS.md` y `TEST-STRATEGY.md`: **no existen** en este proyecto; el índice de RFCs es la carpeta `docs/archive/rfcs/` y la estrategia de pruebas vive dentro de cada RFC (§5–§6 de RFC-024). No se crean por este cambio.
- Código: ninguno todavía.

## 8. Stakeholders y comunicación
Único stakeholder: el usuario (dueño del proyecto). Comunicación: este archivo, el PRD actualizado y la adenda; cada corte se cierra con capturas y métricas.

## 9. Riesgos y mitigación
1. Tamaño de `shiny.d` (3442 líneas): cortes chicos; fidelidad de comportamiento, no de bits; suite de cuentas puras.
2. Pathfinding cambia el movimiento del jugador: regresión de flows (`f25`, `f27`, `pt60`, `pt64`).
3. Rendimiento con NPC (~92 cuerpos): grilla espacial, medición `sep_ms`.
4. Supuestos de dos jugadores con slots 3 y 4: el reviewer busca cada `owner_slot ==` y `% 8`.
5. Reglas del original sin verificar (flag de refugio, daño a cadáveres, FSM de los Farmers): comprobar con REA antes de fijar números; si no alcanza, quedan marcadas «según [S]».
6. Determinismo solo en la misma máquina: criterio de 024a degradable a «registro de eventos idéntico los primeros 2 min».
7. Modelos de las casas de James no horneados: tabla por bioma o placeholder con aviso.
8. Riesgo de no hacerlo: el juego solo se puede jugar con dos humanos conectados; sin partida solo, no hay forma de probar el juego completo de forma autónoma.

## 10. Decisión
**Aceptado** (usuario, 2026-10-14). Se implementa por cortes F71–F77 una vez termine el corte de pasto en curso (un solo Godot a la vez).
