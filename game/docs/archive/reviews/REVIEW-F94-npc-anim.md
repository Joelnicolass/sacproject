# REVIEW F94 — Animaciones de Farmer y Taurock y doble avance de clips (RFC-028, corte 028c)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto:** PASS en código, sin bloqueantes. Faltan evidencias del playtest.

## Código
- **Ningún estado queda sin avanzar el clip.** `ClipPosePlayer._physics_process` lo avanza sin condiciones, y la simulación no lee el reloj del clip.
- **No queda doble avance** en ningún otro cuerpo (se revisó con `rg` en todo `scenes/`).
- **`hash(name)` es estable entre peers**, porque el servidor fija los nombres en el spawn.
- **Composición correcta:** los roles salen de datos y los knobs están en `PeasantBehavior`.

## Nits
- El comentario «the same on every peer» promete de más: `_cower_loops` es un contador local.
- `TALK_COWER_EVERY` es const; se acepta.
- Unificar `_clip_pose` como socket tipado.
- **Deuda previa:** un DEAD en el suelo del servidor sigue con el último rol del clip y los clientes muestran idle. Pasa a RFC-023.

## Pendiente para el playtest
- Farmer huyendo con PErn.
- `village_taurock` (BErn, BEa1).
- Tiempo de cuadro A/B con 26+6 NPC.
- Regresión `pt73w_*` y `f79_roster`.
- Revisar a ojo la velocidad nueva de los clips en criaturas y mago.
