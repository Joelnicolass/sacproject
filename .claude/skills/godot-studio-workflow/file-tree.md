# Árbol de archivos (antes del OK)

El tech-lead lo entrega **antes** de pedir aprobación. El orquestador lo muestra al usuario. Sin esto no hay “OK, implementá”.

Sirve para ver, de un vistazo, si la feature es un god-node o un conjunto de piezas.

## Plantilla

```text
<feature>/
├── foo.tscn              # contenedor: física/layout + orquesta hijos
├── foo.gd                # thin: señales hacia arriba, sockets @export
├── bar.tscn              # packed reutilizable (2º caller o F6 solo)
├── bar.gd
└── data/
    └── foo_stats.tres    # tipo; no mutar en runtime
```

Más un **mapa de responsabilidades** (una fila por archivo o nodo):

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|-------|------------------------|------|------------------------|
| `foo.gd` | Orquesta input → `apply_*` | Nodo | Si también pintara HUD, split |
| `bar.tscn` | FX / HUD / hitbox | Packed | Segundo caller o F6 |
| `foo_stats.tres` | Stats de tipo | Resource | Otra skin = otro `.tres` |

Clean: `src/features/<n>/`, `src/core/`, `src/domain/` según [clean.md](../godot-layered-architecture/clean.md).  
Estándar: junto a la escena; no inventar `src/domain/`.

## Escena de prueba

Va en el mismo árbol, bajo `res://debug/`, y en el RFC o en el `F<n>`. La construye el developer con piezas del producto. El playtester no la crea y no la altera: solo la juega.

```text
debug/
└── goal_ready.tscn     # actor + objetivo + stats_debug.tres (mismo script, otros números)
```

El estado inicial hace **fácil** el criterio (no recorrer todo el juego hasta llegar). No lo deja **ya cumplido** (el objetivo no empieza resuelto, el aviso no empieza visible). Un `.tres` de debug cambia números; no un script paralelo. `res://debug/` no entra en el export de release.

## Señales de “componé más”

- Un `.gd` pinta, spawnea, puntúa y cambia de escena.
- Copy o números de ronda hardcodeados (van a módulo / `MatchRules.tres`).
- El mismo bloque copiado en dos features → `shared/` o packed.
- HUD mezclado con reglas de partida.

## Señales de “componé menos”

- Packed scene de un ColorRect que nadie reusa.
- Autoload para el puntaje de *esta* ronda.
- `src/domain/` en un proyecto que eligió **estándar**.

## Qué pedir al usuario

Mostrá el árbol + la tabla. Preguntá: ¿está bien el corte, o querés más/menos piezas? Recién con OK corre `studio-developer`.
