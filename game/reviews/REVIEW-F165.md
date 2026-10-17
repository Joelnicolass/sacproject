# Review F165 Divine Sight fiel (e45aca2 vs 7e75650)

**Veredicto: APPROVE** (sin bloqueantes; 3 nits).

## 1. Fidelidad (sacengine state.d 13102-13109, 25159-25214, 5058-5067)
PASS. Contrastado línea a línea con `divine_sight_eye.gd:_step` (95-135): spawn 2 m delante sobre el suelo (`divine_sight.gd`), escala `min(1,frame,lifetime-frame)/(44)`, subida frame<45 con la misma fórmula de altura, vuelo recto a `speed` mientras `travel*speed < 60*range` y frenado un tick después, fijación en el mismo tick sin perseguir (if/else idéntico), aceleración 3 por tick, topes de velocidad y de `dist*60`, altura de vuelo = tope del blanco + 2 m, blanco muerto -> `lost` para siempre con la velocidad conservada, empuje vertical bajo `land+flying`, vida 45+1800. `updateVision` cada 30 ticks tras la subida.
Divergencias declaradas: (1) `frontOfAIQueue` en sacengine solo limita la búsqueda a ciertos ticks; el ojo busca cada tick, así que puede fijar unos ticks antes (como mucho la longitud de la cola). No cambia nada jugable. (2) `is_valid_foe_of` es la definición única del port. (3) Sin línea de vista y refresco desde el primer tick: la grilla no la consume nadie (sacengine tampoco con niebla apagada). Ninguna cambia lo jugable.

## 2. Un dueño
PASS. `SideVision` es el único dueño de la grilla (`side_vision.gd` update_vision/queries). `spawn_scene` (`shot_spawner.gd` 30-42) solo duplica el patrón solo/servidor/cliente de `spawn_shot` (10 líneas, comparte `_serial` y `_make`); aceptable, no hay lógica de disparo duplicada. `RangedShot.land_height` estática; `ground_height` la delega, sin llamadores rotos (los otros `ground_height` del repo son de `terrain`).

## 3. Red y sim
PASS. `divine_sight_eye.gd:_ready` apaga `_physics_process` en clientes; solo `position`/`scale` por `MpReplicate`, declarados en `setup` (late join ok). `fire` exige `_has_authority()`. Sin RNG. Efecto en digests: solo el evento de f133 cambia a propósito; el digest se declara igual y quick PASS (no lo re-corrí, no se pidió Godot).

## 4. Harness
PASS. `f165_probe.gd` sale en `_physics_process` salvo en `res://debug/f165_divine_sight.tscn`; nada del juego lo lee. Lo único tocado fuera de agent/debug es `static var log_eye` (mismo patrón que `log_effects`).

## 5. Look
`f165_inflight.png`: el ojo es un punto azul de ~10 px, casi invisible. NO es aceptable como look final, sí como placeholder de este corte. El original usa `Bloo.WAD!/Pers.FLDR/tex_ZERO_.FLDR/scri.TXTR` (sacobject.d:3851-3865): hoja 4x4 de 16 cuadros, quad 2,5 x 2,25 m, 4 ticks por cuadro, shadeless, energía 3, sin escritura de profundidad. Existe en el WAD y es una TXTR más: el importador de 033d (`import_ui.py`, atlas FX) puede exportarla igual que las demás. Recomiendo: dejar F165 cerrado y abrir una tarea corta dentro de 033d "scri -> assets/original/fx/scri.png + animación 16 cuadros + energía 3" y cambiar el `glow` del `.tscn` (solo escena, sin tocar `.gd`). Mientras tanto subir el contraste del placeholder es opcional.

## Nits
- `side_vision.gd` `visible_cell_count`/`position_visible_to`/`position_explored_by`: único caller es la sonda (API de producto solo-flow). Aceptado porque la niebla está planeada (RFC-031/029); si ese RFC se descarta, borrar las consultas.
- `divine_sight_eye.gd` signal `ended` sin conectores; quitarla o usarla.
- `_closest_foe` recorre dos grupos cada tick de vuelo (sin lock): costo bajo, pero si el ojo se multiplica con más unidades conviene cachear.
