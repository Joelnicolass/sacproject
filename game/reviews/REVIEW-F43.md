# REVIEW F43 — Higiene del mundo (Fase 0 de AUDIT-2026-10-12)

Fecha: 2026-10-12
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).
Arquitectura: estándar. Multijugador: online dedicado. Godot 4.7.2.

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS |
| Arquitectura | PASS |
| Alcance | PASS con nits |

Sin bloqueantes. El corte se cierra.

## Evidencia

| Qué se corrió | Resultado |
| --- | --- |
| `--headless --path game --quit` | exit 0, sin `ERROR` ni `SCRIPT ERROR` |
| `res://scenes/world/high_noon.tscn` | `mundo listo 71 ms` |
| `debug/{hole_edge,walk_order,melee_duel,biome_gallery,ability_spit,mana_fount,sky_motion}.tscn` | las 7 cargan el mundo sin errores |
| `-- --dedicated` unos 5 s | `dedicated listo puerto 7777`, `en high noon slot 0`, sin errores |
| Sonda que instancia High Noon y la re-empaqueta | `mesh` y `material_override` con `storage=false`; el `.tscn` re-guardado pesa 12 KB sin `PackedByteArray`; colisión con 6 862 caras; el rayo y `ground_height` coinciden en dos puntos |

- `high_noon.tscn`: 9 517 bytes, 0 `PackedByteArray`. Ningún `.tscn` ni `.tres` del proyecto lo contiene.
- Quitar el `transform` (-1275, 0, -1275) de `Terrain` no movió nada: el mago aparece en (1504.93, 16.76, 1540.41), igual que en F12. Ninguna otra escena sobrescribe `Terrain` y nadie lee su posición.
- `terrain.gd` lo usa un solo nodo, así que quitarle el guardado a `mesh` no pierde datos en otra escena.

No se corrió: el editor con interfaz (Ctrl+S real), un render con ventana, ni un cliente contra el dedicado.

## Límite

El repo no tiene commits y el índice guarda versiones viejas, así que `git diff` mezcla este corte con trabajo anterior. Se confirmó el estado actual, no el «antes».

## Nits

1. Índice de git desactualizado: falta `git add` de `high_noon.tscn`, `terrain.gd`, `high_noon.gd` y `RULES.md` antes del primer commit.
2. La escena tiene `uid://cvgikgwb1sifg`; 23 escenas de `debug/` y `agent/fixtures/spawn_view.tscn` la referencian con `uid://highnoonworld01`. Resuelve por ruta; se rompe si la escena se mueve.
3. `tonemap_exposure` huérfano en `high_noon.gd`. Resuelto por el orquestador: borrado.
4. `mesh` y `material_override` seguían editables en el inspector aunque no se guardan. Resuelto por el orquestador: `PROPERTY_USAGE_READ_ONLY`.
5. El criterio de la auditoría pedía que `git grep PackedByteArray` no encontrara nada en `scenes/`, pero `terrain.gd` usa el tipo. Resuelto: el criterio ahora nombra `.tscn` y `.tres`.
6. El rótulo `Terrain/Missing` queda en el origen, lejos del mapa, y `terrain.gd` escribe su `visible` en el editor.
7. `Sky.background_color` guarda un verde en `high_noon.tscn` que el runtime pisa con el bioma; parece un valor de preview guardado por accidente.
8. Sin recentrado, el terreno en el editor está a unos 1275 m del origen; hay que encuadrarlo con F.
