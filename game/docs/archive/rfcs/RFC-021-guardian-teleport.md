# RFC-021 — Guardian y Teleport (pestaña Estructuras)

Plan del tech lead. Estándar, MP online dedicado. No cambia arquitectura ni agrega RPC de cliente.
Fuentes: **[S]** sacengine `source/` (archivo:línea), **[D]** `game/cache/data/spells.json`. Ghidra no hizo falta: no se usó. Lo que dice «sin verificar» es comportamiento de sacengine no contrastado con `Sacrifice.exe`.

## 0. Hallazgos

### Guardian (`ndrg`)
1. **El blanco es una criatura propia; el edificio no se elige.** [D] `flags 1835012` = `targetCreatures | onlyCreatures | onlyOwned | disallowHero` ([S] `spells.d:168-183`), los mismos de Desecrate. `flags2 256` = `nearBuilding`. `exclusion_tags: ["ndrg"]` = no a una que ya es guardiana.
2. **Dos distancias distintas.** Para armar, el *mago* necesita un edificio propio (altar, shrine o Manalith) a ≤ 50 en planta; si no, `mustBeNearBuilding` ([S] `state.d:28064`, `28082`, `29561`; el ícono se apaga, `renderer.d:4930`). La criatura tiene que estar a ≤ 40 del mago ([D] `range 40`, [S] `state.d:29552`). Al terminar el casteo, la criatura queda atada al edificio propio **más cercano a ella**, sin tope de distancia ([S] `findClosestBuilding`, `state.d:10371-10396`, `10404`).
3. **Excluidos:** mago, héroe, familiar, Sac Doctor, la que ya es guardiana ([S] `sacspell.d:168`, `state.d:10401-10402`) y la que está siendo sacrificada (`isApplicable`, `sacspell.d:63`).
4. **Qué gana la criatura** [S]: pega ×1,5 (`state.d:8884`; veneno `9416`); recibe ×0,5 de hechizos y ×0,25 de ataques a distancia, cuerpo a cuerpo igual (`9006-9009`); se cura 1000/min = 16,67 de vida/s además de su regeneración (`14407-14408`); pierde su habilidad activa (`1414`), el sigilo (`25071`) y hacerse la muerta (`14069`); no se teletransporta (`10309`).
5. **Qué gana el edificio** [S]: mientras tenga un guardián válido no recibe daño; cada guardián recibe `daño / min(n, 0,5·(n+3))` con sus propias resistencias (`state.d:9098-9117`, `9194-9212`). Sin tope de guardianes por edificio (`Array guardianIds`, `1663`).
6. **Atadura** [S]: al atarla se deselecciona, sale de los grupos y pierde sus órdenes (`10408-10410`). Después **se puede volver a seleccionar y ordenar** (`canSelect`/`canOrder`, `1134-1141`, no la excluyen; doble clic junta a los guardianes del mismo edificio, `29884-29896`). Si queda a más de 50 del punto de enganche, recibe una orden de moverse a 20 del edificio (`15364-15376`). sacengine anota `// TODO: bind creature to building` (`15393`): **la atadura dura del original no está verificada.**
7. **Se libera** solo si muere, cambia de bando, entra en `thrashing` (la toma un doctor) o desaparece el edificio (`isValidGuard` `15352-15355`, `15362-15391`). No hay hechizo ni orden para soltarla (sin verificar en el original).
8. **Números** [D]: maná 300, casteo 1,11 s (mínimo 0,56 con nivel), enfriamiento 2 s. **Se ve** [S]: partícula `heal` en el mago al castear (`15289-15291`); un haz de 19 segmentos, textura `grdn.TXTR`, de la criatura al edificio (+15 de alto en Manalith, +2,5 en shrine/altar, `15344-15350`), que aparece en 1 s, se sacude cada 1 s y se retira en 1 s (`2772-2784`, `sacobject.d:4462-4475`).

