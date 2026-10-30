# REVIEW F141 (031b): menú de pausa y Salir al menú

**Veredicto: PASS.** No hay bloqueantes. El revisor es de solo lectura; el orquestador guardó este informe el 2026-10-16.

Los criterios 1 a 6 tienen evidencia en `agent/out/pt141dev/`:
- **Pausa en solo:** la criatura se mueve 0 m y los ticks de la IA quedan congelados.
- **Input:** callado en solo y en red.
- **Continuar:** la partida sigue.
- **Salir:** vuelve al boot en ≤ 2 s con la pausa en false. Una partida «Contra la IA» de nivel 4 después de una de nivel 9 da 7 casillas, así que se cierra la deuda de F115.
- **Red:** el menú de A no frena a B ni al servidor, y el servidor imprime `peer_left`.
- **Capturas:** legibles.

**Pausa:** no hay ningún camino que deje la escena siguiente pausada. `_exit_tree` solo libera la pausa si la puso él. El fin de partida no cambia de escena.

**Esc:** solo lo usa `pause_menu`. El menú corre su `_input` antes que `MatchCommand` y no toca el hechizo armado.

**Composición:** el menú no tiene lógica de partida, no hay API solo para harness y `unit_body.gd` no se tocó. El desvío `ConfirmationDialog` → botones está justificado porque AgentKit no puede pulsar el diálogo.

## Dueño único de «¿el input llega al mundo?»
Hoy el estado tiene un solo escritor, `PauseMenu`, a través del grupo `menu_open`. El problema es que la regla está copiada en 5 lectores:
- `match_command`
- `wizard_body`
- `world_camera` (dos lugares)
- `soul_system`

Además los lectores usan el literal del grupo. **Recomendación:** `WorldInput.blocked(from)` como dueño único, primer paso de 031c, con el grupo `WorldInput.MODAL`. `walk_order` sigue siendo un chequeo propio de `match_command`, porque no es un modal.

## No bloqueantes
- El `_release_pause()` de `_quit` es redundante.
- Esc con la confirmación abierta cierra el menú entero, cuando debería volver a `%Main`.
- Las señales `opened` y `closed` no tienen quien las escuche.
- Con un hechizo armado, el cursor del hechizo se ve encima del menú.
- Los offsets del panel quedan fijos.
- Faltan flows de clic en el mundo con el menú abierto y de Esc con un hechizo armado.
