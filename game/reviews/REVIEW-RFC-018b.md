# REVIEW RFC-018b (F48) — Inicios y manantiales como nodos de la escena

Fecha: 2026-10-13
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios | NEEDS WORK por las posiciones guardadas de los inicios (ver abajo); el código cumple |
| Arquitectura | PASS |
| Alcance | PASS |

## El único hallazgo que frena el cierre

`high_noon.tscn` se guardó desde el editor el 2026-10-12 a las 21:13, después de las pruebas del developer (20:48). En ese guardado `Start2` está en (1498.1, 22.07, 1328.1) en lugar de (1040, 15.1, 980), y `Start1` corrido 5 cm. Con eso el mago 2 nace a unos 450 m de donde nacía. Los logs del developer muestran el mapa bien antes de ese guardado.

Nota del orquestador: no es un defecto del corte. Es una edición hecha en el editor con el gizmo, que es justamente lo que el corte habilita, y el archivo guardado quedó limpio (10,4 KB, sin malla, sin vista previa, raíz sin posición). No se revierte sin preguntarle al usuario.

## Evidencia

- Parseo headless sin errores; `rules_suite` da `RULES SUITE PASS`.
- `high_noon`, `mana_fount`, `hole_edge`, `structure_siege`, `late_join`: 0 `ERROR`.
- 5 nodos en el grupo `manafount` en las posiciones del criterio, `rate` 33,333 y radio 50. 2 altares con `ManaSource` de `owner_slot` 1 y 2, `rate` 16,667.
- Con las reglas de `cast_heal.tres`, el `rate` de las 7 fuentes es 0: el orden de inicialización de `rules` funciona.
- Dedicado real: `dedicated listo puerto 7861`, `mundo listo`, sin `ERROR`.
- Editor headless: los 7 nodos con malla; carteles «Jugador 1» y «Jugador 2»; mover un manantial o un inicio deja su `y` igual a `terrain.ground_height`; duplicar un manantial lo apoya; los avisos de `faces` vacío y de slot repetido aparecen y se van. Re-guardado: 10,3 KB, sin datos embebidos ni `Preview`, raíz sin posición. Tras `POST_SAVE` la vista previa vuelve una sola vez.

No corrió: la sonda de maná con magos en cada fuente ni un cliente contra el dedicado (lo hizo el developer).

## Arquitectura

Cada pieza hace una cosa. `PlayerStart` y `GroundSnap` tienen `class_name`, sockets tipados, `@tool` y avisos. Los `.set()` / `.call()` sin tipo van solo hacia código existente. El `_process` de editor de `PlayerStart` escribe solo cuando cambia algo y nada de eso se guarda. `GroundSnap` pisa la `y` al mover el padre; se apaga con `enabled = false`.

## Nits

1. Cuatro flows con rutas viejas: `agent/flows/pt35_manalith_lifecycle.json:15`, `pt20_solo.json:21-22`, `f17_world.json:23-24`, `f22_mana_pt.json:6-7`.
2. `Preview` se instancia en runtime y se libera en `_ready`; inocuo.
3. `altar.get("owner_slot")` da null: `altar.tscn` no tiene script. Lo arregla 017a.