### Teleport (`elet`)
1. **El blanco es un edificio aliado.** [D] `flags 4112` = `targetStructures | onlyAlly`. Vale cualquier edificio aliado con vida o que sea altar ([S] `state.d:30786-30790`): Manalith, altar, shrine. Un manantial libre es neutral: no. Alcance 5000 [D] = todo el mapa.
2. **Viajan el mago y todas las criaturas de su bando a ≤ 30 de él** ([D] `effect_range 30`; [S] `teleport`, `state.d:10313-10327`), **manteniendo la formación** (`nueva = pos − inicio + destino`, `10317`). No viajan: muertas, Sac Doctor, guardianas (`canTeleport`, `10306-10311`).
3. **Destino:** a 30 del edificio, del lado desde el que venía el mago; si ahí no hay suelo, la posición del edificio ([S] `getTeleportPosition`, `10215-10228`). Una criatura no voladora cuyo lugar no tiene suelo cae en el destino del mago (`10318-10320`). Las voladoras conservan su altura (`10262-10263`).
4. **Tiempos:** maná 800, casteo 1,23 s (mínimo 0,62), enfriamiento 15 s [D]. El salto es instantáneo al terminar el casteo. El destino se recalcula cada cuadro; si el edificio cae a mitad de casteo, se usa el último destino y el salto ocurre igual (`16056-16072`). Interrumpido: no pasa nada.
5. **Órdenes:** las criaturas pierden sus órdenes salvo guardia o retirada (`10260-10261`).
6. **Se ve** [S]: en origen y destino, por cada cuerpo, 0,53 s de anillos azules que suben o bajan (cada anillo vive 0,8 s) y 50 partículas `heal`; sonido `elet` (`10237-10253`, `16074-16101`).
7. **Fantasma:** no castea (regla ya vigente, `wizard_can_cast`). **Bajo ritual:** sin restricción; teletransportarse al altar propio es la defensa natural.

### Sin verificar
Atadura dura, liberación y tope de guardianes en el original; que una criatura cautiva viaje con Teleport (sacengine no la excluye; ver riesgo 3); bits desconocidos de `flags1` (8224 y 8272); escala del casteo por nivel (el port usa `casting_time_s`, como el resto del libro); apuntar Teleport por minimapa.

## 1. Sub-cortes

| Sub-corte | Qué cierra | Depende de | Feature |
|---|---|---|---|
| **021a** Despacho de la pestaña | Contrato `SpellAction`, Manalith migrado, clic según `pick` | nada | F62 |
| **021b** Guardian | `GuardPost`, `GuardianBond`, haz, modificadores | 021a | F63 |
| **021c** Teleport | `TeleportAction`, `TeleportMath`, `warp_to`, efecto | 021a (el filtro de guardianas, 021b) | F64 |

### Criterios de aceptación
**021a (F62)**
- Manalith se arma, se coloca y se replica igual que hoy (F34, F46): mismos mensajes, mismo `submit_structure`.
- `caster.gd` y `match_command.gd` no nombran ningún tag de la pestaña Estructuras para decidir el blanco; lo decide el `pick` de la acción.
- Una casilla sin acción responde «No implementado» (hoy: `ndrg`, `ccas`, `ucas`, `elet`).

**021b (F63)**
- Sin edificio propio a ≤ 50 del mago: «Lejos de un edificio propio». Clic sobre algo que no es una criatura propia libre: «Blanco inválido». A más de 40: «Fuera de alcance».
- Al terminar el casteo la criatura queda atada al edificio propio más cercano a ella, sale de la selección y se ve el haz en los dos clientes.
- Atada: pega ×1,5, recibe ×0,5 de hechizos y ×0,25 a distancia, se cura 16,67/s, no usa su habilidad.
- Un Manalith con guardián no pierde vida; la pierde el guardián.
- A más de 50 del enganche vuelve sola a 20 del edificio. Se libera al morir o al caer el edificio; el haz se retira en 1 s.

