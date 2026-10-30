# RFC-017 — Red que cierra la partida (plan del tech lead)

Estado: árbol aprobado por el usuario el 2026-10-12

Solo lectura: no toqué el repo. Verifiqué en código B2, B3, B4, la falta de sincronizador en `structure.tscn` y las cinco validaciones de sender. B1 ya no aplica: `scenes/world/high_noon.tscn` pesa 9,5 KB.

El corte es grande para un developer. Lo parto en tres:

| Sub-corte | Qué cierra | Depende de |
|---|---|---|
| **017a** — Partida que cierra en red | B2, estado de partida, late join | nada |
| **017c** — Higiene de red | sync de estructura, sender único, B4 | nada; **puede ir en paralelo con 017a** (no comparten archivos ni escena) |
| **017b** — Doctores atacables | B3 | 017a y 017c (toca `desecration_system.gd`, `soul_system.gd`, `unit_body.gd`) |

Sugiero registrarlos como F44 (017a), F45 (017b) y F46 (017c) en `FEATURES.md`.

## 1. Objetivo y criterios de aceptación

**017a**
- Con dedicado y dos clientes, al terminar el ritual el altar 2 queda destruido en los tres procesos (oculto, sin colisión, sin maná).
- Cuando el mago sin altar llega a `GONE`, el cliente 1 ve «Victoria» y el cliente 2 «Derrota». El dedicado no muestra nada.
- Un cliente que entra después de la destrucción ve el altar destruido; si la partida ya terminó, ve su resultado.
- En solo sigue funcionando (el altar se destruye; sin RPC).

**017b**
- Los dos doctores tienen `Health`, colisión, grupo atacable y caminan con `move_and_slide` sobre el terreno.
- Matar al doctor de profanación durante el canto cancela el ritual: el altar sigue en pie.
- Matar al Sac Doctor libera el alma: antes de recogerla queda convertible de nuevo; si ya la cargaba, cae un alma en el lugar. No se acreditan almas.
- La vida del doctor se ve bajar en ambos clientes.

**017c**
- La vida de una estructura llega al cliente que no la construyó.
- Los cinco `submit_*` validan por `MpAuthority`, sin copias a mano.
- `multiplayer_suite` deja de llamarse así y pierde los dos casos que no prueban nada.

## 2. Escenas de prueba

Todas instancian `scenes/world/high_noon.tscn` y cambian `rules` por un `.tres`, como `debug/wizard_ghost.tscn`. Online se abren con `--world=res://debug/<x>.tscn` en el dedicado y en los dos clientes. El cliente A entra primero (slot 1). Los extras son instancias estáticas de `units/unit.tscn` con overrides en el `.tscn` (`owner_slot`, `target_groups`, `groups`), sin script nuevo.

| Escena | Instancia | Estado inicial | Todavía NO cumplido | Acción InputMap |
|---|---|---|---|---|
| `debug/desecrate_match.tscn` (017a) | `high_noon.tscn` + `debug/rules/desecrate_match.tres` (`start_health = 50`). `MapProps/Slot1` movido a ~90 m frente al mago 1, en llano. `Offering` (slot 1, `target_groups = []`) a ≤ 8 m del altar 2. `Executioner` (Druid slot 1, `target_groups = ["wizard"]`) a más de 100 m del mago 2, sobre su línea de frente. | Dos altares en pie, dos magos vivos | `Altar.destroyed`, `Match.winner_slot != 0`, `%MatchResult` visible | A: `move_forward`, clic `%StructureTab`, `spell_4` (Desecrate; confirmar índice), clic `%View`. B: espera el altar destruido, `move_forward` hasta entrar en la vista del Executioner |
| `debug/ritual_cancel.tscn` (017b) | Igual que arriba, sin Executioner, + `debug/rules/ritual_cancel.tres` (`desecrate_chant_s = 30`). `Guard1..3` (Druid slot 2, `target_groups = ["doctor"]`) a ~15 m del altar 2 | Sin doctor, altar 2 en pie | Doctor spawneado, su vida bajando, doctor muerto, altar todavía en pie | A: igual que arriba. B: solo mira |
| `debug/sac_doctor_kill.tscn` (017b) | `high_noon.tscn` + `debug/rules/sac_doctor_kill.tres` (`starting_souls = 0`). `Victim` (slot 2, `groups = ["victim"]`, `target_groups = []`) a < 20 m frente al mago 1. `Killer` (slot 1, `target_groups = ["victim"]`). `Guard1..3` (slot 2, `target_groups = ["doctor"]`) cerca del altar 1 | Sin alma, sin doctor, «Almas 0» | Alma roja, `SacDoctor1`, doctor muerto, alma suelta en `%Souls`, «Almas 0» sin cambio | A: clic `%StructureTab`, `spell_3` (Convert), clic `%View` |
| `debug/structure_siege.tscn` (017c) | `high_noon.tscn` + `debug/rules/cast_heal.tres` (ya existe). `Sieger` (slot 2, `target_groups = ["structure"]`) junto al manantial 1 | Sin estructura | `Structure1` con `Health.current < 3000` en el cliente B | A: clic `%StructureTab`, `spell_1`, clic `%View` sobre el manantial |

