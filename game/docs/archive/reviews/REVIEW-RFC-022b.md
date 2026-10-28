# Review RFC-022b (luz base)

Alcance: `rfcs/RFC-022-graphics-upgrade.md` (§3 fila 022b, §5-§9, §17, "Medido en 022a" con aclaración, "Medido en 022b") y `VISUAL.md`. Una pasada, solo lectura.

## Veredicto: FAIL con 1 bloqueante (corregible con un cambio de datos)

| Dimensión | Resultado |
|---|---|
| Criterios 022b (sombra/sol, penumbra, sin 255, nada negro) | PASS |
| Imagen vs referencia (VISUAL pilar 5, ref 2) | **FAIL**, bloqueante 1 |
| Modo clásico idéntico (`look = null`) | PASS |
| Restauración al apagar y en PRE_SAVE; `env_base.tres`; `high_noon.tscn` | PASS |
| Cliente vs dedicado | PASS (nit 3) |
| Composición / editable por un technical artist | PASS con observaciones |
| Costo | PASS con observaciones |

## Verificación ejecutada

- `rules_suite.tscn --fixed-fps 600 --quit-after 600000`: `RULES SUITE PASS`.
- Carga headless de `high_noon`, `look_gallery`, `convert_ritual` (`--quit-after 120`): sin ERROR/WARNING/SCRIPT ERROR.
- `rg -n "func agent_" scenes` (src/glue no existen en este proyecto): vacío.
- Píxeles sobre `agent/out/rfc022/022b/v2/ref_on.png` (tercio inferior = suelo): 0 píxeles con los tres canales >= 254; luminancia lineal media del suelo 0,134 con la capa contra 0,030 sin ella.
- Experimento propio (script en el scratchpad, no tocó el proyecto; ventana 1280x720, cámara `ref` de `look_light_probe.tscn`, Persephone, capa encendida; cambié una propiedad del `Environment` privado por cuadro y capturé).

## Bloqueante 1: velo lechoso causado por la niebla volumétrica sin recalibrar

**Archivos:** `data/look/env_base.tres:10-11` (`volumetric_fog_enabled = true`, solo anisotropía 0,75; **densidad, largo y albedo quedan en el default del motor**: densidad 0,05, largo 64 m, albedo blanco); `scenes/world/look/light/light_layer.gd:15-23` (`ENV_PROPS` no incluye ninguna propiedad volumétrica) y `:141` (`_apply_environment` no la toca); `light/light_look.gd:23` (`sun_fog_energy`).

**Causa medida.** La aclaración de la review de 022a dice que 022b recalibra la volumétrica; no lo hizo. La densidad por defecto (0,05 sobre 64 m = ~96 % de extinción al final del volumen) cubre toda la cámara del juego y el altar, y 022b subió el sol de 0,43 a 1,6 (x3,7) y el ambiente de ~0,22 a 0,65 (x3), así que la dispersión hacia el sol (anisotropía 0,75) quedó mucho más fuerte, justo en la cámara `ref` que mira hacia el sol.

Experimento (misma captura, una variable por vez):

| Variante | Resultado |
|---|---|
| Base (capa encendida) | velo grande alrededor del sol, altar gris, suelo gris verdoso |
| Glow apagado | **idéntico**: el glow no interviene |
| Volumétrica apagada | altar con textura y verdes, cielo celeste, mucho más contraste |
| Volumétrica apagada + `fog_sun_scatter` 0 | idéntico a la anterior: la dispersión de la niebla de profundidad no interviene |
| `volumetric_fog_density` 0,01 | altar legible, un poco de bruma de valle; **valor recomendado** |
| `volumetric_fog_density` 0,003 | casi igual a apagada |
| anisotropía 0,3 (densidad 0,05) | velo uniforme, sigue lavado |
| `light_volumetric_fog_energy` del sol 0,05 (densidad 0,05) | sigue lavado: es extinción además de dispersión, `sun_fog_energy` no alcanza |