**021c (F64)**
- Clic sobre un Manalith o altar propio en pie, a cualquier distancia: el mago y sus criaturas a ≤ 30 aparecen a 30 del edificio con la misma formación. Cuesta 800 y enfría 15 s más el casteo.
- No viajan: guardianas, criaturas a más de 30, doctores, muertas.
- Otro blanco: «Blanco inválido». Mago muerto a mitad de casteo: nadie se mueve.
- Los dos clientes ven el salto y el efecto en origen y destino.

## 2. Escenas de prueba y flows

| Escena | Instancia | Estado inicial | Qué NO está cumplido | Acción |
|---|---|---|---|---|
| 021a: ninguna nueva. Usa `debug/cast_heal.tscn` y `debug/structure_siege.tscn` | — | el de F34/F46 | no hay `Structure1` | pestaña Estructuras, `spell_1`, clic en el suelo |
| `debug/guardian_altar.tscn` (021b) | High Noon + `debug/rules/guardian.tres`; Rangers propios `Guard1`, `Guard2` a 10 m del mago (altar propio a 15); Rangers enemigos `ShooterA`, `ShooterB` (slot 2, `idle_aggro`), uno frente a cada uno | maná lleno, nadie atado | `Guard1/GuardianBond.post_path` vacío, sin haz | Estructuras, `spell_2`, clic sobre `Guard1` |
| `debug/guardian_manalith.tscn` (021b) | hereda `structure_siege.tscn` + un Ranger propio `Guard1` junto al manantial 1 | sin Manalith, `Sieger` enemigo a 14 m | sin estructura ni guardián | `spell_1` + clic (Manalith, 11 s); luego `spell_2` + clic en `Guard1` |
| `debug/teleport_home.tscn` (021c) | High Noon + `debug/rules/teleport.tres`; mago a ~80 m de su altar con el altar a la vista; `Pack1..3` a < 30 m, `Stray` a 60 m | maná lleno | todos lejos del altar | Estructuras, `spell_5`, clic sobre el altar propio |

Resultado esperado: en `guardian_altar`, tras 6 s `Guard2` perdió unas 4 veces la vida que perdió `Guard1`. En `guardian_manalith`, `Structure1/Health.current` deja de bajar y baja la de `Guard1`. En `teleport_home`, mago y `Pack1..3` quedan a 30 ± 12 m del altar y `Stray` no se movió.

**Flows** (`agent/flows/`, patrón `pt57_client_a/b.json`): `pt62_manalith.json` (solo); `pt63_guardian.json` (solo), `pt63_client_a.json` / `pt63_client_b.json` (dedicado + 2 clientes en `--world=res://debug/guardian_manalith.tscn`: A castea, B comprueba el haz, `post_path` y la vida del Manalith); `pt64_teleport.json` (solo), `pt64_client_a.json` / `pt64_client_b.json` (A castea, B ve las posiciones nuevas de mago y criaturas).

**Casos de `debug/rules_suite` (sin red):** `action_lookup`, `manalith_action`; `guard_split` (n = 1..5), `guard_factors`, `guard_leash`, `guard_release`; `teleport_landing`, `teleport_offsets`, `teleport_carry`.

## 3. Árbol de archivos