Los 100 m del Executioner son el `sight_range` del Druid (`cache/data/creatures.json`, `nmuh`). Victim muere por Killer y no por Rock porque Rock (300) + Convert (800) pasa los 1000 de maná.

**Flows que tiene que escribir el playtester** (`res://agent/flows`, patrón `f20_client_a/b.json`: `boot.tscn` → `%Play` → `%Join`):
- 017a: `rfc017a_win_a`, `rfc017a_lose_b`, `rfc017a_late_b` (B entra con el altar ya destruido), `rfc017a_rejoin_b` (B vuelve con la partida terminada y ve «Derrota»), `rfc017a_solo`.
- 017b: `rfc017b_cancel_a/_b`, `rfc017b_sacdoc_a/_b`.
- 017c: `rfc017c_siege_a/_b`, más regresión de los `submit_*`: `f20_client_a/b`, `f24_online_client`, `f27_pt_online_client`, `f30_pt_online_client`, `f31_online_client`.

## 3. Árbol de archivos y mapa de responsabilidades

```text
game/
  scenes/world/match/
    match.tscn                 NUEVO  Match + AltarDefeatRule
    match_state.gd             NUEVO  class_name MatchState
    altar_defeat_rule.gd       NUEVO  class_name AltarDefeatRule
  scenes/ui/
    match_result.tscn/.gd      NUEVO  class_name MatchResultBanner (%MatchResult)
  scenes/world/props/
    altar.gd                   NUEVO  class_name Altar
    altar.tscn                 MOD    script, mallas bajo Visuals, socket mana_source
  scenes/world/doctors/
    doctor.tscn                NUEVO  (017b)
    doctor_body.gd             NUEVO  class_name DoctorBody
  scenes/world/attackable.gd   NUEVO  class_name Attackable (017b)
  scenes/world/souls/
    convert_errand.gd          NUEVO  reemplaza sac_doctor.gd (BORRAR)
    sac_doctor.tscn            MOD    instancia doctor.tscn + %Errand
    soul_system.gd             MOD
  scenes/world/desecration/
    ritual_errand.gd           NUEVO  reemplaza desecration_doctor.gd (BORRAR)
    desecration_doctor.tscn    MOD    instancia doctor.tscn + %Errand
    desecration_system.gd      MOD    (017a y 017b)
  scenes/world/structures/structure.tscn   MOD (017c)
  scenes/world/{high_noon.tscn, high_noon.gd, map_props.gd}   MOD (017a)
  scenes/world/{unit_body.gd, match_command.gd, body_separation.gd,
                units/ranged_shot.gd, spells/rock_projectile.gd}  MOD (017b, una línea c/u)
  scenes/world/{wizard/wizard_body.gd, spells/caster.gd, unit_body.gd,
                orders.gd, souls/soul_system.gd}                  MOD (017c, sender)
  scenes/world/components/health.gd   MOD  + class_name Health (017b)
  scenes/data/match_rules.gd, data/match_rules.tres   MOD (017b)
  addons/mp_kit/mp_authority.gd (+README)   MOD (017c)
  debug/  desecrate_match · ritual_cancel · sac_doctor_kill · structure_siege (.tscn)
          rules/{desecrate_match, ritual_cancel, sac_doctor_kill}.tres
          multiplayer_suite.* → rules_suite.*   RENOMBRAR (017c)
```

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `Altar` | Estado `destroyed` y su efecto local: oculta `Visuals`, `collision_layer = 0`, apaga `ManaSource`, sale del grupo `altar` | Nodo en `altar.tscn` | `map_props` coloca; no decide ni pinta el estado. Shrine lo reusará |
| `MatchState` | Fuente única del resultado (`winner_slot`, `loser_slot`, `destroyed`), `to_snapshot`/`apply_snapshot`, push y reenvío | Nodo `%Match` | Si viviera en `DesecrationSystem`, la victoria quedaría atada a un hechizo |
| `AltarDefeatRule` | Solo servidor: mago en `GONE` con altar destruido → `match_state.finish()` (lógica movida desde `desecration_system.gd:110-132`) | Hijo de `Match` | Otra condición de victoria = otro hijo; se apaga sacándolo |
| `MatchResultBanner` | Copy «Victoria» / «Derrota» / «Fin de partida» según `MpKit.local_slot()`; oculto si es 0 | Packed UI bajo `Hud` | Hoy va en `%Battle`, que el próximo mensaje de hechizo pisa |
| `high_noon.gd` | Conecta `match_state.result_changed` y deshabilita `%View` | Orquestador flaco | Pierde el texto de resultado |
| `DesecrationSystem` | Validar, sacrificar, spawnear doctor; al completar llama `match_state.record_altar_destroyed()` | Nodo | Ya no hace `queue_free()` del altar ni decide victoria |
| `DoctorBody` | Cuerpo: vida, colisión, caminar a un punto con el motor, morir | Packed `doctor.tscn` | Dos callers (Convert y Desecrate). No es `unit.tscn`: sacengine lo excluye de selección y órdenes (`state.d:1135`, `1141`) |
| `ConvertErrand` | Ir al alma, tomarla, volver, acreditar; soltarla si el cuerpo muere | Nodo hijo | Recado ≠ cuerpo |
| `RitualErrand` | Llegar al altar, cantar, completar; cancelar si el cuerpo muere | Nodo hijo | Ídem |
| `Attackable` | `GROUPS` e `is_body(node)`: qué grupos son blanco | `static`, estilo `GroundGuard` | Reemplaza tres copias del mismo `is_in_group(...) or ...`; sin esto «doctor» sería la cuarta |
| `MpAuthority.command_slot(node)` | Slot del sender en el servidor, o 0 | Addon, genérico | `orders` y `soul_system` no tienen `owner_slot` que pasar |

