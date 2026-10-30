# RtsKit, pieza (d): la cámara

Inventario de Sacrifice para que la sesión del kit lo vuelva genérico. Rutas desde `game/` en la rama `refactor/godot-standard`.

## Archivos

| Archivo | Líneas | Qué hace | Destino |
|---|---|---|---|
| `scenes/camera/world_camera.gd` (`WorldCamera`, un `Camera3D`) | 314 | Tercera persona siguiendo un cuerpo: se ubica detrás según el zoom, gira con teclas, bordes y mirada libre, y hace zoom con la rueda | Kit: el modo «seguir un cuerpo». El modo cenital libre es nuevo |
| `scenes/camera/camera_shake.gd` (`CameraShake`, hijo de la cámara) | 120 aprox. | Solo calcula `offset()` y `roll()`; la cámara los suma a su ubicación. Ruido propio con semilla fija, nada en un proceso headless | Kit: un gancho genérico «efectos sobre la cámara», o se queda en el juego. Es presentación, no RTS |
| `scenes/orders/world_input.gd` (`WorldInput`) | 19 | La cámara no lee entrada con un modal abierto | Kit (ver pieza c) |

## API que usa el resto del juego

| Miembro | Quién lo usa |
|---|---|
| `@export var follow: Node3D` y `set_follow(node)` | `MatchWorld`: el mago local, y otro cuerpo en la vista previa |
| `yaw` | `PointerRay.camera_yaw()`: el giro de las formaciones (pieza b). También el minimapa, que gira con la cámara |
| `is_dragging()` | `PointerRay.camera_dragged()` y `CommandInput`: con la cámara arrastrándose no se selecciona ni se ordena |
| `zoom`, `target_zoom`, `view_pitch_deg` | La UI de debug y los flows |
| `debug_pointer` | Los flows de AgentKit: reemplaza al puntero real para los bordes y para la mira |
| `shake` | `CameraShake` |
| Exports `ground`, `edge_area`, `wheel_blockers` | `match.tscn` |

## Comportamientos a conservar (modo «seguir un cuerpo»)

| Comportamiento | Valor |
|---|---|
| Bordes | El puntero a menos de `edge_px` (100 px) de un borde gira la cámara a `turn_rate_deg` (36°/s) y cambia el zoom a `zoom_rate` (0.5/s). Solo mientras el puntero está sobre `edge_area`, así que la barra del HUD queda afuera |
| Teclas | `turn_left` / `turn_right` a `key_turn_rate_deg` (180°/s); `zoom_in` / `zoom_out` |
| Rueda | `camera_wheel_in` / `camera_wheel_out`, paso `wheel_step` (0.04). No hace zoom sobre `wheel_blockers`; si un control tiene `covers(screen)`, decide él (el minimapa usa su círculo) |
| Zoom | Arranca en 0.125 (`start_zoom`), va de 0 a 1 y se asienta hacia `target_zoom` con `zoom_settle` (0.0001: la fracción que queda después de un segundo) |
| Mirada libre | `camera_orbit` (botón medio, o Ctrl + `select` con `camera_orbit_modifier`). `look_deg_per_px` = -0.25 (negativo da la sensación de «agarrar el mundo»). Pitch limitado a 85° hacia abajo y 80° hacia arriba, porque `looking_at` degenera en ±90°. Cuenta como arrastre después de 3 px (`drag_px`) |
| Ubicación | Se calcula con la altura del cuerpo: distancia `max(0.6 + 2.32·h, 4.5)`, más la flotación y la caída del foco por altura, y factores de zoom (`distance_zoom_*`, `height_zoom_*`, `focus_*`, `eye_lift`). Son las constantes del grupo `Formula` |
| Suelo | El ojo nunca baja de `ground_clearance_m` (0.5 m) sobre la tierra. Cuenta lo más alto entre el rayo al nodo `ground` (los props de la capa 1 no cuentan) y la tierra viva (`Terrain.height_at`), para que un Volcán que sube antes de que se rehaga su colisión no entierre la vista |
| Interpolación | `physics_interpolation_mode = OFF`: la cámara se ubica en `_process` |
| Ventana | Los bordes no corren si el mouse salió de la ventana (`NOTIFICATION_WM_MOUSE_EXIT`) |

## El modo cenital libre (nuevo, no existe en Sacrifice)

El selector de rectángulo y el ejemplo del kit lo necesitan. Lo que tendría que traer:
- moverse con WASD o flechas, con los bordes y arrastrando el botón medio;
- zoom con la rueda entre una altura mínima y una máxima;
- girar con Q/E o con un modificador;
- `focus(point)`, que la 0.2 usa para las alertas, el doble toque de un grupo y las posiciones guardadas;
- quedar dentro de un rectángulo de mapa que da el juego;
- la misma respuesta a `WorldInput.blocked` y a `wheel_blockers`;
- `yaw` y `is_dragging()` con el mismo contrato, para que las formaciones y la entrada no sepan en qué modo está.

## Lo propio de Sacrifice

- **`Terrain.of(self)` y `Terrain.height_at`**: en el kit sería un proveedor de altura del suelo, `func(x, z) -> float` o NaN. Sin proveedor, solo el rayo.
- **El mago como `follow`**: lo asigna `MatchWorld`.
- **La mira sobre la cabeza del mago**: `PointerRay.action_pointer()` apunta con el centro de la pantalla cuando se usa el teclado. Es del juego.
- **`CameraShake` y sus mapas (`shake_map.tres`)**: presentación del juego.

## Qué lo cubre hoy

- **Ningún test GUT.**
- **Flows de AgentKit** que usan `debug_pointer`.
- **La captura visual** con ventana: las pruebas de luces y de terreno dependen de la ubicación de la cámara, así que si cambia la fórmula cambian las capturas.

Para la RC del kit propongo tests de:
- la ubicación del modo seguir para una altura y un zoom dados (posiciones exactas);
- el límite del suelo;
- los bordes con `edge_area`;
- el bloqueo de la rueda con `covers`;
- los límites del pitch;
- el umbral de arrastre;
- en el modo cenital: los límites del mapa y `focus`.
