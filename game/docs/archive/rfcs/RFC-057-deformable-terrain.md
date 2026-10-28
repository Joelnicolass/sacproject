# RFC-057: terreno deformable (cierre de fase 2)

Estado: implementado (057a, 057b, 057c, 057d, 057z); falta 057e (flora viva), que espera a 066d. Plan: `rfcs/plans/057-deformable-terrain-plan.md` (aprobado el 2026-10-26).
Reemplaza al boceto de RFC-055 §12.5. La API es la de 063D (`Terrain` es el único escritor; `GroundField`, `TerrainLive`, `TerrainStamp`, `HoleCutter`, `TerrainNet`), y este RFC cierra los huecos que quedaban.

## Decisiones del usuario (2026-10-26)

1. **Bases a nivel (1b):** un sello de hechizo no mueve el suelo bajo una base (`GroundFootprint.pins_ground`, encendido por defecto): bajo la huella queda igual y en el anillo de vértices de alrededor se mueve a la mitad (`PinRules`). Es un desvío declarado: en el original el altar flota o queda enterrado. Bore nunca cava bajo una base, como el original.
2. **Nav (2b):** `NavService` rehornea con los agujeros (`holes_changed`) y con lo que queda (`kept`), no con cada `settled`: un Erupt entero no rehornea.
3. **Flora (3b):** las plantas siguen a los sellos largos (el monte de Volcano) y se replanifican cada 1 s solo en las celdas tocadas. Es el corte 057e y va después de 066d.
4. **Quake en el cliente (4a):** `QuakeWave` vive solo en el servidor; el cliente juega la copia `on_clients_only` que trae `quake_ring.tscn`. No hay red nueva: si se pierde el FX, a ese cliente le falta la onda, que es solo look.
5. **Inmovilizados:** también bajan con el suelo (una regla para todos los que están parados en tierra). Es un desvío declarado.
6. **Alma sobre un agujero:** cae a 1 m/s y desaparece 50 m bajo el último suelo que tuvo (`Soul.vanish_depth_m`), como el original.
7. **Nadie entra a mitad de partida:** la partida empieza cuando todos los asientos están en el mapa. El único que llega en el medio es un asiento que se cae y vuelve dentro de `rejoin_grace_s` (`MatchTicketGlue`, RFC-034 034g). Ese asiento recibe el snapshot del suelo y los sellos vivos con el reloj del servidor.

## 1. Qué deforma el suelo

El original suma lo permanente más los sellos vivos (Erupt, Quake) y aparte los agujeros. Ref: `Displacement`, state.d:28911-28934; agujeros `edgeChanges`, state.d:29027-29066.

| Poder | Tipo | En el port (API) |
|---|---|---|
| Erupt | Vivo: crece al lanzar y en la erupción; si lo cortan, se va en el acto | `erupt_zone.tscn`: `TerrainStamp` Mound, Rebound y Wave (`stamp`/`unstamp`) y `Cut` (`ZoneStampStop`) |
| Quake del Jabberocky y la vaca de Bovine Intervention | Vivo, 0,5 s: hundimiento de 2 m y onda de 1,5 m | `quake_ground.tscn` (Rebound + Wave) dentro de `quake_wave.tscn` (servidor) y una copia `on_clients_only` en `quake_ring.tscn` |
| Volcano | Monte vivo que baja al 25 % y queda, más un cráter de 25 m × 10 m | `volcano_zone.tscn`: Mound (vivo y después `keep`) y Crater (`keep`) → `keep_stamp` |
| Bombardment | Abolladura permanente de 15 m × 1,2 m | `meteor.tscn`: Dent `manual` + `keep`, `DropDent` → `leave_now()` → `keep_stamp` |
| Bore | Agujeros | `HoleCutter` → `cut_hole`/`fill_hole`; `HoleRules` decide qué vértice puede irse (borde, 11 m de una parte, base) |
| Tornado | No deforma | `tornado_drift` solo lee `height_at` |

Quien escucha: `StampCarry` (los cuerpos suben y bajan con el suelo, en el servidor), `TerrainCollision` (`changed`), la textura de deformación del look (`changed`), `NavService` (`holes_changed` + `kept`), la flora (`settled`), `HoleWalls` y `FallingChunk` (agujeros), el alma (`is_on_ground`).

## 2. Criterios de aceptación

