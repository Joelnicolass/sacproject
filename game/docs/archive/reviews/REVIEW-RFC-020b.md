# REVIEW RFC-020b (F58) — El Sac Doctor como actor

Fecha: 2026-10-13
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS |
| Arquitectura | PASS |
| Alcance | PASS |

Sin bloqueantes.

## Evidencia del reviewer

- `addons/fsm_kit` idéntico al de la RC. `rules_suite`: `doctor_stats`, `doctor_regen`, `doctor_one_shot`, `doctor_melee` en PASS.
- Sonda propia con una orden de ataque por `Orders._apply`: las criaturas persiguen al doctor y le bajan la vida 400 → 314 → 161 en 6 s.
- Red: dedicado + un cliente headless; el cliente ve los 3 doctores y la caída de `DoctorDrop`; el dedicado no carga mallas. Movimiento y daño replicados: logs del developer.
- Editor headless: `doctor.tscn` carga con malla, sin avisos, y re-guardada no embebe mallas.
- De las once escenas de regresión pedidas, cinco confirmadas sin `ERROR`; las otras seis seguían corriendo al escribir el informe.

## Regresión de blancos

`Attackable` es una lista única (`wizard`, `unit`, `structure`, `doctor`, sin `corpse`): cambio aditivo. Los tres sitios cambiados siguen exigiendo `is_targetable()` y vida. `_is_valid_foe` no se tocó: invocación, roca y sigilo se filtran como antes, y un doctor propio no es blanco. Los doctores viejos usan otros grupos y no quedan afectados hasta 020c.

## Composición

Los modos son nodos bajo `FsmMachine`; el cuerpo no tiene `match pose`. Sockets tipados con avisos. `StuckGuard` se apaga quitando el nodo. El cliente no simula. `@tool` no ejecuta lógica de juego en el editor. Ningún número del original commiteado.

## Nits

1. `doctor_drop_height` y `doctor_exit_depth` declarados sin lector hasta 020c.
2. El comentario de `doctor_bounce_s` no aclara que la invulnerabilidad cubre toda la caída.
3. La cápsula guardada en `doctor.tscn` es un placeholder que `_ready` reemplaza.
4. Copia oculta de un doctor muerto en el cliente en escenas sin spawner: lo resuelve el spawner de 020c.

## Para el playtest con ventana

Clic sobre el doctor y orden de ataque; que no sea seleccionable; caída, barra de vida y fundido al morir; cliente que entra mientras cae; criatura enemiga ociosa atacándolo sola; doctor trabado contra un borde.
