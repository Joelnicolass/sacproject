# 061a — Shrine y torres como escenas (plan aprobado 2026-10-24)

Fuente: `docs/archive/rfcs/research/061R-abilities-structures.md` (verificado con REA). Plan del tech lead, aprobado por el usuario con estas decisiones:

- Se migra el Manalith en este corte y se borra `StructureBody` (RFC-055 §13.1: nada de contenido nuevo sobre lo calcado).
- El Shrine **no** revive al mago (el fantasma vuelve solo en el altar).
- El altar, el Manalith y el Shrine dan maná al bando **y a sus aliados** (flag 0x400 del BLDG).
- **Sin escena debug nueva** (el usuario va a borrar `debug/`): nada de `shrine_lab.tscn` ni `debug/rules/shrine_lab.tres`. Verificación: suite de reglas headless + captura con ventana en la partida real con `agent/harness/match_shots`.

## Objetivo
- Shrine `pcas` lanzable sobre un manantial libre: 800 de maná, mismo camino de lanzamiento que el Manalith, modelo del dios del mago.
- Manalith y Shrine: vida 5000, regeneración 83,3/s (se llenan en 60 s).
- Maná a ≤ 50 m para el bando y aliados: Manalith 33,3/s, Shrine 8,33/s, altar 16,7/s. Los Manahoar solo cuentan Manaliths.
- El Shrine es destino de Convert y sitio de ritual, admite Guardian y es destino de Teleport. Al destruirse, el manantial queda libre.
- Ningún `spell_tag == "htlm"` en gameplay, UI ni IA.

## Árbol de archivos
```
scenes/structures/
  [~] README.md
  [-] structure.tscn, structure_body.gd          (registro 1 a 1: constantes 3000 y 1,25)
  [~] structure_spawner.gd                       @export scenes: Array[PackedScene]; spawn_tower(scene, fount, slot, yaw)
  [~] building_type.gd                           + enum Role {SCENERY, MANALITH, SHRINE}, @export role
  [~] structure_inspector.gd                     solo el grupo "structure"
  towers/
    [+] README.md
    [+] cast_tower.gd                            CastTower extends MapBuilding (≤ 90 líneas)
    [+] tower.tscn                               hereda map_building.tscn, valores del Manalith
    [+] shrine_tower.tscn                        hereda tower.tscn: rate 8.333, post a 2,5 m, + RitualSite
    [+] tower_rules.gd                           static RefCounted: closest_free_fount, has_room, regen_per_s
  buildings/
    [~] _mana,_pyma,_jman,_stam,_cama.tscn        instancian tower.tscn (conservan Visuals/Collision)
    [~] _pcsh,_pasp,_jsac,_stsp,_casp.tscn        instancian shrine_tower.tscn
data/buildings/
  [~] los 10 .tres                               role, display_name ("Manalith" / "Santuario"), vida 5000
scenes/components/[+] health_regen.gd           HealthRegen: @export health, refill_s (0 = off); solo autoridad
scenes/gods/[+] god_structure.gd                GodStructure (Resource): spell: SpellType, scene: PackedScene
scenes/gods/[~] god_type.gd                     + @export structures: Array[GodStructure]
data/gods/[~] 5 dioses                          2 filas (htlm → su Manalith, pcas → su Shrine)
scenes/spells/[~] spell_type.gd                 [-] campo `structures`
scenes/spells/actions/[-] manalith_action.gd → [+] structure_action.gd (StructureAction para htlm y pcas)
data/catalog/spells/[~] htlm.tres, pcas.tres    sin `structures`
scenes/wizards/[~] wizard_body.tscn             Caster/Actions: Manalith + [+] Shrine, ambos StructureAction
scenes/wizards/[~] wizard_body.gd               + god_type() -> GodType
scenes/map/[~] map_building.gd                  health.setup solo si maximum ≤ 0
scenes/map/props/[~] mana_source.gd             + @export reach: CollisionShape3D (esfera); aliados; audit_name
scenes/map/props/[~] ritual_site.gd             + const GROUP; + @export building: MapBuilding
scenes/map/props/[~] altar.tscn                 GuardPost con AttachPoint Marker3D a 2,5 m
scenes/map/props/[~] manafount_body.gd          const GROUP
scenes/spells/guardian/[~] guard_post.gd        [-] attach_height → @export attach_point: Marker3D
scenes/sacrifice/[~] sacrifice_system.gd        closest_own_altar → closest_own_site(slot, from) -> RitualSite
scenes/units/[~] unit_mana_support.gd           type.role == MANALITH
scenes/ui/[~] target_info.gd, minimap_markers.gd  por rol (Shrine con su marca)
scenes/orders/command/[~] pointer_ray.gd        sin preload de structure_body
scenes/ai/[~] ai_perception.gd, convert, ai_audit.gd  por rol; closest_own_site
scenes/match/[~] match.tscn                     StructureSpawner.scenes = las 10 torres
debug/suite/[+] tower_cases.gd (+ rules_suite.gd y agent/det_cases.txt); [~] bench_structure.gd y los usos existentes
agent/harness/match_shots/[~] match_shots.gd    opción para lanzar Shrine/Manalith y la vista del manantial
```

