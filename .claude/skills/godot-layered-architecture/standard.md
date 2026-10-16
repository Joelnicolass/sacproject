# Camino estándar — escenas y scripts

Usar **solo** si el usuario eligió estándar (o el repo ya lo declara). No crear `src/domain/` ni una fachada de sesión “por las dudas”.

Siguen valiendo: composición, editor, Resources, reuso, scripts chicos, señales arriba / llamadas abajo.

## Forma del proyecto

Escena + script **juntos**.

```
scenes/
  actors/
    projectile.tscn + .gd
    enemy.tscn + .gd
    actor.tscn + .gd
  components/           # Health, Hitbox, Hurtbox (packed scenes)
  world/
  ui/
resources/
  projectiles/          # projectile_data.gd + projectile_fast.tres + projectile_slow.tres
  enemies/
addons/mp_kit/
```

Variante válida: carpetas por feature. Inválido: un `Player.gd` de mil líneas y `match weapon`.

## Escenas autónomas

Cada `.tscn` debe poder abrirse con **F6** y funcionar (o advertir). Docs: [organización de escenas](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html).

- Cero deps al entorno. Lo que falta, el padre lo inyecta: `@export var health: Health`, Callable, o Node.
- Señales en **pasado** y tipadas. El **padre** hace `child.died.connect(...)`. El hijo no llama `get_parent().on_died()`.
- Internos de *esta* escena: `%UniqueName` (`%Sprite`). Entre escenas: socket `@export`, no `get_node("../../Audio")`.
- Si un socket obligatorio está vacío: `@tool` + `_get_configuration_warnings()`.
- Relacional, no espacial: ¿al borrar el padre debe borrarse el hijo? Si no, sibling. Posición relativa: `RemoteTransform2D` / `RemoteTransform3D`.
- `Main` (entrada) → `World` (se reemplazan niveles) + `GUI` (hermana; no muere con el nivel).

## Scripts pequeños

- Un nodo = un trabajo. Movimiento ≠ HP ≠ disparo ≠ HUD.
- Extraer packed scene hija cuando el script implementa dos sistemas.
- Herencia rasa: `State extends Node`. No `EliteFlyingEnemy extends FlyingEnemy extends Enemy`.
- El mundo **compone** spawners, cámara, FX. No puntúa en el mismo archivo que spawnea.

## Estado de partida sin domain

- Nodo chico `Match` (hijo del mundo). Autoload **solo si** sobrevive el cambio de escena.
- Catálogo de tipos = Resource, no `enum` + `match` en el Match.
- Con red: solo el host muta ese estado.

## Autoloads

Ver tabla en `SKILL.md`. Sí: bus de eventos, `MpKit`.  
No: `EnemyManager`, fábrica global de proyectiles, inventario del run si puede vivir en el árbol. Audio: `AudioStreamPlayer` / componente `class_name` en escena; autoload de sonido solo si es un bus aislado.

## Checklist extra

- [ ] ¿La escena corre con F6? ¿Deps por `@export`? ¿Warning si falta el socket?
- [ ] ¿Variantes = `.tres` (o packed scene si cambia la **estructura**)?
- [ ] ¿El script cabe en una lectura corta?
- [ ] ¿No se introdujo `src/domain/` sin pedir Clean?
