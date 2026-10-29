# Plan v2: del port funcional al juego «human first, Godot priority»

Fecha: 2026-10-23. La v1 del port está en `main` (`840be169`). Este plan cubre los puntos que el usuario reportó al probarla, ordenados por cómo conviene atacarlos. El análisis del código y el orden del refactor grande van en `docs/archive/rfcs/RFC-055-human-first-refactor.md` (en curso).

## 1. Qué reportó el usuario y dónde cae cada cosa

| # | Reporte | Tipo | Dónde se resuelve |
|---|---|---|---|
| 1 | Los voladores mueren y quedan flotando; el alma también | Bug | Parche hecho (`bb324052`: el muerto cae). La solución real es el corte A, muerte con ragdoll. |
| 2 | Las unidades caminan hacia atrás sin girarse; parecen ir de espaldas | Bug | Parche corto en movimiento: el cuerpo mira hacia donde se mueve. Se verifica contra sacengine. Después lo absorbe el corte B, unidades. |
| 3 | No hay selector de dificultad | Falta | Parche corto en el boot (049h lo dejó solo en sala y servidor local). |
| 4 | No hay selector de mapa por tipo, sin azar ni dios | Falta | Parche corto en el boot: elegir el mapa a mano, con el bioma del mapa, sin sorteo. |
| 5 | Al invocar un doctor se ve la barra de vida del cadáver | Bug | Parche corto: el cadáver no muestra barra mientras lo cargan. |
| 6 | En el editor no se ven edificios ni NPC (`PeaksLayout` los instancia en runtime) | Diseño | Corte C, mapa como nodos: cada edificio, NPC y árbol es un nodo visible y movible, con placeholder que el bioma reemplaza. |
| 7 | La muerte debería usar la física de Godot (ragdoll) | Diseño | Corte A. |
| 8 | `BuildingType` muestra flags, folder y components del WAD | Diseño | Corte C: el edificio es una escena con nombre, vida, modelo y tamaño. Lo del WAD queda solo en `tools/import`. |
| 9 | `FloraMap` muestra arrays de bytes | Diseño | Corte C: la flora se pinta o se ubica con nodos de dispersión en el editor; la densidad del original se importa una vez como punto de partida. |
| 10 | Los pobladores no huyen cuando los golpean | Falta | Corte B, con una FSM visible: `Idle / Work / Flee / Cower`. Se puede adelantar como parche si molesta. |
| 11 | Faltan habilidades del mago | Falta | Corte D, mago y libro de hechizos como `.tres`. Las habilidades nuevas entran ahí, una por una. |
| 12 | Faltan estructuras | Falta | RFC propio después del corte C, porque las estructuras son edificios con comportamiento. |
| 13 | Hechizos que deforman el terreno (volcán, tornado) | Falta | RFC propio al final: terreno deformable con recálculo de colisión y navmesh. |
| 14 | Faltan luces en hechizos, unidades y habilidades | Falta | Corte E, look: cada hechizo, unidad y mago lleva su `OmniLight3D` como nodo hijo, configurable en el inspector. |
| 15 | Bioma de Persephone más rico: verde, árboles, arcos | Falta | RFC-059 Bioma Persephone (tutorial como referencia, kit propio en Blender), fase 2. |
| 16 | Insectos, partículas, lluvia, día y noche, clima | Falta | RFC-058 Ambiente (`TimeOfDay`, `Weather`, `AmbientLife`), fase 2. Ver RFC-055 §13.3. |

## 2. Orden propuesto

**Actualizado 2026-10-23:** el orden vigente y el registro de deprecación del 1 a 1 están en `docs/archive/rfcs/RFC-055-human-first-refactor.md` §13. El refactor va antes que cualquier contenido nuevo.

### Fase 0: parches cortos, esta semana
Sin refactor, cada uno en un commit. Son los puntos 2, 3, 4 y 5, y si molesta, el 10.

### Fase 1: refactor por sistema, con el árbol revisado por el usuario antes de cada corte
Cada corte tiene su árbol de nodos, que el orquestador le devuelve al usuario para que lo apruebe antes de implementar.

- **A. Muerte, cadáver y alma.** El alma sale, el cuerpo cae con ragdoll o con un `RigidBody3D` simple y queda tendido. El doctor desvanece el cuerpo y lo hace aparecer en el alma. Cubre 1 y 7.
- **B. Unidades.** Escena por unidad: `.tres` de stats, `Area3D` de visión (esfera o cono), armas y ataques como nodos hijos, FSM visible. Cubre 2 y 10.
- **C. Mapa.** Edificios, NPC, árboles y flora como nodos en el editor. Cubre 6, 8 y 9. Deja la base para 12.
- **D. Mago y hechizos.** El mago es una escena con un `.tres` de libro; cada hechizo es una escena configurable. Cubre 11.
- **E. Look.** Cableado del cielo simplificado, luces por nodo, bioma de Persephone nuevo. Cubre 14 y 15.

### Fase 2: contenido nuevo sobre la base limpia
Estructuras (12), clima y ambiente (16) y terreno deformable (13), en ese orden.

### Fase 3: multijugador como envoltorio
Refactor de MpKit: cada feature es un caso de uso y un wrapper hace el cableado de red. Se diseña desde la fase 1, se implementa acá.

## 3. Reglas para todo el plan
- Lo que se rehace se construye como lo haría una persona en Godot: nodos, escenas, `.tres`, inspector. Nada de datos crudos del original en el inspector.
- El código original de sacengine sirve para saber qué hace el juego, no para copiarlo.
- Scripts cortos, un dueño por estado, patrones solo cuando hacen falta.
- Lo rehecho puede ir a capas Clean si simplifica el multijugador; se decide en el RFC-055.
- El banco de determinismo sigue siendo humo: se regraba al cerrar cada corte.
