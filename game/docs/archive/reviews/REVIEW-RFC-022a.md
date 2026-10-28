# REVIEW RFC-022a (andamiaje y medición)

Veredicto: **FAIL con 1 bloqueante** (arreglo de minutos). El resto es PASS o PASS con observaciones.

## Bloqueante

1. **Los cinco `LookProfile` por dios son archivos de 0 bytes y no cargan.** `data/look/{persephone,pyro,james,stratos,charnel}.tres` pesan 0. `load("res://gods/pyro/pyro_look.tres")` da `Parse Error` y `Failed loading resource` y devuelve null (reproducido headless). Rompe el «Resources vacíos» de §3/§14, el botón de vista previa (`look_rig.gd:36`, `LookApplier.profile_for` en `look_applier.gd:11-14` carga ese archivo) y cualquier corte que haga `look = load(...)`. Los themes tienen `look = null`, por eso nada falla hoy y el diff clásico no lo detecta. Corrección: escribir un `[gd_resource type="Resource" script_class="LookProfile" ...]` válido con `god` y `label`.

## Criterios de 022a (§3)

- `look_bench` imprime base por preset y modo de escala: **PASS** (`debug/look_bench.gd:168`; resultados en el RFC «Medido en 022a»). No lo corrí (consume 7,7 GB con 60 cuerpos, como pediste). Ver observación 1.
- Captura clásica idéntica (diff <= 1 %): **PASS**. Comparé yo `agent/out/rfc022/022a_before_still` contra `022a_after_still` (ref, rts, horizonte): 0 % de píxeles con diferencia > 2. Los pares con partículas aleatorias dan 0,1–8,9 %; es ruido de sprites, no del cambio.
- Dedicado sin nodos de `look/`: **PASS**. Headless carga `high_noon` y `Look` queda liberado (`is_instance_valid` = false). Cliente y dedicado (`--dedicated --world=high_noon`) sin errores y con el mismo bioma (james en ambos).
- Presets con escala de render como Resources (`quality_*.tres`, enums correctos: bajo FSR1 0,5; medio MetalFX espacial 0,67 + FXAA; alto 1,0 + MSAA 2x): **PASS**. No hay nadie que los asigne en el juego (`%Look/Quality.quality` = null en `high_noon.tscn`); es coherente con «Nada nuevo» pero el preset no se aplica en una partida normal hasta que un corte lo conecte.

## Lo que pediste verificar

- **`theme_applier.gd` y los biomas**: PASS. Probé los 5 dioses en una instancia de `high_noon`: cada `apply` deja un `Environment` propio (`resource_path` vacío, distinto de `env_base`), con fondo y niebla de su bioma (persephone, pyro, james, stratos, charnel distintos). `env_base.tres` queda intacto tras los 5 (fog, densidad, fondo, ambiente iguales a antes). `match_biome` sortea igual en servidor y cliente (semilla -> `james` en ambos). `debug/biome_pick`, `biome_gallery` y `high_noon` cargan sin errores. Nit: `sky.set(...)` / `has_method` (`theme_applier.gd:32-35`) aflojan el tipado; está bien si la escena tiene un `Sky` instanciado, pero no es de 022a.
- **`env_base.tres` = sub-recurso viejo**: **no verificable por VCS.** La rama `main` no tiene commits y el sub-recurso nunca estuvo commiteado (el índice y el último checkpoint no tienen `Environment` asignado). Lo único que lo respalda es la captura idéntica (arriba), que es evidencia fuerte para tonemap, SSAO, glow y niebla. Pedir al developer que pegue el sub-recurso original. Ver observación 2.
- **`LookRig`**: PASS con nota. `@tool`, sin autoloads: usa `get_node_or_null("/root/MpKit")` (`look_rig.gd:68`), así que corre en el editor. No guarda datos derivados: `profile` no es `@export`; solo `preview_god` y los sockets se serializan. Se libera en headless y si `MpKit.is_dedicated()`. En el dedicado real el flujo llama a `host` en `SacrificeFlow._ready` antes de crear el mundo (primer cliente), por lo que `is_dedicated()` ya es true cuando corre `_ready` del rig; lo verifiqué solo por lectura y en headless, no con ventana (el developer ya avisó). `_get_configuration_warnings` avisa si falta `Layers`. Nota: `LookApplier` no es `@tool`; el botón de vista previa en el editor llama a su método estático y no lo probé en el editor (el usuario lo tiene abierto).
- **`QualityApplier` con `quality = null`**: PASS. `apply()` sale sin tocar nada (`quality_applier.gd:19-21`); tampoco actúa en el editor ni en headless.
- **Acciones de debug**: PASS. Se registran en `look_gallery.gd:157-162` (`InputMap.add_action`) y no están en `project.godot`; solo existen cuando corre esa escena. Ninguna referencia a `look_gallery`/`look_bench` en `project.godot`, `scenes` o `addons`.
- **Composición y `@export`**: PASS. El rig son sockets tipados (`layers`, `quality`), capas = hijos de `Layers`, sin `../..`; `LookProfile` y `LookQuality` son Resources con `@export`; `GodTheme.look` es el único interruptor del modo clásico. Un nodo, una responsabilidad (rig = contenedor + máscara; applier = entrega; quality = viewport).
- **Suite**: `rules_suite` completa, **RULES SUITE PASS**, 0 FAIL. Hay 11 líneas `ERROR: Parameter "material" is null` (render headless/dummy), sin relación con 022a.
- **Higiene del kit**: `rg "func agent_"` en `scenes` vacío (`src` y `glue` no existen en este proyecto). Sin procesos vivos de mis pruebas.