Árbol de `doctor.tscn`: `Doctor` (CharacterBody3D, layer 2, mask 1) → `Mesh` (BodyVisual, `sacd`), `Collision` (cápsula 0,4 × 2,55 de `bodies.json`), `Health`, `HealthBar` (`unit_health_bar.tscn`), `Net` (MpReplicate, como `unit.tscn`), `MultiplayerSynchronizer`.

## 4. Resource, nodo, `@export`

- **Resource:** `MatchRules` suma `desecrate_chant_s`, `doctor_altar_distance`, `convert_pickup_distance`. Los `.tres` de debug solo cambian números. La vida, velocidad y regeneración del doctor salen de `GameData.creature("dcas")`; no se commitea un `.tres` con datos originales.
- **Nodo:** todo lo de la tabla, salvo `Attackable` y `command_slot`.
- **`@export` (sockets):** `Altar.mana_source`, `Altar.visuals`; `DesecrationSystem.match_state`; `AltarDefeatRule.match_state`; `MatchResultBanner.match_state`; `DoctorBody.health: Health`, `.visual`, `.health_bar`; `ConvertErrand.body`, `RitualErrand.body` y `.rules`. Los recados avisan por señal (`delivered`, `soul_dropped`, `completed`, `cancelled`); se va el `get_parent().get_parent()`.
- El nombre de variable es `match_state`: `match` es palabra reservada.

**Números**

| Dato | Valor | Fuente |
|---|---|---|
| Vida Sac Doctor | 400 | `cache/data/creatures.json` `dcas`; tag en `nttData.d:1016` |
| Velocidad | 10 m/s | ídem (hoy 7,5 y 8,0 sin cita) |
| Regeneración | 83,3/s continua | ídem; `continuousRegeneration`, `nttData.d:693` |
| Distancia al altar para empezar | 20 m | `state.d:15787`, `15857` (hoy 1,2 m: queda dentro de la base de radio 7) |
| Distancia para tomar el alma | 2 m | `state.d:15692` |
| No ataca | — | `sacobject.d:85` |
| Sin cadáver al morir | — | `state.d:13999` |
| `desecrate_chant_s` | 7,5 **provisional** | sacengine no tiene duración fija: preparación 5 s (`state.d:2713`) y rondas de 13,5 s (`15946-15949`) hasta que muere el mago rival |
| `give_up_s` (doctor trabado) | 10 **provisional** | sin equivalente |

## 5. Qué se replica y cómo

