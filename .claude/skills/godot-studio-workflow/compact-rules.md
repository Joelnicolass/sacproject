# Estándares para el subagente

Los subagentes **no** ven el chat. El orquestador pega este bloque en el prompt de cada subagente.

```markdown
## Estándares del proyecto

- Autoridad: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFC > plan generado.
- Clean vs estándar y tipo de MP **ya elegidos**: no los cambies. Sin MP → ni addon ni RPCs. Local/WiFi → listen-server. Online → dedicated (`host_dedicated`), no un listen detrás de NAT.
- Composición: contenedor flaco, hijos / packed, `@export` / `%UniqueName`, tipos en Resource `.tres`. Un nodo no pinta + spawnea + puntúa + cambia de escena.
- Copy de UI en el idioma del producto; IDs en inglés. Puntaje/copy/fútbol **fuera** de `addons/mp_kit`.
- Arte: no inventar sprites ni modelos. MCP Aseprite/Blender solo con OK + referencias. Shaders: Godot Shaders / Shadertoy; un pass = packed scene.
- Motion: 12 principios. Tween **o** `AnimationPlayer` según el clip; knobs `@export` / timeline, sin números mágicos. Skill `godot-animation`.
- Juicy (jugoso): shake, VFX, post, impacto = presentación local, packed + `@export`. Skill `godot-juicy` / `/add-juicy`. No es puntaje.
- FSM: hijos `FsmState` bajo `FsmMachine` (addon `fsm_kit` / `/add-state-machine`). No un `enum` de 200 líneas.
- Plataformas 2D: coyote / buffer / apex = `PlatMotor` (addon `plat_kit` / `/add-platformer-2d`). Dash/stamina solo si el producto los pide.
- Playtest ≠ GUT. La escena de prueba es `res://debug/` (la nombra el tech lead, la arma el developer, la revisa el reviewer). El playtester solo escribe `res://agent/flows` y juega con InputMap / click. No `call()` para construir el mundo. No helpers en `src/`. Cubrir **todos** los criterios de **este** slice. Un PNG que no muestra lo que el criterio nombra es FAIL, aunque haya cambiado un número. `ERROR` / `SCRIPT ERROR` / `AGENT_STEP_ERROR` = FAIL. Look (paleta, tipografía) es el pase visual, no este. Visual exige `VISUAL.md` o refs.
- Un RFC, una feature (`/implement-feature`) o un cambio acotado. Extra no pedido = alcance, no “mejora”.
```

Si RULES.md tiene convenciones extra, sumá 3–6 viñetas **de ese archivo**. No pegues skills enteras.
