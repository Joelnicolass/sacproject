# REVIEW-RFC-030t-a (F131): Devour

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: CHANGES** (1 bloqueante), corregido por el orquestador.

## Bloqueante
- **B1.** `DevourGrowth.bulk()` es API de producto que solo usaba el harness.
  - **Corregido:** se borró `bulk()` y `pt131_watch` ahora lee `mesh.scale`. `f131` sigue en `6973c160`.

## Revisión (PASS)
- **Fidelidad:**
  - `devourSoul`: +500, incremento 0,25·máx y después 0,75·inc+125, regeneración inc/60, resistencia ×0,9.
  - El alma se encoge 3/60 por tick.
  - `severSoul`.
  - Rainbow: 600 en 150 ticks, solo si no está lleno.
  - Bulto `2 − 0,75ⁿ`.
  - Regeneración × maná/máx.
  - Alcance 2D según la caja.
  - `isApplicable`.
- **Costo 0** (`float(mana_cost)`): es fiel (29584, 13468). Ahora Play Dead y Devour se pueden usar con maná 0, como en el original. Los otros `max(1)` del código son de hechizos o disparos.
- **Un dueño:**
  - `DevourGrowth`.
  - `Soul.sever()`, que es el único que disuelve. `_try_collect` mantiene el orden.
  - `Soul.on_corpse`.
  - `RangedAttack.origin_of`.
- **`DEVOURING` al final del enum:** ningún código compara estados por orden.
- **Banco:** `holds_still` y `target_soul` existen solo en `debug/`.
- **`HealEffect.report_each`:** solo agrega log.
- **Red:** `DevourGrowth:shown` va en `properties/18`.
- **Reglas:** `unit_body` sigue en 1040 líneas.

## Menores
- **m1.** Hay una referencia circular entre `Health.growth` y `DevourGrowth.health`.
- **m2.** `report_each` se pisa en cada Devour.
- **m3.** Las divergencias están declaradas.
- **m4.** `_devour_step` no exige autoridad, igual que `_collect_step`.

## Playtest (Sonnet, una corrida)
- El alma se encoge hacia la Netherfiend: 5,52 m → 1,56 m, escala 0,63 → 0,18.
- La Netherfiend pasa de 402,6 a 560,7 px (×1,39, con bulto 1,40) y la vida máxima de 1800 a 2800.
- El Hellmouth crece y no se cura: no hay ninguna línea `cura`.
- Los rechazos no gastan maná (500 → 500).
- **Reserva:** `Corpse.dissolve` hace desaparecer el cadáver de golpe a los 2,5 s, sin fundido. Lo mismo pasa con la recolección normal de almas.