1. **Quake deforma:** `height_at(c+d) − base` = la fórmula del original ±0,05 m para d ∈ {0, 10, 25, 40, 55} m y t ∈ {1, 5, 10, 20, 29} ticks; en el tick 31, |Δ| < 0,01 m; en el servidor `live_stamps` tiene 2 claves.
2. **Los cuerpos bajan con el suelo:** el Trogg a 5 m del Quake queda a ≤ 0,5 m del suelo en cada tick y no vuela ni da tumbos; a 5 m de una abolladura, a ≤ 0,05 m en el mismo tick; sobre un techo no se mueve (±0,01 m).
3. **Bases y Bore:** la espiral de Bore por el altar y por el manantial no deja agujeros bajo ninguna huella.
4. **Bases a nivel:** con un sello vivo o uno que queda sobre el altar, |`field().at`| ≤ 1e-4 bajo cada huella con `pins_ground` y ≤ la mitad del sello libre en el anillo.
5. **Borde y vacío:** Erupt en (5, 5) m y al borde del vacío de `edit_bed`: sin errores, 3 claves vivas, los vértices iguales a la fórmula ±1e-4, `GroundRay.surface_y` = `height_at` ±0,05 y |Δ| < 0,01 al terminar.
6. **Cortar Erupt:** con `cancel()` a los 0,5 s, al tick siguiente `field().at` = 0 exacto en el rect y `live_stamps` vacío.
7. **Alma sobre un agujero:** baja 1,00 ± 0,05 m/s sin tierra; el servidor la libera a `vanish_depth_m` bajo su último suelo; con tierra, sigue como hoy.
8. **Nav:** un Erupt entero no cambia `NavService.rebakes`; una abolladura suma 1; un agujero de Bore suma 1; `bore_nav` sigue en PASS.
9. **Red** (`terrain_late_join`, `TERRAIN NET PASS`):
   - `net_inflight`: un `kept` en vuelo antes del snapshot (que el servidor toma después del RPC) deja el mismo checksum y el mismo `rev`, llegue en el orden que llegue;
   - `net_rejoin_mid_volcano`: un asiento que vuelve a los 20 s de un Volcano queda con `ticks` a ≤ `resync_ticks` (8) del servidor, el mismo checksum, y |`at(centro)` del asiento − el del servidor| ≤ 0,05 m más el paso de redibujo de `Live` (`min_step_m`, 0,1 m), porque cada par redibuja un sello lento en su propio momento;
   - `net_quake_client`: el cliente ve las 2 claves del Quake mientras dura y el suelo del servidor no se toca.
10. **Rendimiento:** en `debug/perf/terrain_deform_bench.tscn` (con ventana), 5 Quakes a la vez suman ≤ 1 ms al tick promedio de la base y ningún frame pasa de 20 ms (`TERRAIN DEFORM BENCH PASS`).
11. **Flora viva (057e, pendiente):** durante la bajada del Volcano, las plantas de las celdas tocadas quedan a ≤ 0,5 m de `height_at` en cada replanificación de 1 s, y no hay replanificaciones fuera del rect.
12. **Lint:** ningún conteo sube.

## 3. Cómo se verifica

- `zone_run.tscn -- --only=terrain` (`--case=<caso>`): `quake_ground`, `carry_quake|carry_dent|carry_roof`, `base_hole|base_pin`, `rim_stamp|void_stamp|erupt_cancel|soul_hole|nav_trigger`, `net`, `net_inflight|net_rejoin_mid_volcano|net_quake_client`, y los de antes.
- `debug/net/terrain_late_join.tscn` (headless): los cuatro casos de red.
- `debug/perf/terrain_deform_bench.tscn` (ventana): criterio 10.
- F6 en `debug/spells/cast_terrain.tscn` (Bore y Erupt sobre el altar, cortar Erupt; Volcano con pyro) y en `debug/units/f132_quake_onhit.tscn`. Remote → `Terrain/Status` (`live_stamps`, `holes`, `rev`).

## 4. Fuera de alcance

Navegación por zonas (rehornear solo lo tocado), el hechizo «gota de agua» y modernizar Erupt, Volcano, Dent y Bombardment (al final de todo); edificios que siguen el relieve, el minimapa que se actualiza, el pasto, las cuevas, que la IA use los hechizos de terreno y `TestDisplacement`.