```text
game/
├── data/match_rules.tres                       MOD  b,c  grupos «Guardián» y «Teleport»
├── scenes/data/match_rules.gd                  MOD  b,c
├── scenes/world/spells/
│   ├── caster.gd                               MOD  a    tabla de acciones; − código de Manalith
│   └── actions/
│       ├── spell_action.gd                     NUEVO a   class_name SpellAction (contrato)
│       ├── manalith_action.gd                  NUEVO a   class_name ManalithAction
│       ├── guardian_action.gd                  NUEVO b   class_name GuardianAction
│       ├── teleport_action.gd                  NUEVO c   class_name TeleportAction
│       └── teleport_math.gd                    NUEVO c   class_name TeleportMath (static)
├── scenes/world/guardian/
│   ├── damage_deflector.gd                     NUEVO b   class_name DamageDeflector (contrato)
│   ├── guard_post.gd                           NUEVO b   class_name GuardPost
│   ├── guardian_bond.gd                        NUEVO b   class_name GuardianBond
│   ├── guardian_tether.tscn / .gd              NUEVO b   class_name GuardianTether
├── scenes/world/wizard/wizard_body.tscn        MOD  a,b,c  Caster/Actions/{Manalith, Guardian, Teleport}
├── scenes/world/wizard/wizard_body.gd          MOD  c    warp_to()
├── scenes/world/unit_body.gd                   MOD  b (attack_factor) · c (warp_to)
├── scenes/world/units/unit.tscn                MOD  b    + GuardianBond; post_path al sincronizador
├── scenes/world/units/melee_attack.gd          MOD  b    × attack_factor
├── scenes/world/units/ranged_attack.gd         MOD  b    × attack_factor
├── scenes/world/units/active_ability.gd        MOD  b    locked
├── scenes/world/components/health.gd           MOD  b    kind_factors, deflector
├── scenes/world/structures/structure.tscn      MOD  b    + GuardPost (attach_height 15)
├── scenes/world/props/altar.tscn               MOD  b    + GuardPost (attach_height 2.5, altar)
├── scenes/world/selection.gd                   MOD  b    drop(unit); guardianes aparte en el doble clic
├── scenes/world/match_command.gd               MOD  a    clic por pick; + _building_under
├── data/particles/teleport_out.tres, teleport_in.tres   NUEVO c  ParticleType (placeholder)
├── FEATURES.md                                 MOD       F62, F63, F64
└── debug/
    ├── guardian_altar.tscn, guardian_manalith.tscn      NUEVO b
    ├── teleport_home.tscn                               NUEVO c
    ├── rules/guardian.tres, rules/teleport.tres         NUEVO
    └── rules_suite.gd                                   MOD  a–c
```

```text
wizard_body.tscn                    unit.tscn                     structure.tscn / altar.tscn
Caster                              Unit                          Structure | Altar
└── Actions (Node)                  └── GuardianBond              └── GuardPost
    ├── Manalith  (ManalithAction)      └── (GuardianTether, instanciado
    ├── Guardian  (GuardianAction)           al atarse, solo con ventana)
    └── Teleport  (TeleportAction)
```
No hay nodo nuevo en `high_noon.tscn` ni sistema global.

### Mapa de responsabilidades

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `SpellAction` | Contrato de un hechizo «con procedimiento»: `tag`, `pick`, `prompt`, `arm_status`, `check`, `begin`, `finish`, `cancel` | Nodo base, hijo de `Caster/Actions` | Es lo que evita el `if tag ==`; `Caster` solo busca por tag |
| `ManalithAction` | Manantial libre más cercano, lugar libre, spawn del edificio | `SpellAction` | Son ~90 líneas que hoy viven en `caster.gd` (`_structure_model`, `_can_place_structure`, `_closest_free_manafount`, `_spawn_structure`, 4 `_pending_*`) |
| `GuardianAction` | Reglas de Guardian: edificio a ≤ 50 del mago, criatura válida, elegir el puesto más cercano a la criatura y atarla | `SpellAction` | No sabe de daño ni de haz |
| `TeleportAction` | Reglas de Teleport: blanco válido, quién viaja, mover y avisar el efecto | `SpellAction` | Mueve cuerpos; no calcula |
| `TeleportMath` | Cuentas puras: destino, traslado en formación, radio | `static` | Se prueba en `rules_suite` sin mundo |
| `DamageDeflector` | Contrato: `deflect(amount, kind, from_slot) -> float` (`NAN` = no desvié) | Nodo base | `Health` no tiene que conocer a los guardianes |
| `GuardPost` | «Este edificio acepta guardianes»: dueño, punto de enganche, lista de atados, abierto o no, y el reparto del daño | Hijo del edificio | Shrine lo suma como hijo. Sacarlo = ese edificio no se puede guardar |
| `GuardianBond` | La criatura atada: `post_path` replicado; en el servidor aplica y quita modificadores, cura, correa y validez | Hijo de `unit.tscn` | Es el comportamiento removible; `unit_body.gd` solo gana una variable |
| `GuardianTether` | El haz, en cada peer, según `post_path` | Packed | Presentación; el dedicado no lo instancia; se ajusta en el inspector |
| `Health` (mod) | Suma `kind_factors` (factor por tipo de daño) y socket `deflector` | Nodo existente | Dos ganchos genéricos; ninguna regla de Guardian adentro |
| `Caster` (mod) | Casteo, maná, enfriamiento; reparte en la acción del tag | Nodo existente | Baja de 666 líneas |
| `match_command.gd` (mod) | Traduce el clic según `pick`: suelo, criatura propia, alma, edificio propio | Nodo existente | Deja de preguntar por tag |

