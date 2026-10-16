# REVIEW RFC-018a (F47) — Los modelos se ven en el editor

Fecha: 2026-10-12
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS |
| Arquitectura | PASS |
| Alcance | PASS |

Sin bloqueantes. Dos salvedades: nadie miró el editor con ventana, y el «`git diff` vacío» literal del RFC no se cumple porque el primer guardado cambia el formato (`uid=`, `unique_id=`, `load_steps`); no agrega malla ni pose.

## Evidencia (sondas propias del reviewer)

| # | Criterio | Resultado |
| --- | --- | --- |
| 1 | Las tres packed muestran el modelo | `ArrayMesh` en los 6 visuales del altar, en el manantial y en la planta, en editor headless; 0 `SCRIPT ERROR` |
| 2 | 4 pilares en las esquinas | Editor y runtime: (±20, 0, ±20); el centro de cada pilar a menos de 0,2 m de su colisión |
| 3 | `model` desplegable | Hint ENUM con 155 opciones |
| 4 | Guardar no deja malla ni pose | Re-guardados sin `ArrayMesh`, `PackedByteArray`, `CapsuleMesh` ni `res://cache/` |
| 5 | Sin caché | Relleno y aviso, sin error (simulado con una carpeta vacía) |
| 6 | Runtime igual | Dedicado real: 0 cargas de `cache/baked`; 8 escenas debug sin `ERROR`; 314 casos de pose iguales al script anterior |

- Ningún `.tscn` del proyecto guardaba un transform en un nodo `BodyVisual`, así que quitarle el guardado no pierde datos. Fuera del editor el flag no se toca.
- La base que leen `unit_body.gd`, `wizard_body.gd` y `manafount_body.gd` para `ClipPose` es idéntica a la de antes (310 casos, error 0).
- `loads_meshes()` no cambió en runtime; el `or` solo cuenta dentro del editor.
- El cambio en `clip_pose_player.gd` es mínimo y solo de editor.

No corrió: nada con ventana, Ctrl+S real, dedicado con clientes.

## Nits y pendientes

1. `props/manafount.tscn`: `node_paths=` sobre `mesh_path` (un `NodePath`) lo deja vacío; funciona por un fallback. Va en 018b. Mismo patrón en `units/unit.tscn`, `wizard/wizard_body.tscn` y `structures/structure.tscn`.
2. `props/plant.tscn`: el `BodyVisual` es la raíz; una planta colocada a mano pierde la posición al guardar o duplicar. Requisito previo de 018d.
3. `body_visual.gd`: el gizmo todavía puede mover un visual; el cambio no se guarda ni se revierte hasta recargar.
4. F17 dice «cuerpos 84 de pie 84»; la galería lista 155 porque incluye props.
5. Menores: `BodyCatalog.refresh()` sin caller (conviene llamarlo desde `tools/bake_bodies.gd`); la lista de tags se arma en cada `get_property_list()`, también en runtime; `set_physics_process(true)` redundante en `clip_pose_player.gd`.

## Aparte

- `high_noon.tscn`: la instancia `Sky` guarda un `background_color` verde que el runtime pisa con el bioma.
- `ClipPosePlayer` tiene `_physics_process` propio y además `unit_body.gd` y `wizard_body.gd` llaman `advance(delta)` a mano: los clips podrían avanzar dos veces por tick. Leído, no medido.
