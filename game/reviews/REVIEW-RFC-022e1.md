# REVIEW RFC-022e1 (pasto estilizado BotW/Ghibli)

Veredicto: **PASS con observaciones** (cero bloqueantes verificables por código/headless). El look, el costo y los criterios 1-3, 5-6 quedan para `studio-visual` / `studio-playtester` (GUT y headless no los prueban).

## Corrido
- `debug/rules_suite.tscn` headless `--fixed-fps 600 --quit-after 600000`: **RULES SUITE PASS**, 0 FAIL.
- `high_noon.tscn` headless 120 frames: carga limpia, "mundo listo 54 ms", sin error ni warning.
- `debug/grass_lab.tscn` headless: arranca y sale sin error (en headless `GrassField` no genera nada, a propósito).
- Un solo proceso a la vez, RSS vigilado (< 2,5 GB), sin procesos vivos. `rg "func agent_"`: sin salidas en `scenes` (los dirs `src`/`glue` no existen en este proyecto). `git diff --stat` de playtest: no aplicable, repo sin commits (sin base para comparar).

## Criterios 022e1
| # | Criterio | Estado / evidencia |
|---|---|---|
| 1 | Valle como una superficie verde, raíz = color del suelo | Por código: raíz con el color horneado del suelo (`grass_bake.gdshader` + `ground_common.gdshaderinc`). Look: **pendiente de captura (studio-visual)**. |
| 2 | Borde invisible ≤ 6 % | Código: `edge_k` y alto decreciente hacia `radius_m` (`grass.gdshader:140-141,~176`). Medición de luminancia: **pendiente**. |
| 3 | Unidades no tapadas; cursor y marcador sobre el pasto | Aplastado implementado (ver abajo). **Marcador de orden: no existe aún en el juego** (solo `player_start.tscn` Label3D con `no_depth_test` y la barra de vida con `depth_test_disabled`), así que no se pudo ver. El pasto es opaco y **escribe profundidad** (`grass.gdshader:4`, sin `depth_draw_never` ni prioridad): cualquier marcador/decal/anillo de selección futuro con prueba de profundidad quedará tapado por briznas de hasta ~0,9 m. Nota para el RFC que lo cree: `no_depth_test` o `render_priority` alto. Captura: pendiente. |
| 4 | Sin briznas en altar, manantiales, sendero; `VegetationClear` en vivo | Código OK: `grass_mask.gd` toma grupos `altar` (lo añade `props/altar.gd:18`) y `manafount` (`manafount_body.gd:17`) más nodos `VegetationClear` (`@tool`, notifica por grupo en `_enter_tree`/transform/`_exit_tree` diferido; refresco de seguridad cada 1 s). Sendero: el shader usa las reglas del suelo (`height_by_layer`/`density_by_layer`). En vivo en el editor: pendiente de playtest. |
| 5 | Viento / sin estelas | Viento en shader con `TIME`; estelas con MetalFX: pendiente de playtest. |
| 6 | Costo | El developer midió ~+7 ms medio sin tope (RFC: ≤ +1,5). No lo repetí (prohibido `look_bench`). Desvío **aceptado por el usuario** (priorizó look); queda registrado, sin tope no hay cierre de rendimiento. |
| 7 | Editor / dedicado | OK por código: ver abajo. |

