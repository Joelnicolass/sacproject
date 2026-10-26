# ui/match_wait

What: el cartel «Esperando jugadores k/n» de una partida en red que todavía no arrancó; en el host LAN, con al menos un cliente cargado, «Empezar ya» arranca con los que están.
Not: quién se sienta ni cuándo arranca (`MpMatchGate`, `Mp.gate()`); nada de red propio.
Talks to: escucha `Mp.gate().waiting_changed`; el botón llama `Mp.gate().start_now()`. Corre con el árbol pausado (`PROCESS_MODE_ALWAYS`).
Edit: `match.tscn` → `Hud/MatchWait` (posición, tamaño); textos `UI_MATCH_WAIT_*` en `data/i18n/strings.csv`. Quitarlo = borrar el nodo; la espera sigue igual.
Check: `-- --listen-host --mode=ffa3 --map=test_flat4` y dos clientes (`agent/runs/run_068_gate.sh`): el cartel dice 0/2, 1/2 y desaparece al arrancar.
