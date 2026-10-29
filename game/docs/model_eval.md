# Evaluación de modelos: Opus 5.5 contra Sonnet 5.5 en el workflow de godot-studio

Pedido del usuario (2026-10-15): «evalúa las próximas iteraciones con opus contra las de sonnet: gasto de tokens (en cuota de sesión), eficiencia y resultados contrastados con el gasto por sesión».

**Plan acordado (2026-10-15):** primero se miden varias iteraciones con Opus. Sonnet se vuelve a medir recién cuando el usuario dé la orden; desde ese momento se registran las dos series con el mismo método. La línea de base de Sonnet de abajo queda como referencia histórica, no como medición comparable (no tiene cuota).

## Método

- **Cuota:** `get_usage` da el % usado de la ventana de 5 h y de la semanal (todos los modelos juntos; no hay desglose por modelo). Se toma una lectura al lanzar cada agente y otra al recibir su notificación. Delta = costo aproximado del agente. Si hay otro agente corriendo en paralelo, la lectura se marca «contaminada».
- **Tokens:** `subagent_tokens`, `tool_uses` y `duration_ms` de la notificación de cada agente (acumulativos si se lo retoma con SendMessage: se registra el delta de cada ronda).
- **Resultado:** rondas de corrección que necesitó el corte (review y playtest), bloqueantes encontrados por el reviewer, fallos en el playtest, y si los criterios del contrato pasaron a la primera.
- **Eficiencia:** cuota (pp de la ventana de 5 h) por corte cerrado, y tokens por corte cerrado, incluidas las correcciones.

Limitaciones: los cortes no son iguales en tamaño; la cuota es por cuenta (incluye esta sesión orquestadora); el % es entero (resolución de 1 pp).

## Línea de base: Sonnet 5.5 (datos de esta sesión, 2026-10-14/15)

Tokens = `subagent_tokens` final (acumulado con las correcciones). Rondas = cuántas veces se lo retomó para corregir.

| Corte | Rol | Tokens | Tools | Tiempo | Rondas de corrección | Resultado |
|---|---|---|---|---|---|---|
| 022e4c pasto | developer | 412k | 241 | 59 min | 0 (recortado) | review FAIL (4 bloqueantes, informe no correspondía a lo entregado) |
| 025a selección | developer | 232k | 92 | 25 min | 1 | review NEEDS WORK (1), playtest PASS |
| 025b panel | developer | 292k | 115 | 59 min | 2 | review NEEDS WORK (2), playtest PASS con 1 desvío |
| 025c iconos | developer | 296k | 118 | 23 min | 1 | review NEEDS WORK (1 bloqueante + 1 hueco), playtest PASS |
| 024a semilla | developer | 231k | 91 | 23 min | 1 | review PASS, playtest FAIL (simulación ligada al render) |
| 024b nav | developer | 484k | 165 | 64 min | 1 | review 1 bloqueante, playtest PASS |
| 024b2 NPC | developer | 647k | 228 | 120 min | 2 | review 2 bloqueantes, playtest 1 FAIL |
| 024c cerebro | developer | 706k | 201 | 69 min | 1 | review sin bloqueantes, playtest FAIL parcial (mago a la deriva) |
| reviews (8) | reviewer | 102k–205k (media ~145k) | 17–59 | 3–10 min | — | — |
| playtests (8) | playtester | 98k–222k (media ~140k) | 25–77 | 4–30 min | — | — |

Opus ya medido antes del cambio:

| Corte | Rol | Tokens | Tools | Tiempo | Rondas | Resultado |
|---|---|---|---|---|---|---|
| 022e4c pasto | developer (Opus) | 427k | 179 | 70 min | 1 | playtest: PASS 4/5, FAIL RTS (corregido en la ronda); ver informe |
| tech leads (3) | tech lead (Opus) | 141k–363k | 4–63 | 4–11 min | — | planes aprobados; el de pasto v1 tuvo una regla equivocada |

Cuota durante la línea de base: no registrada (se empieza a registrar desde aquí).

## Registro Opus (desde 2026-10-15)

| Corte | Rol | Cuota 5 h antes → después | Δ pp | Semanal antes → después | Tokens | Tools | Tiempo | Paralelo | Resultado |
|---|---|---|---|---|---|---|---|---|---|
| — | lectura inicial | 19 % | — | 17 % | — | — | — | 024d developer (Sonnet) corriendo | — |
| 024d | developer (Sonnet, fuera de la serie) | 19 % → reset de la ventana | — | 17 % → 21 % | 703k | 274 | 285 min | solo | criterios pasan salvo p99 del tick (3 ms); falta review y playtest |
| 024d | reviewer (Opus) | 8 % → 10 % | +2 | 21 % → 21 % | 228k | 70 | 13 min | solo | NEEDS WORK: encontró un bloqueante real (25–152 SCRIPT ERROR por partida) que el developer Sonnet no reportó; re-corrió 30 min ×3, citas de shiny.d verificadas |
| 024d | developer correcciones (Opus) | 10 % → 19 % | +9 | 21 % → 22 % | 278k | 122 | 75 min | solo (la sesión del kit pudo correr Godot) | B1 cerrado (0 errores), p99 3,1 → 1,43 ms, nits; 4/5 victorias (s1 trabada por un bug previo de NavGrid que diagnosticó); encontró y midió además el encierro del mago humano con escolta |
| 024d | developer 2.ª ronda (Opus, mismo agente) | 19 % → 47 % | +28 (contaminada) | 22 % → 26 % | +115k (394k acumulado) | +79 | 111 min | tech lead Opus (RFC-026) y la sesión aparte de MpKit corriendo a la vez | prioridad de paso del mago, quitó `_check_jam`, 5/5 victorias, escort_jam 6/6; descubrió que el bug de la esquina era la escolta; 1 criterio menor no cumple (farmer_in_sight 57 s) |

## Conclusión

Se completa al cerrar F75–F77 y la opción de tamaño del HUD.