## Chequeos pedidos
- **Dedicado sin `GrassField`**: `look_rig.gd` libera el rig entero en dedicado/headless (línea 38, helper 105-108); además `GrassField._refresh` sale si `DisplayServer` es headless. PASS.
- **Nada derivado guardado**: `grass_layer.tscn` solo contiene el nodo con script (6 líneas); `look_rig.tscn` solo instancia `Grass`; `high_noon.tscn` no menciona pasto. Celdas con `INTERNAL_MODE_BACK`, MultiMesh/texturas/viewports de bake son runtime y se liberan. Ninguna asignación `_type.* =` en el código: el campo solo lee el `GrassType`; editar uno cambia únicamente su `.tres`. PASS.
- **Vista previa en el editor sin autoloads**: `@tool`, cámara vía `EditorInterface` singleton, sin referencias a autoloads; `look_rig.gd` documenta "No autoloads". `_get_configuration_warnings` avisa falta de `height.exr`. PASS (verificación visual en editor: pendiente).
- **Suelo sin cambio de comportamiento**: `ground_pbr` incluye `ground_common.gdshaderinc` (254 + 87 líneas), `bind_common` compartido. No hay commits para un diff real; acepto el "≤ 0,22 %" del developer como no verificado. La suite y `high_noon` cargan limpios.
- **Aplastado**: posiciones de los grupos `unit` y `wizard` (excluye `corpse`, voladores a > 2,2 m del suelo), escaneo cada 0,2 s, hasta 16 vivos (los más cercanos al centro del campo) + 32 de estela; radio = `BodySeparation.half_size × trample_radius_scale`. Costo CPU acotado; en shader `stamps[48]` en bucle. Límite conocido: con 60 cuerpos, solo se aplastan los 16 más cercanos al centro del campo (alcanza para la cámara RTS, pero conviene mirarlo en el banco del developer/playtest).
- **Licencias**: `assets/cc0/LICENSES.md` sección Code declara técnica BotW/Tsushima/GodotGrass (MIT) como "ideas only, no code copied" y descarta la serie CC BY-SA. Sin código copiado, sin obligación de atribución adicional. PASS.
- **Memoria / recursos**: dos MultiMesh compartidos (cerca/lejos) por todas las celdas; las celdas se borran al pasar `radio + 6 m`; al recibir cambios solo se reconstruyen los buffers si cambió la densidad; viewports de bake se liberan; `_height_image/_texture` estáticos únicos (1024², ~0,6 MB EXR). Sin crecimiento sin límite observado. Guardia del lab: topes `MAX_BLADES` 60000, radio 40 m, suave 2000 MB / duro 2500 MB con `quit(1)`; **mide `OS.get_static_memory_usage()` (RAM de Godot), no el RSS del proceso ni la memoria de GPU/unificada**, así que no cubre el costo de texturas y buffers en una Mac de memoria unificada.
- **Composición / `@export` / `@tool`**: tipos en `.tres` (`GrassType`, `GrassSet`), mirada de instancia en `@export` con grupos y rangos, responsabilidades separadas (campo, máscara, aplastado, malla de brizna, claros). Sin paths `../..`. `GrassField` es un nodo grande (478 líneas) pero con una sola responsabilidad (la capa).

## Observaciones (no bloquean)
1. **Carrera en `_bake`** (`grass_field.gd:~92-171`): `_refresh` desactiva y sale temprano (grass off, oculto, sin altura) sin subir `_generation`; si había un bake esperando 2 frames, al terminar pone `_active = true` y `set_process(true)` y empieza a crear celdas aunque el preset ya lo apague. Ventana de 2 frames al cambiar el preset/visibilidad en caliente. Arreglo: `_generation += 1` al inicio de `_refresh`.
2. Desvío del tope de 48 claros (`grass_mask.gd:12`): los excedentes se descartan **en silencio**; un `push_warning` una vez ayudaría si se agregan muchos `VegetationClear` (018d).
3. Guardia de memoria del lab: ver arriba (solo memoria estática, no RSS/VRAM).
4. Costo medio ~+7 ms contra +1,5 ms del RFC: aceptado por el usuario; no hay presupuesto verificado ni re-medido en esta pasada.
5. `cache/look/height.exr` está en `.gitignore` y se hornea por máquina (~172 s); sin él no hay pasto y avisa (warning del editor + `push_warning` una vez). Aceptable, pero documentarlo en el flujo de arranque del proyecto.
6. Alcance: no vi extras fuera del RFC. `GrassSet` dibuja solo el primer tipo (advertido en la configuración del nodo); máscara horneada a 1024² (celdas de 2,5 m/texel en el mapa de 2560 m): aceptable para zonas, puede quedar tosco en claros pequeños (cubierto por el suavizado de claros que va en shader, 48 discos).

## Cierre
022e1 se puede dar por cerrado **a nivel de código y carga**. Antes de cerrarlo del todo falta el playtest con capturas (criterios 1, 2, 3, 5), que no sustituye la revisión visual.