Valores descartados con evidencia: `fog_sun_scatter` 0,4, glow (`hdr_threshold` 1,0, intensidad 0,3), exposición 1,0, saturación 1,05, ambiente 0,65. La niebla de profundidad (`fog_depth_begin` 0, fin 1500 de `theme.json`) solo blanquea los cerros lejanos, no es el velo. El comentario de `light_look.gd:20-22` ("Low avoids a milky glare") es falso con estos números: la perilla correcta es la densidad.

**Cámara de juego.** `rts_on.png` también sale gris: el suelo a 20-40 m está dentro de los 64 m de volumen. No es solo un artefacto del encuadre hacia el sol.

**Corrección pedida (una):** exponer `volumetric_density` (y `volumetric_length`) en `LightLook` (grupo "Fog (until 022f)"), añadirlas a `ENV_PROPS` para que se restauren, aplicarlas en `_apply_environment`, y fijar ~0,01 en los cinco `*_light.tres` (menos en Pyro/Charnel solo si se ve necesario); corregir el comentario de `sun_fog_energy`. Recapturar `ref_on` y `rts_on` y repetir la medición de sombra/sol (debería moverse poco) y los ms de medio. 022f sigue siendo dueño del look final de la volumétrica; esto es la recalibración mínima que la aclaración le asigna a 022b.

**Suelo pálido.** Es creíble como textura, no como luz: en las seis variantes (con y sin niebla) el suelo conserva el mismo tono, la luminancia 0,134 es razonable con sol a 36 grados y los cuerpos bajo el mismo sol tienen color. El albedo gris verdoso del atlas es lo que 022c reemplaza. La luz no lo explica; el velo volumétrico sí explica el gris del *conjunto*. Con la corrección, el suelo debe seguir pálido hasta 022c, y no cuenta contra 022b.

## Criterios del RFC 022b

- Sombra/sol >= 0,35: medido 0,54 por el developer (sondas de `look_light_probe`); coherente con los datos de las capturas (suelo en sombra legible en `ref_on`). OK.
- Penumbra visible: `ref_on` muestra bordes suaves en las sombras de los cuerpos y del altar (`sun_angular_distance` 0,7, `shadow_blur` 1,2). OK.
- Sin píxeles 255 en el suelo: verificado, 0. OK.
- Nada negro: doctores bajo la losa 0,011 a 0,100 de luminancia, píxeles casi negros 35 % a 3 % (medición del developer; no la reprodujé). OK.
- Preset medio/bajo/alto: `quality_low` 2 splits, `quality_medium` y `quality_high` 4 splits (`shadow_splits` 1 / 2 / 2 son `PARALLEL_2_SPLITS` / `PARALLEL_4_SPLITS`), SSAO en medio y alto, SSIL solo en alto: coincide con §9.
- Look de cada dios en `data/look/light/<dios>_light.tres` (5), cargados por `LookProfile.light`. OK.

## Chequeos pedidos

- **Modo clásico idéntico.** Con `look = null`: `ThemeApplier.apply` llama a `LookApplier.apply(null)`, el rig llama `apply_look(null)` y `LightLayer._refresh` ve `_look == null`, va a `_restore`, que sale sin tocar nada porque `_applied` es false. La partida nunca entró en estado modificado. OK. Los cinco `data/themes/*.tres` ahora referencian su `LookProfile`: **cambia el look de todas las partidas**; es lo pedido por el flujo del corte, pero ver recomendación del preset.
- **Restauración.** Apagar el nodo (`visibility_changed`) o perfil null: `_restore` devuelve sol, entorno y apaga el relleno (`fill.visible = false`). `NOTIFICATION_EDITOR_PRE_SAVE` (`light_layer.gd:54-60`) restaura y `POST_SAVE` reaplica. OK.
- **`high_noon.tscn`.** El diff contra el índice es grande (119/65 líneas) por el reguardado del editor y por cambios de otros RFC (uids, props, `Sky`, `Match`); lo relevante de 022b: `Look` instancia `look_rig.tscn` con `sun` y `world_environment` asignados; `Sun` conserva su `transform` clásico (az 23, el 46: no es el de Persephone 25/36, así que no se guardó nada derivado); `Environment` sigue apuntando a `env_base.tres`; sin ambiente, exposición, SSAO ni splits guardados. OK.
- **`env_base.tres` no se muta.** `_take_environment` duplica antes de escribir (y `ThemeApplier` ya entrega una copia privada en partida); PRE_SAVE vuelve al recurso fuente. El archivo (sin seguimiento en git, no hay diff que mirar) contiene solo `tonemap_mode`, SSAO, glow, niebla y volumétrica. OK.
- **Cliente vs dedicado.** `look_rig.gd:33-35` se libera con `DisplayServer` headless o `MpKit.is_dedicated()`; `QualityApplier.apply` es inerte en headless. Cargas headless limpias. Ver nit 3.
- **Composición.** `LookLayer` es un contrato mínimo (`apply_look`/`apply_quality`), las capas no se conocen entre sí, `LightLayer` recibe sol y entorno por sockets `@export` del rig (sin `get_node("../..")`), `fill` es un socket tipado con `_get_configuration_warnings`, tipos en `LightLook`/`LookQuality` `.tres`, todo con `@export_range` y grupos. Un technical artist puede editar un `.tres` y apagar la capa ocultando el nodo. OK.

