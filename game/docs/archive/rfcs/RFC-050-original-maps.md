# RFC-050: importar mapas del original

Estado: implementado (F320–F323).
Pedido: «importa 4 mapas, principalmente me importan los mapas chicos, mientras más pequeño mejor. Y un mapa grande para 2v2».

## 1. Qué había

- La instalación local (`/Users/joelsartori/Downloads/sacgame/Sacrifice/maps/`, la ruta que leen los importadores: `tools/import/sac_formats/install.py`, o `SAC_MAPS`) tiene 31 mapas de varios jugadores: 13 `(2)`, 6 `(3)` y 12 `(4)`.
- `import_map.py` estaba fijo en `(2) High Noon.scp` y `terrain.py` leía el HMAP de un desplazamiento fijo de ese archivo. `bake_map_layout` fijaba la raíz `HighNoonLayout` y las etiquetas `jaal`/`jfnt` (James). `import_terrain.gd` escribía siempre en `high_noon`.
- RFC-044 ya dejó el resto: una carpeta `scenes/map/maps/<tag>/`, una `MapDefinition`, `data/maps/map_catalog.tres` y `--map=<tag>`.

## 2. Los 31 mapas

Todos tienen una grilla de 256×256 celdas de 10 m (2,56 km de lado); lo que cambia es la tierra firme. «Asientos» son los bandos con `assignment & 31 != 0` de sus SIDS. «Celdas» son las celdas de tierra (sin vacío) y «km²» su área (celdas × 100 m²). «Edif.» y «Cria.» son las filas de estructuras y criaturas de su NTTS (los edificios incluyen altares y manantiales). Ordenado por asientos y tamaño.

| Mapa | Asientos | Tierra | Celdas | km² | Edif. | Cria. |
|---|---|---|---|---|---|---|
| Peaks | 2 | Charnel | 1.254 | 0,13 | 39 | 0 |
| High Noon (ya estaba) | 2 | James | 3.174 | 0,32 | 76 | 32 |
| Valley of the Dead | 2 | Charnel | 5.155 | 0,52 | 33 | 22 |
| Peasantville | 2 | James | 5.388 | 0,54 | 151 | 53 |
| Roads | 2 | Pyro | 6.020 | 0,60 | 113 | 16 |
| Trial | 2 | Persephone | 7.417 | 0,74 | 135 | 12 |
| Faceoff | 2 | Persephone | 8.244 | 0,82 | 78 | 16 |
| Ferry | 2 | Stratos | 13.119 | 1,31 | 98 | 20 |
| Alpine Meadow | 2 | Persephone | 14.317 | 1,43 | 106 | 10 |
| Closest Combat | 2 | Charnel | 16.509 | 1,65 | 60 | 0 |
| Fork In The Road | 2 | Persephone | 23.748 | 2,37 | 134 | 24 |
| Stone's Throw | 2 | Persephone | 29.717 | 2,97 | 144 | 0 |
| Cathedral | 2 | Persephone | 33.567 | 3,36 | 135 | 24 |
| Firefight | 3 | Pyro | 4.651 | 0,47 | 69 | 6 |
| Gladiator | 3 | Charnel | 6.033 | 0,60 | 39 | 24 |
| This Island Burnt | 3 | Pyro | 9.592 | 0,96 | 151 | 18 |
| Triad | 3 | Persephone | 18.154 | 1,82 | 96 | 24 |
| Molehill | 3 | Stratos | 18.724 | 1,87 | 97 | 15 |
| Trenches | 3 | James | 34.109 | 3,41 | 247 | 0 |
| Devil's Tails | 4 | Charnel | 6.129 | 0,61 | 33 | 26 |
| Genie | 4 | Charnel | 6.162 | 0,62 | 45 | 32 |
| Joust | 4 | Pyro | 6.507 | 0,65 | 53 | 32 |
| Snowy Plains | 4 | Stratos | 6.533 | 0,65 | 45 | 24 |
| Star | 4 | Charnel | 7.229 | 0,72 | 39 | 40 |
| Kirwan | 4 | James | 8.286 | 0,83 | 65 | 20 |
| Faceoff Returns | 4 | Persephone | 8.548 | 0,85 | 92 | 32 |
| Iron Cross | 4 | Stratos | 8.579 | 0,86 | 92 | 40 |
| Exe | 4 | James | 9.582 | 0,96 | 46 | 20 |
| Hamburger Hill | 4 | James | 10.471 | 1,05 | 84 | 19 |
| Pinched | 4 | Charnel | 21.877 | 2,19 | 44 | 16 |
| Web | 4 | Stratos | 35.142 | 3,51 | 131 | 0 |
| WinterWonder | 4 | Stratos | 38.475 | 3,85 | 92 | 17 |

`python3 tools/import/import_map.py --list` imprime esta tabla desde la instalación.

## 3. Elección

Chicos (los 3 más chicos con 2 asientos que el port puede jugar hoy, sin contar High Noon, que ya estaba):

1. **Peaks** (`peaks`): el más chico de los 31, 0,13 km² (el 40 % de High Noon). 2 asientos, 5 manantiales, 32 edificios, sin criaturas.
2. **Peasantville** (`peasantville`): 0,54 km², 2 asientos, 53 aldeanos y 142 edificios. Tierra James, la de High Noon: el suelo se ve igual que el ya conocido.
3. **Roads** (`roads`): 0,60 km², 2 asientos, 103 edificios y 16 aldeanos.

