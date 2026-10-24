# RFC-059: bioma de Persephone como el tutorial del original. Plan aprobado 2026-10-23

Objetivo del usuario: la apariencia del **tutorial** del original (capturas del usuario: pasto verde vivo, árboles cónicos altos en capas, coníferas chicas, arco de piedra con musgo, helechos, anillo de pilares tallados, cielo de nubes, montañas verde-grisáceas).

## Decisiones (aprobadas)
- **El bioma de Persephone usa su material nativo en cualquier mapa**, sin mezclarse con baldosas de James (corrección del usuario a P1). En un mapa de otra tierra, el suelo de Persephone se arma solo con baldosas nativas de Persephone (las del tutorial), elegidas por rol desde la tabla de baldosas de cada mapa.
- **Alpine Meadow** (tierra prsc, 2 asientos, relieve 240 m) entra como mapa **agregado** al catálogo.
- P2: si con luz y niebla no se llega a la saturación objetivo, Persephone puede cambiar el tonemapper (`LightLook.tonemap_mode`).
- P3: se reabre 055d-P8 para 059e: `BuildingType.biome_kind` + `LookProfile.props` cambia solo el modelo de los árboles de escenografía (footprint, vida y colisión intactos), después de 055d-d4.
- P4 (corregido 2026-10-24 por el usuario): `tutorial_valley` es **jugable**; se le agrega un segundo inicio con `WizardSpot`.

## Hallazgos (tech lead, con citas)
- Tutorial: `sacengine/maps/Tutorial/(tu01|tu02|tu03).scp`, tierra Persephone (`prsc`, `levl.d:43-53`). La captura de las colinas coincide con **tu02** por contenido (arco ×2, pct1 ×73, pct2 ×35, pcfe ×28, rocas pcr1–8, PCG/PCF/PCW miles); no verificado con captura desde la misma posición.
- El verde del original viene de las **baldosas nativas** (`sacmap.d:192-207`; shader `0.5*diffuse*(1+detail)*color`, `terrain2.d:202-206`). El LMAP es casi gris (sat 0,05): no es la causa.
- El port pierde el verde en tres lugares: (1) el import remapea todo a ids de James (`tools/import/land_themes.py:374-387`, WORKAROUND) y el atlas de Persephone por rol queda con sat ponderada 0,32 (nativas: 0,45–0,70); (2) tonemap AgX en `env_base.tres`; (3) niebla clara y luz gris en `persephone_sky/light.tres` (tu02: sol (140,200,255), ambiente (100,150,200), niebla lineal (80,130,150) 100–1500 m).
- Modelos (ya importados): árbol alto en capas pct2/pct8; conífera pct1/pct9; copa de hojas ptre/pct7; arco arch (pcta no verificado); rocas pcr1–9; pilar azul pcsp; cerca pcfe; plantas PCF1–4, PCG1–2, PCW5–8, PGL1–2, PCC1–2. `pcsb` (1 140 m) no es prop (probable cúpula): fuera.

## Colores objetivo (cámara fija, suelo a menos de 60 m)
| Región | Criterio |
|---|---|
| Suelo cercano | saturación media ≥ 0,60 (meta 0,75); valor 0,28–0,45; tono 70–95°; ≥ 80 % píxeles verdes (G > 1,15·R y G > 1,3·B) |
| Lomas medias | saturación ≥ 0,35 |
| Lejos | saturación ≤ 0,35 y tono ≥ 120 (la niebla se conserva) |
Port hoy: sat 0,22–0,32, valor 0,49–0,58, tono ~100.

## Árbol
```
tools/import/import_map.py      [~] --scp=PATH (acepta maps/Tutorial/*.scp); --native-tiles → tiles_native.png
tools/import/land_themes.py     [~] native_atlas(god, scp); persephone_by_role: tabla rol→baldosa nativa de Persephone
tools/import/import_themes.py   [~] el atlas de Persephone se arma SOLO con baldosas nativas (sin baldosas de James)
tools/import/measure_ground.py  [+] mide atlas y capturas contra los objetivos
assets/original/maps/alpine_meadow, tutorial_valley   [+]
scenes/map/maps/alpine_meadow, tutorial_valley        [+] (tutorial_valley fuera del catálogo jugable)
MapDefinition.native_ground     [~] @export: suelo nativo del mapa (atlas + light.png)
ground_material.gd / TerrainLayer  [~] único dueño: suelo nativo si el mapa es de la tierra del dios; si no, el atlas nativo del dios por rol
data/look/light|sky/persephone_*.tres  [~] luz y niebla del tutorial
debug/look/persephone_compare.tscn     [+] 3 cámaras fijas (suelo, arco, lomas) sobre tutorial_valley + High Noon con Persephone
```

## Sub-cortes
| Orden | Corte | Entrega |
|---|---|---|
| 1 | 059a colores | `measure_ground.py`; atlas de Persephone solo con baldosas nativas por rol; luz y niebla del tutorial; capturas antes/después de High Noon con Persephone (las mide el orquestador con ventana) |
| 2 | 059b tutorial importado | `--scp`, `--native-tiles`, `native_atlas`, `MapDefinition.native_ground`, `tutorial_valley`, `persephone_compare.tscn` |
| 3 | 059c Alpine Meadow | mapa agregado y jugable 1v1; humo `quick` (solo agrega baseline) |
| 4 | 055d-d2 | aplana 7 layouts (incluye los 2 nuevos) |
| post-d4 | 059e | `biome_kind` + `persephone_props.tres`: árboles de Persephone en mapas ajenos, solo visual |
