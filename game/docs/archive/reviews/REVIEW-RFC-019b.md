# REVIEW RFC-019b (F53) — Modelos de pie y apoyados

Fecha: 2026-10-13
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS (frente y aspecto quedan para ventana) |
| Arquitectura | PASS |
| Alcance | PASS |

Sin bloqueantes. El corte se cierra.

## Evidencia

- `audit_body_pose.gd`: `POSE AUDIT PASS`, 31 modelos. `rules_suite`: `RULES SUITE PASS`.
- La auditoría mide la misma pose que usa el juego (`BodyCatalog.pose`) sobre el cuadro 0 del idle. Una sonda independiente en Python sobre los OBJ dio lo mismo para `eorc`, `humn`, `maho`, `jnwr` y `gobl`: pies entre −0,02 y 0,10 m, cápsula igual al alto del modelo.
- 9 escenas debug sin `ERROR`; el duelo Druid contra Trogg pega y baja vida.
- Dedicado real: sin `ERROR`, ninguna malla de `cache/baked` cargada.
- Editor headless: una entrada de override sube el visual, cambia la cápsula, escala y gira en vivo; al quitarla vuelve; la escena re-guardada no embebe mallas. El `.tres` real quedó intacto.
- Los 53 cuerpos sin clip quedaron idénticos al respaldo. `props.json` solo cambió en `pcfn`, cuyo giro pasó al `.tres`.
- La corrección de desplazamiento es coherente con `saxs.d:313-314` y `sxsk.d:124-139`, e idempotente por marcador.
- `unit_body.gd`, `wizard_body.gd`, `clip_pose_player.gd` y `wizard_preview.gd` no se tocaron.

No corrió: nada con ventana, `tools/audit_unit_parity.py` (escribe en `out/`), la medición de los pilares del altar.

## Límites de la auditoría

Solo mira el cuadro 0 del idle. El chequeo del alto de la cápsula es casi circular (sale del mismo cuadro). No verifica el frente del modelo.

## Brainiac

El clip trae el cuerpo 1,4 m sobre el origen y sacengine lo vuela a `flyingHeight` sobre el piso (`state.d:12304-12309`, `14758-14769`): lo fiel literal es dejarlo arriba. La corrección lo baja para cumplir el criterio. Recomendación: que el usuario decida mirándolo; si prefiere fidelidad, se quita `position_offset` y se deja `capsule_height`.

## Nits

1. `BodyCatalog.refresh()` no relee el `.tres` del disco: `ResourceLoader.load` devuelve la instancia en caché (`body_catalog.gd:46-58`).
2. Si se borran los `.obj` de un clip y queda el marcador `.displacement_fixed`, el re-export los deja sin corregir (`export_stats.py:458-465`).
3. Riesgo de balance por los alcances nuevos: Sylph 0,34 → 0,77; Ranger 0,36 → 0,81; Druid 0,27 → 0,55; Frostwolf 0,47 → 0,76; Jadugarr 2,60 → 1,76; Sorcha 0,80 → 0,56.

## Para un playtest con ventana

Frente y giro de los 31 modelos; Brainiac; los magos en el selector; combate con los alcances nuevos; edición en vivo desde el inspector real.