Se saltaron dos mapas más chicos que Peasantville y Roads a propósito: **Firefight** (0,47 km²) tiene 3 asientos y **Valley of the Dead** (0,52 km²) trae un bando con `assignment` 64 que `SideRelations` leería como asiento y dejaría a los demás bandos sin slot. Los mapas de 3 asientos y ese bando piden un cambio de reglas (RFC-049), no de importación. Trial (0,74 km²) queda de reserva.

Grande, para 2v2: **WinterWonder** (`winter_wonder`, el mapa de nieve de Stratos), 3,85 km², el más grande con 4 asientos de los 31. Tiene un bando de NPC (5 criaturas `ycrp` y 12 `zepa`), 78 edificios, 4 altares y 10 manantiales; sus 4 inicios caen en una misma región del navmesh. Web (3,51 km²) es parecido pero no tiene habitantes; Pinched (2,19 km²) es más chico que lo que se pidió.

## 4. Qué cambia

Una sola cadena para cualquier mapa (los comandos van en `docs/HOWTO.md`, «Un mapa»):

1. `tools/import/import_map.py --map=<Nombre>`: `tiles.png`, `light.png`, `ntts.json`, `widgets.json` en `assets/original/maps/<tag>/`. Sin `--map` sigue siendo High Noon, byte a byte igual. El tag sale del nombre (`WinterWonder` → `winter_wonder`). El HMAP se busca por su etiqueta en el directorio del `.scp`, ya no por desplazamiento fijo.
2. `tools/import/scaffold_map.py --map=<Nombre>`: `sides.tres`, la `MapDefinition`, `map.tscn` (un `PlayerStart` por altar de jugador a su altura de suelo, mirando al manantial más cercano; un `Fount` por manantial) y la entrada en el catálogo. Las etiquetas de altar y manantial son una lista por tierra (`jaal`/`jfnt`, `ca_a`/`cafn`, `pyal`/`pfon`, `stal`/`stmf`, `alt1`/`font`).
3. `tools/bake/import_terrain.gd -- --map=<tag> --bin=F` (`terrain.res`), `terrain_glb_export.gd -- --map=<tag>` (`terrain.glb`, con `tiles.png` ya importado), `--import`.
4. `tools/bake/bake_map_layout.gd -- --map=<tag> --force` (`layout.tscn`, raíz `<Tag>Layout`; ya no fija `HighNoonLayout`) y `bake_nav.tscn -- --map=<tag>` (`nav.res`; `--check` dos veces).
5. El minimapa no tiene bake offline: `MinimapBake` del `map.tscn` toma la malla del `Terrain` del mapa.

### Decisiones que se notan

- **Suelo.** Los atlas de suelo indexan las baldosas de James. Un mapa de otra tierra (Peaks Charnel, Roads Pyro, WinterWonder Stratos) pasa sus ids de baldosa a los de James por rol con el mismo `land_remap` que ya usan los temas (`land_themes.map_tiles`); ninguna celda quedó sin equivalente. Los atlas de los otros dioses solo llevaban los ids de High Noon: `import_themes.py` suma los ids de los demás mapas con el mismo mapeo de grupos base (los de High Noon no se mueven). Cambiaron solo los `atlas.png` de Persephone, Pyro, Stratos y Charnel; el de James y todo lo de High Noon quedó igual.
- **Plantas.** Solo existen los modelos de los widgets de James. Las etiquetas sin modelo (`CAH1`, `PYA1`, `SAW1`...) ya no caen en las flores de Persephone: no plantan nada, y el bake lo dice. Peaks, Roads y WinterWonder quedan sin plantas; Peasantville tiene 1.530. WORKAROUND hasta importar los modelos de widgets de cada tierra.
- **`terrain_import.gd`.** Tomaba `tiles_path` del `Terrain` vacío y fallaba en cualquier `--import` desde cero («could not build the visual mesh»), también con High Noon. Ahora lee el `tiles.png` junto al glb.
- **Asientos.** `MapDefinition.player_starts` es el número de asientos del mapa (4 en WinterWonder). `SacrificeFlow.max_players` sigue en 2: el 2v2 es de RFC-049.

## 5. Fuera

- Plantas y modelos de widgets de las otras tierras.
- Vistas previas (`preview_path`) para las pantallas de sala.
- Altares y manantiales con el modelo de su tierra (hoy todos usan `altar.tscn` y `manafount.tscn`).
- Un mapa de 3 asientos (Firefight, Gladiator...) y el bando 64 de Faceoff y Valley of the Dead.
- El 2v2 jugado (lobby, colores, HUD): RFC-049. Con WinterWonder queda 1v1 en los asientos 1 y 2 hasta entonces.

## 6. Criterios

- Por mapa: `bake_nav -- --check` PASS dos veces, `check_map_starts` PASS, humo `agent/runs/run_050_maps.sh <tag>` (IA contra IA 0,5 min: `AI_REPORT`, sin `SCRIPT ERROR`), `CATALOG PASS`.
- High Noon no cambia: `bake_nav --check` y `bake_map_layout --check` PASS sin re-hornear, `quick` sin regrabar.