## 4. El despacho de la pestaña para los cinco

`SpellAction.Pick { GROUND, OWN_UNIT, SOUL, OWN_BUILDING }`. `Caster` arma en `_ready` un diccionario `tag → SpellAction` con los hijos de `Actions`.

| Hechizo | Acción | `pick` | Quién la crea | Viaja por |
|---|---|---|---|---|
| Manalith `htlm` | `ManalithAction` | GROUND | 021a | `submit_structure(index, point)` (sin cambio) |
| Guardian `ndrg` | `GuardianAction` | OWN_UNIT | 021b | `submit_cast(tag, point, path)` |
| Convert `ccas` | `ConvertAction` | SOUL | **020e** | `submit_cast` |
| Desecrate `ucas` | `DesecrateAction` | OWN_UNIT | **020c** | `submit_cast` |
| Teleport `elet` | `TeleportAction` | OWN_BUILDING | 021c | `submit_cast` |

- `structure_status(index)`: maná, enfriamiento y `action.arm_status()`; sin acción, «No implementado».
- `_try_cast` y `_try_structure` terminan en un solo `_try_action(spell, point, path)`: `check` → `_start` → `begin`; `_finish` → `action.finish`; `_interrupt` → `action.cancel`.
- `match_command._arm_structure` muestra `action.prompt` («Elegí el suelo», «Elegí una criatura propia», «Elegí un edificio propio»); `_structure_at` hace un `match` sobre `pick`, no sobre el tag. Las ramas `CONVERT` / `DESECRATE` de `_structure_at` (inalcanzables hoy) se van en 021a.
- **Coordinación con 020:** el plan de 020c ya pide en `SacrificeSystem` `arm_status`, `check`, `begin_cast`, `finish_cast`, `cancel_cast` (RFC-020 §16): son los cinco métodos del contrato. Con 021a hecho, los pasos 4 y 5 de 020c pasan de «editar `caster.gd` y `match_command.gd`» a «agregar `desecrate_action.gd` (≈ 20 líneas que delegan en el sistema) y un hijo en `wizard_body.tscn`». Igual 020e con `ConvertAction`. 021 no toca `_convert_soul`, `_desecrate_altar` ni las ramas de `_cast_at`: las borra 020.

## 5. Resource, nodo, `@export`