## Validez del método de medición (GPU ms = frame_ms / 9)

Es razonable como **orden de magnitud y para comparar entre modos/presets con el mismo método**, no como milisegundos absolutos. Sesgos:

- **Subestima** el costo de una vista: lo que se hace una vez por cuadro (pase 2D del HUD y presentación, procesamiento del árbol, actualización de partículas y animaciones, cuando hay cuerpos) se diluye en 9. En el banco sin cuerpos es poco; con 60 cuerpos ya no sería despreciable.
- **Subestima** también por ocupación: nueve vistas seguidas mantienen la GPU saturada y tapan burbujas (esperas entre pases) que una sola vista sí paga; el presupuesto de 16,6 ms es de una vista sola.
- **Puede sobreestimar** si el cuello pasa a ser CPU/envío de comandos (9 vistas multiplican draw calls y sombras direccionales por vista) o si hay calentamiento/estrangulamiento del M4 durante los ~45 ms/cuadro: el tiempo no es lineal en vistas.
- Las sombras y SSAO se recalculan por vista, de modo que costos por vista (lo que importa) sí se multiplican bien; pero el uso de memoria (9 render targets 2560x1440 + escalado) altera el ancho de banda respecto de una sola.
- Sin repetición ni dispersión (un solo valor por celda): no sé el ruido entre corridas. Diferencias de 0,3–0,5 ms (FSR 1 vs MetalFX, +0,5 del escalado) están en el borde del error del método. Los temporales se descartaron además por captura, no por milisegundos, y eso es sólido.
- Fuera del rango de validez (`frame_ms` > ~9) no hay problema: los casos miden ~30–80 ms de cuadro.

Conclusión: usar 4,9 ms como línea de base del medio con una barra de error de ±1 ms y repetir cada corte con el mismo método; no comparar con cifras de otros métodos.

## Observaciones (no bloquean)

1. `debug/look_bench.gd:31` deja `unit_count := 60` por defecto: F6 sobre `look_bench` o el flow dispara los ~7,7 GB de memoria de video del hallazgo ajeno. Sugiero default `0` hasta que se arregle `obj_mesh`/`clip_pose_player`, y que el 60 sea opt-in con `--units=60`. Además, la tabla del RFC mide sin cuerpos pero §4 describe el banco con 60: dejarlo coherente.
2. `env_base.tres` trae `tonemap_mode = 4` (AgX), `ssao_enabled`, `glow_enabled` y `volumetric_fog_enabled`, que el RFC programa para 022b/022f/022h. Si eso ya estaba así antes, la línea de base de 4,9 ms ya incluye SSAO, glow y volumétrica, y los +2,0 / +2,0 / +0,6 de esos cortes se doblan contra la base. Aclarar en el RFC si la base los incluye, o medir con ellos apagados.
3. `LookRig._ready` libera el rig en cualquier proceso headless (`look_rig.gd:25-26, 66-67`), no solo en el dedicado: las pruebas headless futuras (suite) no podrán ejercitar capas ni `apply_profile`. Aceptable (presentación pura), pero 022b+ debe probar sus Resources sin el rig.
4. No hay captura de ventana del dedicado real; el criterio «sin nodos de `look/`» quedó verificado headless y por lectura de `is_dedicated()`.
5. `debug/biome_pick.tscn` referencia `uid://highnoonworld01` y `high_noon.tscn` tiene ahora otro uid (el editor lo regeneró); carga por ruta, pero la advertencia de uid puede aparecer en el editor.
6. VISUAL.md: 022a no cambia nada visible; no hay hallazgo visual (el look queda para `studio-visual` al cierre del slice, 022i).

## Alcance

Sin extras no pedidos en el RFC: los archivos nuevos y modificados coinciden con la lista del árbol de §5 para 022a.

## ¿Cerrado?

No todavía: falta arreglar el bloqueante 1 (cinco archivos). Con eso y la aclaración de la observación 2 en el RFC, 022a se puede dar por cerrado. No hace falta otra pasada completa; basta verificar que `load()` de los cinco `.tres` devuelva un `LookProfile`.
