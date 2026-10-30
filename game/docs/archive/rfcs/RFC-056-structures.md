# RFC-056: estructuras (destrucción, extensible por señales)

Estado: implementado 2026-10-26 (S1, S2, S3), sin correr Godot; falta la pasada final de pruebas. Plan: `docs/archive/rfcs/plans/056-structures-plan.md` (aprobado con todas las recomendaciones). Feature: **F391**.

## Alcance

Solo la caída de las torres (Manalith y Shrine) y de los edificios del mapa, con escombros y explosión como el original. Nada nuevo de guardián, captura, visión, fuego, look del Shrine ni altares: cada uno sería, más adelante, un nodo hijo que escucha las señales de abajo.

## Qué pasa en el juego

- Un edificio con vida que llega a 0 cae en todos los peers el mismo tick (la caída sale de `Health:current`, replicado con `spawn=true`).
- Cada parte de `Visuals` con malla estalla en su centro (o en su `Marker3D`, si tiene uno): `building_break.tscn` (el estallido de Explosion: esferas de 30 m a 40 m/s y 5 m a 10 m/s, 35 rocas, sonido `fbxp`, sin quemadura, sacudida 0,35) más las partículas `explosion_blast` y `explosion_blast2`. Todo local: 0 RPC; el dedicado no dibuja ni suena.
- Los edificios del mapa ocultan sus partes y muestran su ruina (`BuildingType.ruin_scene`) como hijo normal.
- Una torre en pie, al caer: libera el manantial, sale del grupo `cast_tower`, deja de dar maná y deja de ser blanco en ese tick; queda `linger_s` (1 s) y el servidor la libera, así todos ven la caída antes del despawn.
- Quien entra tarde con el edificio ya caído ve la ruina y ningún estallido (`arm_after_s` = 2 s).
- Fuera: el corte de una torre que sube (plan 065, explosión chica), la ceniza `1tuh` (NO VERIFICADO qué edificios la usan).

## Contratos

```gdscript
# MapBuilding (scenes/map/map_building.gd): dueño de «caído»; no dibuja ni suena.
signal damaged(fraction_left: float)        # cada golpe, todos los peers; una vez en 0
signal destroyed(building: MapBuilding)     # una vez, todos los peers; colisión y grupos ya apagados

# StructureBreak (scenes/structures/breaking/): presentación, local en cada peer.
signal broke(at: Vector3)
@export var building: MapBuilding
@export var scene: PackedScene              # building_break.tscn
@export var bursts: Array[ParticleType]
@export var arm_after_s := 2.0

# BuildingRuin: oculta Visuals y agrega la ruina como hijo propio.
@export var building: MapBuilding

# BuildingFit
static func part_center(part: Node3D) -> Vector3   # Marker3D hijo, o el centro de sus mallas; NAN sin malla

# CastTower
@export var linger_s := 1.0
func is_targetable() -> bool                # en pie y no caída
```

## Cómo se extiende

Un comportamiento nuevo (sonido al dañarse, humo, fuego, una regla) es un nodo hijo en `map_building.tscn` (todos los edificios) o en la escena de un edificio, con `@export var building: MapBuilding` y dos `connect` en `_ready` a `damaged` / `destroyed`. No se toca código de `MapBuilding`; se apaga sacando el nodo. Detalle en `scenes/structures/breaking/README.md`.

## Verificación

- `debug/structures/structure_break.tscn` (F6): K tira, de a dos golpes, la torre enemiga, la choza y el cactus.
- rules_suite `structure_break_cases`: un estallido por parte, la torre libera la fuente en el tick 0 y sale a los 60 ± 1 ticks, la ruina no es interna, el indestructible no estalla, quien entra tarde no estalla, la sonda recibe `damaged` y `destroyed`.
- `agent/flows/f391_structure_break.json`: capturas antes, +0,1 s y +3 s por blanco; imprime `BreakKey.report` y el trauma de la cámara.
- Pasada final: import, rules_suite (`tower_cases`, `build_area_cases`, `guardian_cases`, `tree_block_cases`, `structure_break_cases`), el flujo f391 con ventana, una corrida con red (cliente que mira y cliente que entra tarde), `fx_net_probe`, lint.

## Ref

sacengine `state.d:8376-8380` (destroy), `9183-9188`, `15157-15181` (updateBuildingDestruction), `27625-27660` (explosionAnimation, animateDebris, destructionAnimation).
