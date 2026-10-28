# REVIEW RFC-020d (F60) — El ritual: rondas, drenaje, cancelación y victoria

Fecha: 2026-10-13
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS |
| Arquitectura | PASS |
| Alcance | PASS |

Sin bloqueantes.

## Reglas contra las fuentes

- Anillo de 20 m en 45° + 90°·k, con el encogimiento de 3 m al final de la caminata: coincide con `ritualPositions`. En red los doctores quedan en (1514,1494), (1514,1466), (1486,1466), (1486,1494).
- Preparación 5 s y rondas de 13,5 s: en red las fases cambian en 24,5 / 29,5 / 34,0 / 38,5 / 43,05 s.
- Drenaje `200·(1+almas)` y `40·(1+almas)` por ronda, con las almas de la criatura; ventana de 20 ticks de inicio y 250 de duración (`state.d:15975`, `15997-16011`). Medido: 1500 → 1100 en la primera ronda.
- Daño crudo sin resistencias: justificado (`dealDesecrationDamage` → `dealRawDamage`).
- Sin tope de rondas: `finish_round` solo completa si el mago ya no está (`state.d:16030-16033`).
- Cancelación por cualquier doctor, por pérdida de la criatura o por caída del sitio (`state.d:15921-15925`).

## Empuje

La fórmula es idéntica a `pushAll` (`state.d:8614-8628`). Empuja unidades, magos y doctores ajenos, incluidos los del lanzador, como sacengine; respeta el suelo y las colisiones; no empuja fantasmas ni muertos. Con la regla actual (valores de sacengine, decisión del usuario) cuatro Druids llegan a 18–20 m, dañan a dos doctores y el ritual se cancela. Con la variante de barrera (24 m, 15 m/s) se quedan a 22–24 m y el ritual completa. No hay nada en sacengine que impida que el doctor sea blanco cuerpo a cuerpo.

## Red (dedicado + 2 clientes headless)

- Profanación completa: mismas fases, rondas y drenaje en los tres procesos; altar `COLLAPSING` y 11 s después `DESTROYED`; «Victoria» en A, «Derrota» en B, dedicado sin cartel.
- Cancelación por tiradores (no probada por el developer): los tres terminan con `outcome` abortado, 0 doctores, criatura libre, altar en pie y sin ganador.
- El `Ritual` replica `phase`, `round_index`, `outcome`, `kind`, `caster_slot`, `target_slot` y `creature_path` por su sincronizador. Ningún RPC nuevo. El cliente no simula. El dedicado no carga nada de `res://cache`.

## Composición

`Ritual` es un orquestador de 288 líneas sin `match` de fases; las fases son nodos de estado. `RitualPush`, `RitualFx` y `RitualNotice` se quitan sin romper la simulación. Cambios mínimos en `captive.gd` (`hand_to_ritual`) y `ghost_form.gd` (vuelta al cuerpo bajo ritual).

## Nits

1. `Ritual.complete()` no llama a `remove_desecration()` (sacengine sí, `state.d:15827`). El developer lo dejó así para que un mago en animación de muerte no pase a fantasma; hoy no tiene efecto, pero deja el contador en alto si ese mago volviera a vivir.
2. Al cancelarse, el dueño del altar no ve «Ritual interrumpido»; el lanzador sí.
3. Si el mago blanco no existe (jugador desconectado), el ritual completa tras la primera ronda: fiel a sacengine, pero es victoria casi gratis. Lo decide la política de desconexión.
4. `SacrificeMath.convert_rounds` sin uso hasta 020e. Búsquedas por el grupo `wizard` repetidas.

## Capturas del developer

Se ven los 4 doctores en anillo, los rayos a la criatura, el vórtice y los rayos sobre el mago, el derrumbe y el cartel. El cielo naranja liso es un artefacto de la sonda (`far = 2000`; la cámara del juego usa 20000), no un problema del cielo.

## Para el playtest con ventana

Profanación completa con cartel y derrumbe; cómo se ven rayos, vórtice y cuerdas; cancelación cuerpo a cuerpo y por tiradores, con el aviso en cada cliente; un hechizo real del rival contra un doctor; que el empuje se vea razonable.
