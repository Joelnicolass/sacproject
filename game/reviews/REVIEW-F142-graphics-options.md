# REVIEW F142 (031c): Opciones → Gráficos

**Veredicto: PASS.** No hay bloqueantes. El revisor es de solo lectura, así que este informe lo guardó el orquestador (2026-10-16).

**Primer paso:** `WorldInput` es el único dueño. Los 5 lectores lo consultan y ya no queda el literal `menu_open` en ningún lector de producto.

**Criterios 1-6:** PASS. El 1 sale del log del developer: 46 ms de `apply_quality` y 144 ms en el peor cuadro.

**Determinismo:** ninguna simulación lee `LookQuality`, el pasto ni `max_fps`. `LookRig` se libera en headless y en el dedicado, así que los digests no dependen de las preferencias.

**Composición:** las perillas están en `GraphicsPrefs` (`.tres` y `@export`). El menú no copia campos de `LookQuality`. No hay API de producto que use solo el harness y `unit_body.gd` no se tocó.

**`owner == current_scene`:** es robusto. `ai_match` instancia el mundo con `add_child`, así que no le aplica el preset del jugador.

## Notas
1. **Seguridad de la Mac (recomendada).**
   - **Problema:** `_apply_window` corre en todas las escenas y `settings.cfg` lo comparten el jugador y los agentes. Si el jugador elige sin VSync y sin tope, eso llega a los playtests.
   - **Corrección:** el orquestador pidió aplicar la ventana solo en partida o en el boot, y dejar el applier inerte bajo AgentKit.
2. **Atomicidad.** `ConfigFile.save` escribe sobre el archivo. **Corrección pedida:** guardar en `.tmp` y después renombrar.
3. **Doble oscurecido.** La pausa (0,55) y las opciones (0,55) quedan una sobre otra. **Corrección pedida:** ocultar el oscurecido de la pausa.
4. **Pasto en 0 celdas mientras la partida está en pausa.** Se rehace en `_process`. Se acepta y queda anotado.

## Nits
- Los harness de F141 usan el literal del grupo.
- `GraphicsPrefs` parsea el archivo unas 5 veces.
- `GraphicsTab._fill` pisa el `step` del slider definido en el `.tscn`.
- No hay flow que cubra Esc con las opciones abiertas.
- Hay `.uid` sin commitear.
