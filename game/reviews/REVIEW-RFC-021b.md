# REVIEW RFC-021b (F63, Guardian)

Veredicto: **PASS con observaciones**. Sin bloqueantes. Una pasada, solo lectura. Guardian sigue a sacengine (decision del usuario; nada verificado contra Sacrifice.exe).

## Evidencia ejecutada
- `rules_suite` completa (`--headless --fixed-fps 600 --quit-after 600000`): **RULES SUITE PASS**, incluye `guard_split`, `guard_factors`, `guard_leash`, `guard_release`, `guard_action`, `guard_selection`. Cero ERROR en el log.
- Carga headless 300 frames, exit 0 y 0 errores: `desecrate_ritual`, `convert_ritual`, `structure_siege`, `guardian_altar`, `guardian_manalith`.
- `rg -n "func agent_" scenes` : vacio. Sin procesos Godot vivos salvo el editor del usuario.
- No corri los flows de red `f63_*` (eso es del playtester); existen `f63_client_a/b/late`, `f63_guardian_{altar,manalith,look}`.

## Citas a state.d (verificadas contra `sacengine/source/state.d`)
| Dato | Cita real | Estado |
|---|---|---|
| radio 50 para armar | 28082 (`candidateDistance>50.0f^^2`) | OK |
| x1,5 de dano | 8884 (`isGuardian result*=1.5f`) | OK |
| x0,5 hechizo / x0,25 distancia | 9006-9009 | OK (el RFC decia 9006-9009; el dev cita 9007-9008, correcto) |
| curacion 1000/(60*FPS) | 14407-14408 | OK = 16,667/s |
| altura Manalith 15 / altar 2,5 | 15344-15345 | OK |
| correa 50 / vuelta 20 | 15366 / 15367-15368 | OK; mide centro de la criatura vs punto de enganche, igual que el original |
| canTeleport | 10309 | OK (grupo `rooted`) |
| reparto | 9101: `damage/min(n, 0.5*(n+3))` | OK: n=1..5 -> 1, 2, 3, 3.5, 4 (`GuardPost.split_divisor`, probado en `guard_split`) |
| guardian() / validez | 10398-10414, isValidGuard 15352-15355 | OK |

## Criterios 021b
| Criterio | Evidencia | Resultado |
|---|---|---|
| Sin edificio propio a <=50: "Lejos de un edificio propio" | `guardian_action.gd` `arm_status` via `GuardPost.closest(..., radius)` | OK |
| No criatura propia libre: "Blanco inválido"; >40: "Fuera de alcance" | `check`: arm -> `can_guard` -> `standing_status` (orden correcto) | OK (suite `guard_action`) |
| Atada al edificio mas cercano a la criatura, sale de la seleccion, haz en los dos clientes | `finish` -> `GuardPost.closest(target.pos)` -> `bind`; `_apply_post` en todos los pares hace `call_group("selection","drop")` e instancia el haz (`post_path` en `unit.tscn` prop 12, spawn=true) | OK por codigo y suite; red no corrida por mi |
| x1,5 / x0,5 / x0,25 / cura / sin habilidad | `_apply_effects`: `kind_factors`, `attack_factor`, `ability.locked`, `heal` en `_physics_process` | OK |
| Manalith con guardian no pierde vida | `structure.tscn` `Health.deflector = ../GuardPost`; `GuardPost.deflect` | OK |
| Vuelve a 20 del edificio a >50; se libera al morir / caer el edificio; haz 1 s | `_keep_near`, `release()`, `GuardianTether.retire` (withdraw_s 1.0) | OK por suite (el dev lo admite: no probado en red) |