- **Resource:** `MatchRules` (números de regla de las tablas de §6); `ParticleType` `teleport_out.tres` / `teleport_in.tres`; `SpellType` ya trae `cast_range`, `effect_range`, `mana_cost`, `cooldown_s`, `casting_time_s` de `spells.json`: no se copian.
- **Nodo:** acciones, `GuardPost`, `GuardianBond`, `GuardianTether`.
- **`@export` de instancia:** `SpellAction.tag / pick / prompt`; `GuardPost.attach_height`, `health: Health` (opcional), `altar: Altar` (opcional, cierra el puesto cuando el altar queda destruido); `GuardianBond.rules`, `health`, `orders`, `ability`, `tether_scene: PackedScene`; `GuardianTether.segments`, `jitter_radius`, `width`, `material`; `TeleportAction.target_groups` (`["structure", "altar"]`; Shrine suma el suyo), `out_fx`, `in_fx`. Sockets obligatorios vacíos avisan con `_get_configuration_warnings()`.
- **Estado en runtime:** `GuardianBond.post_path`, `GuardPost` lista de atados, `Health.kind_factors`, `UnitBody.attack_factor`, `ActiveAbility.locked`. No hace falta una FSM: el vínculo tiene dos estados (libre, atado) y la retirada del haz es un Tween del propio haz.
- Sin `.call("…")` nuevo salvo hacia `spellbook`, `_wizard` y `fount`, que ya no tienen tipo.

## 6. Números

| Dato | Valor | Dónde vive | Fuente |
|---|---|---|---|
| Guardian: maná / casteo / enfriamiento / alcance | 300 / 1,11 s / 2 s / 40 | `SpellType` | [D] |
| Edificio cerca del mago para armar | 50 (planta) | `MatchRules.guardian_arm_radius` | [S] `state.d:28082` |
| Daño que hace | ×1,5 | `guardian_attack_factor` | [S] `8884` |
| Daño de hechizo / a distancia que recibe | ×0,5 / ×0,25 | `guardian_spell_factor`, `guardian_ranged_factor` | [S] `9006-9009` |
| Curación | 16,667/s | `guardian_heal_per_s` | [S] `14407` |
| Reparto al edificio | `daño / min(n, 0,5·(n+3))` | `GuardPost` (fórmula citada) | [S] `9101` |
| Correa / vuelta | 50 / 20 | `guardian_leash`, `guardian_return_distance` | [S] `15364-15366` |
| Enganche Manalith / altar | +15 / +2,5 | `GuardPost.attach_height` | [S] `15344-15345` |
| Haz: aparecer, cambiar de forma, retirarse | 1 s cada uno; 19 segmentos; radio 0,75 | `GuardianTether` | [S] `2776-2784`, `sacobject.d:4471` |
| Teleport: maná / casteo / enfriamiento / alcance | 800 / 1,23 s / 15 s / 5000 | `SpellType` | [D] |
| Radio de arrastre y distancia al edificio | 30 (el mismo dato) | `SpellType.effect_range` | [D]; [S] `10227`, `10326` |
| Efecto: anillos / vida del anillo / partículas | 0,53 s / 0,8 s / 50 | `ParticleType` | [S] `16074`, `16095`, `10247` |

Enfriamiento real = casteo + enfriamiento + 1,5 s, como el resto del libro (F24): ≈ 4,6 s y ≈ 17,7 s.

## 7. Réplica

| Dato | Viaja por | Por qué |
|---|---|---|
| Lanzar Guardian o Teleport | `submit_cast(tag, point, path)` existente | `path` = criatura o edificio. **Ningún RPC nuevo** |
| Lanzar Manalith | `submit_structure` existente | Sin cambio |
| Respuesta («Blanco inválido»…) | `_receive_feedback` existente | — |
| `GuardianBond.post_path` | `MultiplayerSynchronizer` de `unit.tscn`, al cambiar | Estado del actor; el que entra tarde lo recibe y dibuja el haz |
| Vida del guardián y del edificio | Sincronizadores existentes | — |
| Lista de atados de `GuardPost`, factores, correa | No viaja | Solo los usa el servidor |
| Posición tras Teleport | Sincronizador existente (`position`) | El servidor mueve; no hay interpolación en el cliente que suavizar |
| Efecto de Teleport, partícula de casteo | `FxBus.broadcast` | Evento cosmético |
| Enfriamientos | `Spellbook._push_to_owner` existente | — |

## 8. Riesgos y fuera de alcance

