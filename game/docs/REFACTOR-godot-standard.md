# Refactor a estándar Godot (rama `refactor/godot-standard`)

2026-10-28. Pedido del usuario: un archivo de reglas según los estándares de Godot, más iterar el refactor del plan de `docs/AUDIT-code-quality.md` en una rama aparte, sin aprobaciones y **sin merge a `main`**. Son 44 commits sobre `refactor/new-systems`, todos pusheados a `origin/refactor/godot-standard`.

## Las reglas nuevas

[`CONTRIBUTING.md`](../CONTRIBUTING.md), en inglés y con fuentes oficiales. Gana sobre `CONVENTIONS.md` y `RULES.md`, que quedan como referencia.

| Sección | Qué dice |
|---|---|
| §0 | Simple y predecible. El valor vive en el nodo que lo usa; un `.tres` solo si es compartido; nada de punteros por tag; si cambiar un número abre más de 2 archivos, está mal |
| §2b | Patrones probados: señales, «signal up, call down», bus `Events`, FSM, componentes, command, pool y spawner |
| Resto | Autoloads mínimos, GDScript (orden, nombres, tipado real), `##` solo para API, código y logs en inglés, herramientas |

## Qué cambió

| Corte | Resultado |
|---|---|
| Q1 Código muerto | Fuera `AiAudit` (480 líneas y 32 enganches), las señales del banco, los `debug_*` de los cuerpos, `SpellAction.prompt` en 48 escenas y `CommandLog.text` |
| Q2 Herramientas | `gdlintrc`; avisos `UNSAFE_*` y `UNTYPED_DECLARATION` activos; lint propio podado (C1, C9, C24 fuera); CI en `.github/workflows/godot-checks.yml` |
| Q10 Tests | GUT 9.7.1; 9 archivos y **60 tests** de reglas puras y del daño en `test/unit/` |
| Q5 Aflicciones | Una sola `afflictions.tscn` para criatura y mago, antes copiada a mano. `unit.tscn` pasa de 126 a 89 entradas; las luces son nodos visibles |
| Q7 `BookEntry` | Base común de `SpellType`, `AbilityType` y `CreatureType`; `Caster` y `CastTime` tipados; la regla del Basilisco pasa a un campo (`cast_time_factor`) |
| Q4 Acceso tipado | `MatchWorld` con `@export`; grupos como constantes y Global Groups (57); una sola frecuencia de tick; 11 archivos renombrados como su clase |
| Docs | `docs/architecture.md`; READMEs cortos (47 reescritos, 9 borrados); RFCs y changelog movidos a `docs/archive/` |
| Q9 Pasivas | Cada criatura lleva sus pasivas en `scenes/units/bodies/<criatura>_passives.tscn`. Para la furia del Firefist hoy se abre **1 archivo**; antes eran 7 y un grep |
| Q8 Referencias | Proyectiles, disparos, gotas y espíritus elegidos por `PackedScene`, no por texto; contrato tipado `ProjectileLaunch`. La bola de fuego se cambia abriendo 2 archivos; antes eran 10 u 11 |
| IA | Enums en vez de códigos 0/1/2; 20 helpers sueltos plegados en su dueño (35 → 15); `data/ai` sin comentarios `;` |
| Q6 Cuerpos | Contrato `GameBody` para criatura, mago y doctor; `# dynamic:` (has_method/call) pasa de 40 a 4. Después, el mago usa componentes: `WizardClips`, el `Regeneration` compartido y `GroundSeat`, con los umbrales en el inspector. `wizard_body.gd` pasa de 517 a 399 líneas |
| Bus `Events` | `body_hurt`, `ritual_started`, `ritual_ended` y `match_ended`; audio, HUD, cámara y FX dejaron de sondear el árbol (15 búsquedas menos) |
| Q11 Partida | `match.tscn` en 5 grupos (World, Systems, Input, Hud, Audio); fuera el autoload `GameData`; el spawner le inyecta el pick al mago |
| Política de blanco | Cuelga de la habilidad (`target_policy`), sin ruta armada con el tag |
| Q3 Comentarios | Más de 1 200 citas al original movidas a [`docs/original-mapping/`](original-mapping/). No queda ninguna cita a RFC en el código; `##` dentro de funciones → `#`; logs y avisos en inglés |
| Fase B Nombres | 149 archivos con códigos pasan a nombre humano (`brif.tres` → `fireball.tres`, `ahtf.tres` → `firefist_fury.tres`); el catálogo por tag queda idéntico |
| Q13 Vida | `Health` recorre una cadena de `DamageModifier`; ya no conoce 8 tipos. 21 tests fijan la matemática y dieron igual antes y después |
| Q12 Estado | El reloj, la semilla, el cielo, los bandos y la vista de los bandos viven en `Match/Context` y se liberan con la partida; `ActiveMatch` pasa a `SacrificeFlow.active_match` |
| Formato | gdformat en 571 archivos; gdlint de **5 088 avisos a 0**; el CI bloquea con lint y formato |
| Bugs que aparecieron | La IA preguntaba si un nodo liberado estaba muerto (SCRIPT ERROR intermitente); `GrassField` quedaba pegado al primer mapa; el aura del Manahoar convertido alimentaba al bando viejo |

## Cómo se verificó

| Prueba | Resultado |
|---|---|
| Import headless y carga de los 848 scripts uno por uno | 0 errores |
| GUT | 60/60 |
| `conventions.sh` | 0 FAIL |
| gdlint / gdformat | 0 avisos / sin cambios |
| Partida «Contra la IA» headless con semilla 7 | Mismo hash de posiciones, ticks y lanzamientos antes y después de Q12, Q13 y el formato |
| Dos partidas seguidas en el mismo proceso | Arrancan limpias |
| LAN con 2 procesos (dedicado con IA + cliente) | El pick llega al cliente; bola de fuego y disparos de criaturas por ruta de escena: PASS, sin SCRIPT ERROR. Repetida después de Q12: PASS |

## Lo que no se probó

- No se jugó con ventana: no hay control visual de las luces de las aflicciones, del árbol de `match.tscn` en el editor ni del inspector.
- No se probó online contra el relay de Fly, solo LAN.
- `LightningCharge:shown = true` no se vio en el cliente.

## Pendientes

Los puntos de red están anotados en [`TECH-DEBT.md`](TECH-DEBT.md).

| Tema | Qué falta |
|---|---|
| `wizard_body.tscn` | El kit avisa en runtime que la MpSync guardada está desactualizada; abrir la escena en el editor y guardarla |
| Clases grandes | `UnitBody`, `DoctorBody`, `BodyRig`, `AiPerception` y `tools/bake/new_creature.gd` tienen ignores justificados de gdlint; conviene partirlas por responsabilidad (`WizardBody` ya bajó a 20 métodos públicos) |
| Carpeta por entidad | Q14 sin hacer (el Firefist todavía vive en varias carpetas) |
| Logs del servidor | Siguen en español los que documenta la guía de despliegue (`salas listo puerto`, `partida …`) |
| Códigos sin identificar | `data/catalog/abilities/dhsf.tres` y `othg.tres` |
| Kit de skills | RC v0.19.0 con la skill `godot-code-quality`, commiteada en `rc/v0.19.0` y `rc/v0.19.0-spanish` y **sin pushear** (worktrees en el scratchpad) |