| Dato | Mecanismo |
|---|---|
| Altares destruidos, `winner_slot`, `loser_slot` | **Snapshot**: `MpKit.push_snapshot(match_state.to_snapshot())` al cambiar; `push_snapshot_to(peer)` en `MpKit.client_world_ready`. El cliente aplica en `snapshot_received` y `MatchState` marca `Altar.destroyed` por `owner_slot` (mismo código en servidor y cliente) |
| Doctor: existencia y muerte | **Spawner**: los `DoctorSpawner` (`MpSpawner`) que ya existen |
| Doctor: `position`, `rotation` | **Synchronizer**, always |
| Doctor: `owner_slot` | Synchronizer, solo spawn |
| Doctor: `Health:maximum`, `Health:current` | Synchronizer, spawn + on change |
| Estado del recado (`carrying`, canto) | No se replica; solo servidor |
| Alma soltada | `SoulSpawner` existente |
| Estructura: `Health:maximum`, `Health:current` | **Synchronizer nuevo** en `structure.tscn`, spawn + on change (reemplaza el `MpSpawnGate` vacío) |
| Convert / Desecrate | `submit_cast` existente; no hay RPC nuevo |

Descarté un synchronizer por altar: serían dos canales para un mismo hecho. El snapshot es confiable, ordenado (altar antes que resultado) y hoy nadie usa `push_snapshot`.

**Sender.** `MpAuthority.accept_command(self, owner_slot)` sirve tal cual en tres sitios: `wizard_body.gd:277`, `unit_body.gd:270`, `caster.gd:183-190` (`peer_id_for(0)` da 0, así que slot 0 se rechaza). `orders.gd:48` y `soul_system.gd:94` derivan el slot del sender; para esos propongo `static func command_slot(node) -> int` en `mp_authority.gd` (unas 6 líneas).

## 6. Riesgos y fuera de alcance

- **Línea recta con colisión real.** El doctor puede trabarse en pilares, agujeros o estructuras. Lo mitigan el origen junto al blanco (pregunta 1), el radio de llegada de 20 m y `give_up_s`. El pathfinding es Fase 5.
- **Regeneración de 83/s.** Hace falta daño concentrado; si tres Druids no alcanzan, se suman guardias en la escena de debug.
- **Reingreso con la partida terminada.** `WizardSpawner` puede spawnear un mago nuevo; 017a solo garantiza el cartel.
- **`class_name Health`.** Chequear con parse headless que no choque con constantes locales.
- **Addon.** `command_slot` hay que subirlo después a las dos RC del kit (ES y EN). El PRD dice «sin fork de mp_kit»; RULES permite el arreglo si se sube.
- **Salpicadura.** Fireball, Swarm y Wrath siguen sin pegar a doctores ni estructuras (`["wizard","unit"]`); no lo toco.
- **Mensajes.** «Altar destruido» y «Ritual cancelado» siguen solo en el servidor; el cliente lo ve por el altar y el doctor.
- **Fuera de alcance:** pathfinding, Shrine/Guardian/Teleport, barra y alarma, ritual real de sacengine (cuatro doctores en el altar propio), equipos, más de 2 jugadores, FSM y `class_name` masivo.

## 7. Orden de implementación

**017a**
1. `altar.gd` + `altar.tscn`; `map_props.gd` setea `owner_slot` tipado.
2. `match_state.gd`, `altar_defeat_rule.gd`, `match.tscn`; instancia `%Match` en `high_noon.tscn`.
3. `desecration_system.gd`: socket `match_state`, sacar `queue_free()`, `_destroyed_altars`, `match_over` y `_watch_wizard`. El doctor viejo se borra también si el altar ya está destruido.
4. `match_result.tscn` bajo `Hud`; `high_noon.gd` conecta `result_changed`.
5. Snapshot: push, reenvío y aplicación.
6. `debug/desecrate_match.tscn` y su `.tres`.

**017c**
1. `MultiplayerSynchronizer` en `structure.tscn`.
2. `command_slot` + README del addon; cambiar los cinco sitios.
3. Renombrar a `debug/rules_suite.*` (`RULES SUITE PASS`), borrar `synchronization`, renombrar `victory_defeat` a `unit_death`; actualizar F42.
4. `debug/structure_siege.tscn`.

