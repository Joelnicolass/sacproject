# REVIEW RFC-020a (F57) — Altar con estado y partida que cierra

Fecha: 2026-10-13
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS |
| Arquitectura | NEEDS WORK por un bloqueante de una línea, ya corregido |
| Alcance | PASS |

## Bloqueante (resuelto)

`scenes/world/match/match_state.gd`: `_physics_process` llamaba a `MpKit.is_networked()` también en el editor, donde el autoload no existe: `SCRIPT ERROR` en cada frame con cualquier escena abierta que contenga `%Match`. Corregido por el orquestador con una guarda de editor en `MatchState` y en `DefeatRule`; verificado en editor headless: 0 `SCRIPT ERROR`.

## Evidencia del reviewer

- **Red, dedicado + 2 clientes headless**, High Noon con los dos altares en pie. El servidor marca al mago 2 «bajo ritual» y lo mata: muere a t≈5,5 s, desaparece 4 s después, el altar 2 pasa a `COLLAPSING` y llega a `DESTROYED` 11,0 s más tarde en el servidor y en los clientes. Los tres procesos terminan con `defeated=[2]`, `winner=1`. A «Victoria», B «Derrota», cartel invisible en el servidor. Las criaturas del slot 2 pasan de 2 a 0 en los tres. 0 `ERROR`.
- **Fantasma** con altar en pie: muere, se levanta, se cura y vuelve con 1500 de vida. La partida no termina.
- **Editor headless**: las seis escenas nuevas o tocadas cargan; el altar conserva base, techo y pilares en (±20, ±20) bajo `Visuals`; re-guardar `high_noon.tscn` no embebe datos ni mueve los inicios.
- `rules_suite`: `RULES SUITE PASS` con `altar_collapse`, `match_snapshot`, `match_banner`.

No corrió: el render del derrumbe; entrada a mitad del derrumbe (se apoya en los logs del developer); nada con ventana.

## Reglas contra sacengine

La cadena coincide: muerte bajo ritual → desvanecido 4 s (`state.d:14009-14010`) → `lose(side)` = altares y criaturas (`13404-13407`, `25998`) → 4+4+3 s (`5289-5291`) → `defeat(side)` (`26062`). Un mago que muere sin ritual y con altar en pie vuelve como fantasma. Sin altar en pie, pierde.

## Red

`MatchState` usa la clave `"match"` del snapshot y `MpFlow` no la lee: no se pisan. El reloj del derrumbe lo lleva el servidor; el cliente anima. `Altar.state` viaja solo por snapshot. `GhostForm:under_ritual` y `stage` quedaron en los índices 11 y 12 del sincronizador.

## Nits

1. `Altar.ANY_GROUP` no lo lee nadie.
2. `DefeatRule.kill_creatures` escribe la vida a mano; pasar por la API de `Health`.
3. «Fin de partida» es inalcanzable: un slot derrotado siempre recibe «Derrota».
4. `AltarCollapse.duration_s` y `MatchRules.altar_collapse_s` son dos perillas para lo mismo.
5. `add_desecration` / `remove_desecration` no tienen llamador hasta 020d.
6. Un jugador que se desconecta no cierra la partida. Fuera de alcance.

## Para el playtest con ventana

El derrumbe en pantalla (4 s hundirse, 4 s subir, 3 s estallar); `match_defeat.tscn` con dos clientes hasta «Victoria» y «Derrota»; entrada a mitad del derrumbe y con la partida terminada; el editor sin errores al abrir High Noon; solo sin cambios.
