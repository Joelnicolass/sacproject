# Review RFC-022e4c: laderas y pasto lejano (v2, §12)

Revisor: studio-reviewer, una pasada, solo lectura (no corrí Godot; solo había el editor del usuario, pid 9527, y otro developer en espera).
Evidencia: código en `scenes/world/look/grass/*`, `data/look/grass/types/meadow.tres`, `data/look/quality_*.tres`, banco en `agent/`, y `agent/out/rfc022e4/c_*_pyro/*` + `agent/out/rfc022e4c/*`. Miré las dos láminas, `c_new8_pyro/hill_game_A.png` y `c_base_pyro/rts_A.png`.

## Veredicto: FAIL (el corte no se puede cerrar ni mostrar al usuario todavía)

El mecanismo de código cumple casi todo el §12 (ver tabla). Lo que falla es (a) un defecto concreto de R2 que el RFC prohíbe, (b) un bug de horneado que deja `zone_data` en 64x64, (c) el riesgo RTS sin medir y muy probable, y (d) un reporte incompleto: las métricas entregadas no son las del estado entregado, y hay criterios que fallan y no se declararon.

## Veredicto por dimensión

| Dimensión | Veredicto |
|---|---|
| Pedido del usuario y §12 (R0, R1, borrados) | NEEDS WORK |
| Composición / inspector | PASS (nits) |
| Bugs y regresiones leyendo código | FAIL |
| Honestidad y validez de las métricas | FAIL |
| Producto (SQL/XSS/auth) | N/A: es un juego |
| MP / dedicado | PASS por lectura; criterios 9 y 10 sin correr |

## Cumplimiento del §12 (checklist del reviewer)