1. **Fidelidad de la atadura.** Se porta lo que hace sacengine (se puede ordenar, vuelve sola pasados 50). Si el original la clava, es cambiar `guardian_leash` y un filtro en `Selection`.
2. **Cuerpo a cuerpo desviado.** `melee_attack.gd` ya multiplica por la resistencia del blanco antes de `Health.damage`; al desviarse al guardián llega con la resistencia del edificio, no la suya. Desvío declarado; arreglarlo es tocar la cuenta de melee, otro corte.
3. **Criatura cautiva (020c).** sacengine no la excluye de Teleport. Recomendación: el vínculo y `Captive` meten a su cuerpo en el grupo `rooted`; Teleport y Guardian saltean `rooted`. Desvío declarado para la cautiva; fiel para la guardiana.
4. **Destino sin suelo.** sacengine cae en la posición del edificio (`// TODO: fix`); en el port eso es adentro de la colisión. Se usa `GroundGuard.altar_return_spot`, que ya resuelve el mismo caso para el fantasma.
5. **Apuntar un edificio lejano.** Sin minimapa hay que tener el edificio en pantalla. El alcance 5000 queda fiel, la comodidad no.
6. **Arte faltante (placeholder con `ParticleType` y `FxBus`):** textura del haz `grdn.TXTR`, malla y textura del anillo azul, sonido `elet`. Íconos `ndrg` y `elet`: ya están en `cache/look/icons`.
7. `debug/guardian_manalith.tscn` tarda 11 s en construir el Manalith antes de probar: es el camino del producto; no se agrega un Manalith preinstanciado.

**Fuera de alcance:** Shrine (no existe; cuando exista suma `GuardPost` y su grupo en `target_groups`); héroes y familiares; veneno ×1,5; apagar el ícono de Guardian sin edificio cerca (hoy el motivo sale al armar); minimapa; casteo escalado por nivel; Convert y Desecrate (RFC-020).

## 9. Conflictos y orden

| Corte | Archivos en común | Veredicto |
|---|---|---|
| **020c** | `caster.gd`, `match_command.gd`, `unit.tscn`, `unit_body.gd`, `match_rules.*`, `rules_suite.gd` | **021a antes de 020c** (recomendado): 020c suma un hijo en vez de ramas. Si 020c ya arrancó, 021a va inmediatamente después y mueve la rama `ucas` a `DesecrateAction`. 021b nunca en simultáneo con 020c |
| 020d | `match_rules.*`, `rules_suite.gd` | Paralelo con 021b/c, agregando al final. `RitualPush` (20 m) no alcanza el destino de Teleport (30 m) |
| 020e | `caster.gd` (`ConvertAction`), `match_rules.*` | Después de 021a |
| 019a (terreno) | Ninguno; Teleport consume `GroundGuard` y la altura del suelo | Paralelo; rejugar `pt64` después de 019a |
| 019c (VFX manantiales) | Ninguno | Paralelo |
| 019d / 019e | `altar.tscn`, `match_rules.*` | No en simultáneo sobre esos archivos |
| 018c / 018d | Ninguno: 021 no toca `high_noon.tscn` | Paralelo |
| 018e (mapa en su escena) | Las escenas debug nuevas heredan `high_noon.tscn` | 018e después, o actualiza sus rutas como las de 020. Puestos y edificios se buscan por grupo, no por ruta |

Entre los míos: 021a → 021b → 021c. 021c puede ir antes de 021b si se deja el filtro `rooted` ya escrito.

## 10. Orden de implementación

**021a**
1. `spell_action.gd` (contrato, avisos de socket).
2. `manalith_action.gd`: mover el código de Manalith desde `caster.gd`; hijo `Actions/Manalith` en `wizard_body.tscn`.
3. `caster.gd`: diccionario de acciones, `_try_action`, `structure_status`, `structure_pick`; `_finish` / `_interrupt` llaman a la acción.
4. `match_command.gd`: `match` por `pick`; `_building_under`; borrar las ramas muertas de `_structure_at`.
5. Casos `action_lookup`, `manalith_action`; correr los flows de F34 y F46; `pt62_manalith.json`.