## Recomendaciones (no bloqueantes)

1. **Preset por defecto.** Con `%Look/Quality.quality = null` la partida corre con la luz nueva pero sin escala ni AA del preset y con los valores del `LightLook` (4 splits, 220 m, SSAO): es un híbrido que nadie midió. Recomiendo asignar `quality_medium.tres` al nodo `Quality` en `high_noon.tscn` una vez corregido el bloqueante 1, porque §9 lo declara por defecto y los +0,4 ms medidos son de ese preset. El riesgo es el modo MetalFX espacial en otras plataformas (cae a otro modo; `read_back` ya lo detecta). Si prefieren no cambiar la resolución interna aún, dejarlo en null es aceptable un corte más, con el híbrido anotado en el RFC.
2. **Costo de alto (+5,7 ms).** El techo de §3 (14 ms) es del preset medio, que da +0,4 ms sobre un +2,0 estimado: dentro de presupuesto. Alto cae en el piso de 30-45 fps (14,9 ms en cuadro, margen amplio), así que no bloquea. Sí conviene aislar SSIL: es la primera línea del orden de recorte de §9, la estimación era +2,0 y el banco no separa SSIL de MSAA 2x ni de la luz. Un cuarto renglón del banco (alto con `ssil_enabled` falso) cuesta una corrida y evita decidir a ciegas.
3. **Cuadro del banco.** Todos los números de la tabla "Medido en 022b" llevan ±1 ms: ninguna conclusión por debajo de 1 ms (bajo -0,3, medio +0,4) es distinguible del ruido; el RFC ya lo dice.

## Nits

1. `light_look.gd:20-22`: comentario de `sun_fog_energy` incorrecto (ver bloqueante 1).
2. El `FillLight` de `fill_light.tscn` tiene `light_volumetric_fog_energy = 0` pero entra igual en la dispersión de la niebla de profundidad (que recorre todas las direccionales); con relleno 0,25 desde atrás de la cámara no se nota. Anotar si se sube.
3. `look_rig.gd:33-35` libera el rig con `queue_free` en `_ready`; si `ThemeApplier.apply` corre en el mismo cuadro, `LookApplier` aún lo encuentra y `LightLayer` toca sol y entorno en un proceso sin render. Inocuo, pero un `free()` inmediato o un chequeo `is_queued_for_deletion()` en `LookApplier.apply` lo evita.
4. Producto juego: no aplica SQL/XSS/auth. N/A.
5. Alcance: sin extras no pedidos detectados; `LookLayer` y el contrato de capas son la base de 022c-l, razonable.

## ¿Se puede cerrar el RFC 022b?

No todavía. Una corrección (bloqueante 1: densidad volumétrica a ~0,01 expuesta en `LightLook`, con recaptura de `ref` y `rts`) y queda cerrado; lo demás es PASS. Looks, mapa de cada dios y costo son aceptables. El pase visual fino (`studio-visual`) sigue pendiente: GUT/suite no es playtest ni visual.