## Puntos pedidos en especial
- **`Health.deflector`/`kind_factors` y dano existente**: `kind_factors` vacio = factor 1, sin cambio. `damage()` (crudo: drenaje del ritual, `ritual.gd:169` sobre el Health del mago) consulta `_deflect` pero el mago/doctores/criaturas no tienen deflector, asi que no cambia nada; no aplica resistencias ni `kind_factors`. `desecrate_ritual`, `convert_ritual`, `structure_siege` cargan sin errores y la suite pasa. Unico caller de `damage()` sobre un Health con deflector seria futuro: seria tratado como MELEE.
- **Recursion**: el guardian es una criatura cuyo `Health.deflector` esta vacio (solo `structure.tscn` lo asigna), asi que `GuardPost.deflect -> bond.health.damage_typed` no puede reentrar. No hay guarda de reentrancia (nit 4).
- **Autoridad y replica**: `bind/release/deflect/_keep_near` exigen autoridad (`_has_authority`); `post_path` replicado con `spawn=true` y setter que re-aplica en `_ready`/cambio; cliente tardio resuelve el haz con `get_node_or_null` perezoso.
- **Limpieza**: criatura muerta -> `is_valid_guard` falso -> `release()` (unbind, quita `rooted`, `post_path` vacio, haz se retira). Edificio caido -> `is_open()` falso -> mismo camino. `_exit_tree` desengancha del post; `GuardPost._prune` tolera instancias liberadas; el haz es hijo del bond (no huerfano) y se libera solo al terminar.
- **selection.gd**: `drop()` borra de `_units` y grupos, desmarca y emite `changed`; doble clic: guardianes del mismo edificio entre si, no mezclados con libres (`guard_selection` PASS).
- **Composicion**: `caster.gd` no nombra `ndrg` ni ramas por tag para Guardian (lo resuelve `action_for`); piezas con `class_name`; sockets `@export` con `_get_configuration_warnings`; nada de presentacion en el dedicado (`BodyCatalog.loads_meshes()` antes de instanciar el haz); `@tool` con accesos a `MpKit`/`BodyCatalog` solo tras `Engine.is_editor_hint()`/runtime. Numeros en `MatchRules` grupo "Guardián" con cita. Sin `get_node("../..")` entre sistemas; el post se busca por grupo `guard_post`.
- **Escenas debug**: `guardian_altar.tscn` deja a `Guard1` sin `post_path` ni haz (el resultado no esta puesto); instancia `unit.tscn`/`high_noon.tscn`; `guardian.tres` es solo reglas.

## Observaciones (no bloqueantes)
1. **Textura `grdn`: si se puede sacar del original.** `sacobject.d:4466` la carga de `extracted/charlie/Bloo.WAD!/Misc.FLDR/txtr.FLDR/grdn.TXTR`. `tools/export_particles.py` ya exporta TXTR del instalador local a `cache/look/fx/<tag>.png` con la tabla `ATLASES` `(wad, carpeta)`; bastaria una entrada `"grdn": ("charlie.wad", "Bloo.WAD!/Misc.FLDR/txtr.FLDR")` (no la corri) y usarla en el material del haz. El comentario "no esta en el repo" de `guardian_tether.gd` es inexacto: el repo tampoco trae las demas, vienen del cache. El haz placeholder queda como pendiente de look (`studio-visual`/RFC aparte).
2. **Haz en cliente tardio** (`guardian_tether.gd`, `_process`, rama `STEADY and _post() == null`): si el cliente recibe `post_path` antes de que exista el nodo del edificio y pasa 1 s, el haz se retira y se libera para siempre aunque el vinculo siga. Ademas, si la criatura se libera del arbol, el haz (hijo del bond) desaparece sin la retirada de 1 s. Cubrir con `f63_client_late` en el playtest.
3. Desvio declarado (golpe cuerpo a cuerpo desviado llega con la resistencia del edificio ya aplicada y sin el 0,4 de `dealDamage`): coherente con que `Health._deflect` corre antes de las resistencias del propio Health; no lo verifique contra los callers de `melee_attack.gd`. Aceptable y documentado.
4. Nit: `Health._deflect` sin guarda de reentrancia; hoy imposible, pero un futuro `deflector` en una criatura podria recursar.
5. Nit de estilo: `guardian_tether.gd` declara `enum Phase` antes de los `@export` y `var _shape_cycle` en medio del archivo (despues de `_control_points`).
6. Alcance: `caster.gd` y `unit_body.gd` en el arbol de trabajo traen cambios ajenos a 021b (fuego/rayo/enjambre en `IMPLEMENTED`, `HELD/REVIVING`, `accept_command`), de otros RFC en curso; no atribuibles a 021b.
7. Liberacion del guardian y retirada del haz solo probadas por suite, no en red (declarado por el dev).

## Cierre
RFC-021b se puede dar por cerrado en revision de implementacion, sujeto a que el playtester confirme con captura el haz en ambos clientes y en el cliente tardio (`f63_client_a/b/late`). El look del haz queda para `studio-visual`.
