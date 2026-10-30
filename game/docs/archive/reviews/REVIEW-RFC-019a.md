# REVIEW RFC-019a (F52) — Suelo suavizado y lightmap en coordenadas de mapa

Fecha: 2026-10-13
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS en juego; el lightmap quedaba corrido en la vista previa del editor |
| Arquitectura | NEEDS WORK por un bloqueante de «editor primero», ya corregido |
| Alcance | PASS |

## Bloqueante (resuelto por el orquestador)

`light_base` y `light_gain` no eran editables: el material del suelo se regenera desde el caché y es de solo lectura. Ahora son dos `@export_range` del grupo «Light map» en `Terrain`; se pasan al material al crearlo y al cambiarlos, y sobreviven a `set_tileset_dir`. Verificado en editor headless: 0,3 / 0,55 por defecto; al poner 0,8 el material lo refleja sin recrearse y lo conserva tras cambiar de tema.

## Defecto de la vista previa (resuelto junto con lo anterior)

En el editor `terrain.gd` desplaza al nodo padre −1275 para centrar el mapa, y el shader usaba la posición de mundo: el lightmap quedaba corrido media textura. Ahora usa la posición local del vértice (`map_pos = VERTEX`), que es la coordenada de mapa; en juego es equivalente.

## Evidencia del reviewer

- Sonda de normales: 3 174 / 3 174 con `smooth_ground`, 29 sin él, paredes 1 016 / 1 016.
- Sonda propia de colisión: 220 puntos, `ground_height` e `is_on_ground` idénticos con y sin suavizado; el nodo de colisión no se reconstruye.
- El algoritmo coincide con `sacmap.d:720-744`. Un vértice de suelo junto al borde no se contamina con la pared.
- Editor headless: `smooth_ground` en la lista de propiedades, cambiarlo rehace las normales, la escena re-guardada no embebe malla ni texturas.
- Regresión de 5 escenas y dedicado: rc 0, sin `ERROR`.
- Capturas del developer: las facetas desaparecen (evidente en `v2_slope`), el borde suelo/pared sigue neto, brillo equivalente, sin costuras ni manchas nuevas.

No corrió: nada con ventana; el recorrido de `theme_applier.gd` (lo dedujo de la lectura).

## Nits

1. El suavizado también corre en el dedicado, que no dibuja (unos 0,5 MB y un diccionario al arrancar).
2. `debug/terrain_normals_probe.gd` solo imprime: debería salir con error si no da 3 174 / 3 174.
3. El rectángulo negro grande que se ve delante del cielo en `v2_slope` es previo al corte; sin identificar.

## Para el playtest con ventana

Laderas sin facetas de cerca y de lejos; borde de acantilado neto; brillo sin lavar; el suavizado se conserva al cambiar de bioma; el lightmap no se mueve con la cámara.
