# Spec + skills (bucle del kit)

La **verdad de producto** está en artefactos versionados. El **cómo** escribir Godot está en `SKILL.md`. Ni un PRD sin skill, ni un skill que invente el juego.

## Spec (qué y por qué)

| Artefacto | Qué es |
|-----------|--------|
| `RULES.md` | Constitución técnica (stack, capas, MP, no-goals de código) |
| `VISUAL.md` | Constitución de look (estilo, refs, jerarquía, no inventar) |
| `FEATURES.md` | El contrato del slice: `F<n>`, criterios, path `res://debug/…` si hace falta, acción del InputMap, observable. Crece con `/implement-feature`. |
| `PRD.md` | Opcional y corto. No es la suite. |
| `RFCs/` | Contrato de un slice grande (opcional). `/implement-feature` no exige RFC. |
| Plan del tech-lead | Árbol de archivos + responsabilidades (derivado; se reescribe si cambia el RFC) |

Código, review, playtest y pase visual se miden **contra** esos archivos, no de oído.

Autoridad: `PRD.md` > `FEATURES.md` > `RULES.md` > `VISUAL.md` > RFC > plan generado.

## Skills (cómo)

| Skill | Cuándo |
|-------|--------|
| `godot-studio-workflow` | Orquestar (este chat) |
| `godot-studio-memory` | Notas entre chats (gotchas, decisiones, próximo paso) |
| `godot-layered-architecture` / `godot-composition-first` | Escribir Godot |
| `godot-playtest` | Lanzar el binario y ejercer la feature (módulo [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)) |
| `godot-visual-qa` | Captura vs `VISUAL.md` |
| `godot-testing` | GUT/GdUnit4 **solo** si el usuario o RULES lo piden |
| `godot-mp-kit` | Solo si hay MP |

Quien **escribe** no se auto-valida. Developer ≠ reviewer ≠ playtester ≠ visual.

Al lanzar un subagente, pegá [compact-rules.md](compact-rules.md) (los subagentes no ven este chat).

## Tres formas de validar

- `studio-tester` + `godot-testing` = runner automático del repo.
- `studio-playtester` + `godot-playtest` = **jugar** la escena del `F<n>` (módulo playtest; si no está instalado, playtest manual o saltear). No pide un segundo OK. La regla viva del playtest está en ese módulo (`evaluate.md`); no la reescribas acá.
- `studio-visual` + `godot-visual-qa` = UI/UX. Sin estilo/refs/`VISUAL.md`, **parar** y pedirlos.

Un review = un pase. Si hay bloqueantes, una corrección; no un loop hasta verde.

## Antes del OK de implementación

El tech-lead **muestra** el [árbol de archivos](file-tree.md). Sin árbol no se pide “implementá”: no se puede juzgar si hay que componer más o menos.