| Ítem | Estado | Evidencia |
|---|---|---|
| Densidad y ancho con el mismo `t(d)` | OK | `grass.gdshader:191` (`blend`), usado en 192 (densidad), 238 (alto lejano), 244 (ancho), 307 (punta) |
| Sin `pow(..,4)` ni `size_t`; piso constante | OK | `rg size_t` vacío; `far_ratio` constante desde `far_start_m` |
| Fundido solo por alto, color converge antes | OK | `:195-196`, `:240`, `color_fade_end` 0,7 < 1 |
| Sin ruido de pendiente; campos viejos borrados | OK | `rg slope_noise_deg\|slope_height_scale` limpio (los `slope_max_deg/soft_deg` que quedan son de `ground_layer.gd`, otro sistema); `grass_bake.gdshader:31-37` sin ruido, piso 0,55 |
| `_signature()` / `_zone_view()` actualizados | OK | `grass_field.gd:255-257, 317` |
| Ninguna rama por bioma | OK | `rg pyro\|persephone\|james\|stratos\|charnel` en grass/*.gd,*.gdshader: solo un comentario |
| `grass_density_scale` solo cercana | OK | `grass_field.gd:430-433`; doc en `look_quality.gd:57-59` |
| Invariante de anillos + `push_warning` | OK | `grass_field.gd:_check_rings`; lo razoné: `_tier_for` usa distancia de rect al mismo `_center` que el shader, histéresis solo hacia afuera, conteo `ceili(...)` por anillo; sin hallazgo |
| `far_coverage()` + aviso | OK en forma | `grass_type.gd:148`, `grass_field.gd:_get_configuration_warnings` (ver Obs. 2: no cuenta la densidad por capa) |
| `time_override` default -1, solo agent lo escribe | OK | `rg time_override`: solo `agent/fixtures/grass_bench.gd:124-130` escribe |
| R2 "sin factores por instancia" | **FAIL** | Bloqueante 1 |
| Un solo mecanismo para los 5 biomas | OK por código | `meadow.tres` compartido; Persephone/hotswap sin correr |
| Dedicado sin `GrassField` | OK por lectura | guarda `headless` en `_refresh`; criterio 9 no corrido |
| `agent/`: `rg "func agent_" scenes` | vacío (OK) | `src`/`glue` no existen en este proyecto; el `git diff --stat -- scenes` trae 49 archivos de otro trabajo (wizard), no sirve para atribuir |

## Bloqueantes

1. **R2 de alto agregado y con factores por instancia: `grass.gdshader:249-252`.** El §12.3 R2 define una sola regla (ancho `w(d)`, sin factores por instancia). El developer agregó `height_px = h * focal / dist` y un segundo `smoothstep(min_blade_px, full_blade_px, height_px)`. Ese `h` ya lleva `uneven` (por brizna y por mechón, `:232`), el crecimiento por rango (`:235`), la pendiente (`:242`) y el aplastado. A una distancia dada la regla NO actúa igual sobre todas: sobreviven las briznas altas y mueren las bajas justo en la franja donde `height_px` ronda 1-2 px (con focal 283 y 40-55 m a la cámara, un alto de 0,3-0,5 m da 1,5-3,5 px). Eso es exactamente "unas pocas puntas sueltas", y coincide con lo que el developer reporta: los componentes aislados que quedan (7,7/10k) están en el tramo 35-45 m. Es la hipótesis más probable de la causa residual de las briznas aisladas. Quitarlo o reemplazarlo por algo que dependa solo de `d`.

2. **R2 de ancho apaga el pasto cercano en la vista RTS, sin medir: `grass.gdshader:244-248` y `:348`.** Conté el costo real: medio = escala 0,67, vFOV 75, `focal_px` ~283. El ojo de `rts.tres` está a ~33 m de altura (distancia ~40 m al mago). Una brizna cercana (`w` = 0,16, `blend` 0) mide 0,16 x 283 / 40 = 1,13 px, y `smoothstep(1,2,1,13)` = 0,016: el alto se multiplica por ~0,02. Con el pasto cercano aprobado, en medio y RTS desaparece el pasto alrededor del mago. El RFC (§12.3 R2, «no actúa en medio ni en alto») calculó solo la brizna lejana de 0,54 m; el caso de la brizna cercana vista desde lejos quedó sin contar. El developer nombró el riesgo y no lo midió: el JSON final no tiene la vista `rts` (ni `hill_turn45/90`, ni sweep). Ver Bloqueante 4. Hay que correr `rts` en medio y bajo y, si confirma, bajar `min_blade_px`/`full_blade_px` (por ejemplo ~0,4/0,9) o hacer que R2 mire solo la franja lejana, siempre igual para todas las briznas de una distancia.

3. **`zone_data` queda en 64x64: `grass_field.gd:219` y `:299-303`.** `_ground_luminance(plain_image, zone_image)` hace `image.convert(...)` y `image.resize(...)` dentro de `for image in [ground, zone]`, que son referencias: encoge `zone_image` EN SITIO y luego la línea 231 crea `zone_data` con esa imagen de 64x64 (≈ 40 m por texel). Lo confirmé: `agent/out/rfc022e4/c_new8_pyro/zone_data.png` mide 64x64. Consecuencia: `density_by_layer` (sendero, claros, transición), `height_by_layer` y `hill` (mezcla de color de la ladera) se leen borrosos a 40 m. `slope_data` sí queda a 1024. No puedo probar si el defecto es previo a 4c (no hay commits), pero 4c depende de él: la ladera, su color y la densidad por capa pasan por esa textura, y el banco lo hereda (su máscara de zonas sin pasto sale de esta misma imagen de 64x64). Arreglo de una línea: `duplicate()` antes de achicar.

4. **Reporte incompleto y no del estado entregado (§12.10: "un reporte sin ... vuelve").**
   - `metrics_pyro_medium_final.json` es una copia exacta de `c_new7_pyro/metrics.json` (00:25:47). Después de esa corrida se corrió `c_new8` (00:26:30) y se **editó `meadow.tres` a las 00:26:58**; la copia "final" es de las 00:27:07. Ninguna corrida es del `.tres` entregado.
   - La corrida más reciente en disco, `c_new8_pyro`, falla el criterio 0 (A vs A2 en `hill_game`: 38 % de píxeles distintos, `mean_diff` 1,6 %), da aislados 30,9/10k en ladera y los mismos FAIL. Si el `.tres` se revirtió a los valores de c_new7, falta una corrida que lo pruebe; si no, la cifra buena no corresponde a lo entregado.
   - El final solo trae 3 de 6 vistas (`hill_game`, `hill_on`, `plain_p`). Faltan `hill_turn45`, `hill_turn90`, `rts`, sweep, bajo/alto, Persephone, dedicado, hotswap. El developer declaró algunos de estos, no `hill_turn45/90` ni `rts`.
   - **Fallan y no se declararon:** criterio 3 (hf no monótono, último anillo > 10 %, caída de cobertura), criterio 5 (banda oscura: en `hill_game` la ladera y la llanura tienen L_A hasta 10-12 % por debajo de L_B, límite 4 %; saltos de L_A hasta 26 % y 56 % entre anillos) y criterio 1 en `hill_on` (0,77-0,88 con huecos de 267-650 px, límite 64). El developer sí declaró el 2 (7,7/10k), el 1 de `hill_on` y el costo.
   - **Criterio 4 (llanura sin regresión) nunca se calculó** (`null`: no se pasó `--base`). Es justo la garantía de "no tocar lo aprobado cerca". Tampoco hay corrida de Persephone.
   - **El "PASS" del criterio 7 es vacío:** sin `--base` solo se listan prims. Calculado a mano contra `metrics_pyro_medium_baseline.json`: grass_prims `hill_game` 1.061.376 -> 1.228.008 (+15,7 %), `hill_on` 1.124.352 -> 1.173.699 (+4,4 %), `plain_p` 1.035.264 -> 1.135.113 (+9,6 %). Umbral +10 %: falla en `hill_game`. GPU no medida. Aceptar +15 % es la palanca 3 de §12.4, pero necesita medir `rfc022e4_perf_*` y decirle al usuario.
   - La línea de base misma no es válida por la regla del RFC: su criterio 0 falla en 4 de 6 vistas (`distinct_px` 0,04 % > 0,02 %). Una base que no pasa A/A2 no sirve para el criterio 4.

## Observaciones (no bloqueantes, pero para la próxima pasada)

1. **El criterio 2 falla de verdad y el developer lo redefinió.** El contrato pide `isolated_per_10k` <= 1,0 y da 7,7 en ladera (`hill_game`/`hill_on`). La métrica `visible_per_10k` (VISIBLE_DL = 16) la inventó el developer después; no está en el §12.6. Mirando la columna A de `hill_game` no veo puntas sueltas, así que la lectura visual sí podría pasar; pero eso lo decide el playtester con ventana, no un número nuevo. El divisor "~3 px por brizna" en `ring_table` (`grass_bench_metrics.py:190`) tampoco está en el contrato.
2. **`far_coverage()` ignora `density_by_layer`.** El piso 2,3 se calcula con densidad de capa 1,0, pero la ladera de Pyro cae en capas de 0,30-0,35 (`meadow.tres`/`grass_type.gd:51`): `frac_total` multiplica `zone_density`. Con 12 x 0,35 = 4,2/m² la cobertura lejana efectiva es ~1,3 (≈ 73 % de suelo cubierto). Eso explica por qué `hill_on` queda en 0,77-0,88 y con huecos, mientras `hill_game` (capa 0) da 0,98. El fix es un valor de `.tres` (subir `density_by_layer.z/w` o el aviso debería usar el mínimo no nulo), pero cambia la densidad cercana de capas aprobada: preguntar.
3. **La ladera se lee casi pelada.** Lámina `hill_on` (abajo = después): superficie lisa, textura de briznas casi nula incluso a 5-15 m; `hill_game` columna A: manto naranja alto en la llanura y ladera beige lisa a partir de ~20 m, con un salto de tono en la base. Las briznas existen (cobertura 0,98 medida por ΔL > 6) pero van del color del suelo, al 55 % de alto y con luz de suelo: visualmente es lo que el usuario rechazó en la v1 ("quiero que SÍ haya pasto"). Que el número pase no basta (§12.6: "falla si su PNG muestra otra cosa"). El playtester debe preguntarle al usuario si ese manto sutil es lo que quería.
4. **Fundido medido desde `field_center`, no desde la cámara** (§12.2.4). El banco mide anillos por distancia horizontal a la cámara (`grass_bench_metrics.py:107`) y por eso aparecen cobertura 0,17 -> 0,79 entre 50 y 55 m en `hill_game`, más allá del radio efectivo de 54,4 m: el eje del banco no es el eje del shader. Para el criterio 3 los anillos deberían ir por distancia a `field_center` (el bench puede escribirlo en `bench.json`). El criterio 6 (giro) no se corrió, así que el cambio de `field_center` al girar sigue sin verificar.
5. **Aparición por rango en todo el campo, no solo en la franja.** `grass.gdshader:235` sigue aplicando `smoothstep(0,0.5,(frac_total-rank)/frac_total)` a cualquier distancia; el `mix(uneven,1,fade)` de `:236` la apaga solo con `fade`. En 19-40 m la mitad de las briznas queda más baja que el resto: es variación de alto por rank, grano sutil que el §12.3 R0 quería evitar. Probablemente contribuye a los componentes aislados.
6. **Radio efectivo en medio baja de 70 a 54 m** (`quality_medium.tres` radio 64). Es la opción (a) recomendada de la pregunta abierta 1 (§12.11); no hay respuesta del usuario registrada. Decirlo en la entrega. Bajo 20 m y alto 74 m, igual.
7. **Magic numbers heredados en el shader** (no nuevos, no bloquean): `:307` (0,55 del ancho de punta lejano), `:334` (1,2 / 4,0 de `far_mass`), `:335-337` (14, 0,3), `:257` (1,5/5,0). Constantes en script que el RFC dejó en uniform/tipo: `FADE_END`, `FAR_START_FACTOR`, `TIER_BLEND` (`grass_field.gd:28-37`), `COVER_SHAPE`/`FAR_REFERENCE_OPENNESS`/`MIN_FAR_COVERAGE` (`grass_type.gd:139-143`). Están documentadas; no bloquean.
8. **Banco:** `_freeze()` fuerza upscaler bilinear en lugar de FSR2 del preset medio (documentado, razonable). La máscara se calcula en Python con el mapa de altura volcado (`height_r.f32`), no por geometría del juego como pedía §12.5: es equivalente en terreno, pero no ve altura de brizna ni el mesh real. Usa `scipy`, que el RFC no listaba. `grass_bench_metrics.py` mezcla en `ok["7"]` un vacío cuando falta `--base` (ver Bloq. 4).
9. **Criterio 0:** `c_new8` muestra que el banco puede ser no determinista (38 % de píxeles distintos en `hill_game` entre A y A2) sin que cambie nada visible en el código; conviene entender por qué antes de fiarse de otro número.

## Qué falla y qué es aceptable para el usuario

- **Bloquea mostrarle el corte:** Bloq. 1 y 2 (R2: puede apagar el RTS y deja sobrevivientes), Bloq. 3 (bug de horneado), Bloq. 4 (no sabemos si el estado entregado cumple). Además falta mirar RTS, giro 45/90 y Persephone, que son lo que el usuario pidió explícitamente (sin pop al girar, mecanismo único).
- **Aceptable si el playtester lo confirma con ventana:** aislados 7,7/10k si en el juego no se ven espinas (columna A de `hill_game` hoy no las muestra); +16 % de prims si el GPU en medio queda <= +0,15 ms y el usuario lo acepta; radio 54 m en medio si el usuario responde la pregunta 1 con (a).
- **Se puede arreglar con solo `.tres`:** `hill_on` < 0,85 y huecos (Obs. 2), `min_blade_px`/`full_blade_px` para el RTS. Pero Bloq. 1 y 3 son de código.

## ¿Se puede cerrar el RFC?

No. Una sola corrección (el orquestador puede pedirla): quitar el R2 de alto o hacerlo solo función de `d`, arreglar el `resize` en sitio de `zone_image`, repetir **una** corrida completa del banco en Pyro medio con el `.tres` entregado y con `--base` (incluyendo `hill_turn45/90`, `rts`, `plain_p` y sweep) más `rts` en bajo, y reportar todos los criterios, también los que fallan (3, 5, 4). Después, playtester con ventana. Los criterios 9 y 10 y Persephone siguen pendientes.