**017b**
1. `class_name Health`; `attackable.gd`; reemplazar los tres chequeos; `"doctor"` en `unit_body.target_groups` y `BodySeparation.GROUPS`.
2. `doctor.tscn` + `doctor_body.gd`.
3. `MatchRules` + `data/match_rules.tres`.
4. `ritual_errand.gd`, `desecration_doctor.tscn`, sistema con señales y `_doctor_origin()`.
5. `convert_errand.gd`, `sac_doctor.tscn`, `soul_system.gd` (soltar al morir).
6. Borrar los dos scripts viejos; dos escenas de debug y sus `.tres`.

## 8. Cómo verifica un humano

- **F6** en `altar.tscn`: marcar `destroyed` en el inspector remoto → desaparece y pierde colisión.
- **F6** en `doctor.tscn`: se ve el modelo `sacd`, la cápsula y los sockets sin avisos.
- **Online:** `godot --headless --path game -- --dedicated --world=res://debug/desecrate_match.tscn` y dos instancias de editor con el mismo `--world`, Unirse a `127.0.0.1`. Hacer la acción de la tabla. En el árbol remoto del dedicado, `%Match` muestra `winner_slot = 1`. Los clientes muestran «Victoria» y «Derrota».
- **Late join:** abrir el cliente B después de la destrucción; el altar 2 no está.
- **Ritual cancelado:** en `ritual_cancel.tscn`, la barra del doctor baja en ambos clientes, el doctor desaparece y el altar 2 sigue.
- **Estructura:** en `structure_siege.tscn`, el cliente B ve `Structures/Structure1/Health.current` por debajo de 3000.
- **Solo:** F5 → Jugar solo; el altar se destruye sin servidor.

## 9. Preguntas abiertas

1. **¿De dónde sale el doctor?** F38 dice «desde el altar del jugador». sacengine lo expulsa a 20 m del blanco (`state.d:10190`, `10207`, `2640`). Con colisión real ya no puede nacer en el centro del altar (queda dentro de la base). **Recomiendo: junto al blanco** — Convert a 20 m del alma, Desecrate donde estaba la criatura sacrificada. El PRD pone a sacengine como árbitro y gana sobre FEATURES; habría que corregir el texto de F38. Si preferís el altar, nace a 15 m del centro y `sac_doctor_kill` solo puede probar la muerte antes de recoger el alma. El plan asume lo recomendado; el cambio queda aislado en `_doctor_origin()`.
2. **¿De quién es el alma que suelta un Sac Doctor muerto mientras la cargaba?** sacengine no tiene ese caso (el doctor no la consume al llegar). **Recomiendo: sin bando** (azul para los dos, la junta el primero), que es lo que `soul.gd` ya hace con un alma suelta.
3. **¿El doctor regenera 83,3/s como en los datos?** **Recomiendo: sí.** Si el playtest muestra que no se puede matar, se revisa.
4. **¿OK editar `addons/mp_kit/mp_authority.gd`** para `command_slot` y subirlo después al kit? **Recomiendo: sí.** Si no, `orders` y `soul_system` quedan con `MpKit.slot_for_peer` y la unificación es de tres sobre cinco.
5. **¿Están bien las piezas?** Las candidatas a fusionar son `AltarDefeatRule` (dentro de `MatchState`) y `Attackable` (sumar `"doctor"` a mano en cuatro sitios). Recomiendo dejarlas separadas.

## 10. Decisiones del usuario (2026-10-12)

- Árbol aprobado. Orden: 017c en paralelo con 018a/018b; 017a después de 018b (el altar ya es un nodo fijo de la escena: `altar.gd` lleva `@export var owner_slot` y no se toca `map_props.gd`); 017b después de 018c/018d.
- Pregunta 1: el doctor sale junto al blanco, como en sacengine. Confirmar con REA sobre el ejecutable original antes de implementar 017b.
- Pregunta 4: sí, se agrega `command_slot` a `addons/mp_kit/mp_authority.gd` y después se sube al kit.
- Preguntas 2, 3 y 5: se siguen las recomendaciones del plan.
- Los valores provisionales (`desecrate_chant_s`, `give_up_s`) se verifican con REA antes de 017b.

## 11. Cambio de alcance (2026-10-13)

017c está cerrado (F46). **017a y 017b quedan reemplazados por RFC-020**: el usuario eligió el ritual fiel al original (4 doctores, rondas con drenaje de vida y maná, la muerte del mago destruye el altar; Convert revive y se lleva a la criatura). Ver `.studio/RESEARCH-doctors.md`. Lo que sigue valiendo de este plan: `Altar` con estado replicado, `MatchState` con snapshot y reenvío, `MatchResultBanner`, `DoctorBody` reusable y `Attackable`.