## Nodos de `tower.tscn`
```
Tower (StaticBody3D, CastTower)   type, owner_slot, mana_source, guard_post
├── Visuals
├── Collision (BoxShape3D)
├── Health                        deflector = GuardPost
├── HealthRegen                   refill_s = 60
├── ManaSource                    rate 33.333, audit_name &"manalith"
│   └── Reach (Area3D, monitoring off, layer 0) └── Shape (SphereShape3D r = 50)
├── GuardPost                     attach_point = %AttachPoint
│   └── AttachPoint (Marker3D, y = 15)
├── Sync (MultiplayerSynchronizer) Health:maximum + Health:current
└── HealthBar
```
`shrine_tower.tscn`: rate 8.333, audit_name &"shrine", AttachPoint y = 2.5, + `RitualSite` (kind SHRINE, building = raíz).

## Dueños
Vida: `Health` de la torre (host). Vínculo torre ↔ manantial: `CastTower` (occupy en `_ready`, release en `_exit_tree`). Bando: `CastTower.owner_slot`. Rol: `BuildingType.role`. Tasa y radio: `ManaSource`. Ritual: `RitualSite`. Torres en juego: `StructureSpawner`.

Red: `Caster.request_structure` → `submit_structure` → `StructureAction` en el host → `StructureSpawner.spawn_tower` (MpSpawner) → cada peer instancia la escena. Muerte: `Health.died` → `MapBuilding.destroyed` → `CastTower` hace `queue_free` en la autoridad.

## Criterios de aceptación
Suite `tower_cases`:
- 10 torres: vida 5000, rol correcto, rate 33,333 / 8,333, radio 50; GuardPost en las 10, RitualSite solo en Shrines.
- Regeneración de 1000 a 5000 en 48 s ± 1 tick (83,3/s ± 0,1).
- Maná en 10 s: mago a 49 m de un Shrine +83,3 ± 1 %, a 51 m 0; aliado igual; enemigo 0; Shrine + Manalith +416,6; altar con aliado 16,7/s.
- Manahoar: > 0 cerca de un Manalith aliado, 0 con solo un Shrine.
- Convert: `closest_own_site` elige el Shrine si está más cerca; con el altar destruido y el Shrine en pie arma; sin ninguno, `NO_ALTAR`; el ritual ocupa el RitualSite del Shrine.
- Guardian encuentra el post del Shrine (rayo a 2,5 m); Teleport acepta el Shrine.
- `pcas` ya no da NOT_IMPLEMENTED; levanta `_pcsh` (Persephone) y `_jsac` (James); manantial ocupado → NO_FOUNT; destruir la torre libera el manantial.
- Red: late join ve la misma vida y el manantial ocupado (`debug/net/late_join.tscn`).
- Lint: bajan C7, C16 y C18; no sube nada.

Con ventana (la hace el orquestador): partida real en High Noon, el Shrine lanzado sobre un manantial, PNG antes y después.

## Fuera de alcance
La IA lanzando Shrine (055f), Desecrate contra Shrines, partículas propias del Shrine, radios del altar y del manantial como esfera (055r).

## Orden
1. Rol, `.tres`, `GodStructure`/`GodType.structures`; quitar `SpellType.structures`.
2. `HealthRegen`; esfera y aliados en `ManaSource`; `attach_point`; `RitualSite.GROUP/building`.
3. `CastTower`, `tower.tscn`, `shrine_tower.tscn`; re-rootear las 10 escenas; guarda en `MapBuilding`.
4. `StructureSpawner` tipado, `StructureAction`, nodo Shrine en `wizard_body.tscn`, `match.tscn`.
5. Consumidores de rol (Manahoar, minimapa, target_info, IA, audit) y `closest_own_site`.
6. Borrar `structure.tscn`/`structure_body.gd`; ajustar suite; `tower_cases`; baseline del lint.
7. Opción de `match_shots` para la captura.