**021b**
1. `health.gd`: `kind_factors`, `deflector`, una sola consulta por golpe. `damage_deflector.gd`.
2. `guard_post.gd`; hijo en `structure.tscn` y `altar.tscn`.
3. `unit_body.attack_factor` leído por `melee_attack.gd` y `ranged_attack.gd`; `active_ability.locked`.
4. `guardian_bond.gd` en `unit.tscn` (`bind`, `release`, cura, correa, validez, grupo `rooted`); `post_path` al sincronizador.
5. `guardian_action.gd`; hijo `Actions/Guardian`.
6. `guardian_tether.tscn`; `selection.gd` (`drop`, doble clic).
7. `MatchRules`; escenas debug; casos `guard_*`; flows `pt63_*`.

**021c**
1. `teleport_math.gd` y casos `teleport_*`.
2. `warp_to(point)` en `wizard_body.gd` y `unit_body.gd` (posición, velocidad cero, sin meta de marcha).
3. `teleport_action.gd`; hijo `Actions/Teleport`; `ParticleType` nuevos.
4. `debug/teleport_home.tscn`; flows `pt64_*`. Actualizar `FEATURES.md`.

## 11. Cómo verifica un humano

- **Inspector:** `wizard_body.tscn` → `Caster/Actions` muestra tres hijos con `tag` y `pick`; borrar `Guardian` deja la casilla en «No implementado». `unit.tscn` → `GuardianBond` con sus sockets; `structure.tscn` y `altar.tscn` → `GuardPost.attach_height`. `data/match_rules.tres` → grupos «Guardián» y «Teleport» con la cita en cada tooltip.
- **F6 en `debug/guardian_altar.tscn`:** Estructuras, `spell_2`, clic en `Guard1` → haz hasta el altar, sale de la selección; a los 6 s `Guard2` está mucho más herido. Ordenarle a `Guard1` ir lejos: vuelve sola.
- **F6 en `debug/guardian_manalith.tscn`:** construir, atar; la barra del Manalith deja de bajar. Matar al guardián: vuelve a bajar.
- **F6 en `debug/teleport_home.tscn`:** `spell_5`, clic en el altar → el mago y `Pack1..3` aparecen junto al altar en formación; `Stray` sigue en su lugar; la casilla queda enfriando unos 17 s.
- **Dedicado + 2 clientes:** `Godot --headless --path game -- --dedicated --world=res://debug/guardian_manalith.tscn` y dos clientes a `127.0.0.1`; repetir con `teleport_home.tscn`. B tiene que ver lo mismo que A.
- `debug/rules_suite` en verde con los casos nuevos.

## 12. Preguntas abiertas (ninguna bloquea 021a)

1. **¿021a antes de 020c?** Recomendación: sí; achica 020c y 020e.
2. **¿La guardiana se puede ordenar?** Recomendación: sí, como sacengine (correa 50 / vuelta 20), anotado «sin verificar en el original». Alternativa: verificarlo en Ghidra antes de 021b.
3. **¿Una criatura cautiva de un doctor viaja con Teleport?** Recomendación: no (riesgo 3).
4. **¿Texto del aviso?** Recomendación: «Lejos de un edificio propio».

## 13. Decisiones del usuario (2026-10-13)

- Árbol aprobado. **021a va antes de 020c**: Desecrate (020c) y Convert (020e) se enchufan como `DesecrateAction` y `ConvertAction`. 021b y 021c van al terminar los sacrificios (020c–e).
- Pregunta 2: se sigue a sacengine (la guardiana se puede ordenar; correa 50, vuelta a 20), anotado como sin verificar en el original.
- Preguntas 3 y 4: se siguen las recomendaciones (una cautiva no viaja con Teleport; aviso «Lejos de un edificio propio»).
- Numeración: F62 (021a), F63 (021b), F64 (021c).
