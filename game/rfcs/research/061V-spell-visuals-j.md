# 061V — Cómo se ven en el original Meanstalks y Tornado (061j)

Informe de arte para el corte 061j. Mismo método que `061V-spell-visuals-f-g.md`: el registro SPEL de `spells.wad` manda sobre las etiquetas por defecto del exe, y sacengine (`sacengine/source/`, solo lectura, se describe lo que hace) dice cómo lo dibuja. El usuario pidió **arte final desde el inicio**. No se vieron capturas ni videos: nada de este informe sale de una imagen del juego. Los números de juego están en `061R-abilities-structures.md` (filas `rter` y `nrot`).

## Fuentes y etiquetas

- **[SAC archivo:línea]** sacengine; si no se nombra archivo, es `state.d`.
- **[SPEL]** registro de `spells.wad` (la carpeta se llama con el nombre del hechizo **al revés**: `rter` es `retr`, `nrot` es `torn`). Claves/valores desde el byte 142, en pares de 8 bytes, la clave al revés (`xett` es `ttex`).
- **[TXTR]** texturas leídas de las WAD con `tools/import/sac_formats/txtr.py` (tamaño, color medio, alfa).
- **[EXE 0xDIR]** `Sacrifice.exe`, `objdump` de los tramos que importan.
- **[PORT]** código y datos de este repo.
- Precedencia: SPEL/EXE > sacengine > manual. Lo que no se pudo confirmar dice **NO VERIFICADO**.
- Unidades: 60 ticks por segundo; sacengine usa z hacia arriba y el port y hacia arriba (abajo, todo en ejes del port).

## Meanstalks (`rter`, SPEL `retr`, Persephone, nivel 8)

### Qué dice el SPEL
- Recursos: `ttex = dvin`, `ttx2 = vine`, `tscr = mean`.
- Sonidos (tabla del byte 112): `akts`, `hkts`, `pkts`, `fkts`, con banderas 2, 4 (lazo), 8 y 16. Las etiquetas están al revés: son las muestras `stka`, `stkh`, `stkp` y `stkf` de `sfx/pers/` (existen en `assets/original/audio/sfx/pers/`). Ya están importadas.
- Los números (60 s, velocidad 30, aceleración 3, 500 de daño, alcance 60) están en `data/catalog/spells/rter.tres`. `amount3 = 4` no se guarda en `SpellType`; el tope de 4 tallos es constante en sacengine (`Meanstalks.maxVines=4`, state.d:4430), así que en el port es el número de hijos `Stalk` de la escena.

### Texturas [TXTR]
| Etiqueta | Dónde | Tamaño | Color medio | Qué es |
|---|---|---|---|---|
| `dvin` | `charlie.wad` `Bloo.WAD!/Pers.FLDR/tex.FLDR` | 64² | (0,18; 0,30; 0,04) | verde oscuro uniforme con trama fina: la piel del tallo |
| `vine` | ídem | 64² | (0,47; 0,38; 0,10) | degradado vertical de verde (arriba) a naranja (abajo); ya importada para Grasping Vines |
| `mean` | ídem | SCAR (9232 bytes) | — | la cicatriz del suelo en cada raíz. **No hay lector de SCAR**: queda sin dibujar (igual que `scar` de Explosion, 061f) |

### Qué usa el exe [EXE 0x42e040-0x42e1c0]
La rutina que arma el hechizo lee `ttex` (por defecto `vine`) y lo guarda en la ranura de textura 0, lee `ttx2` (por defecto `vine`) y lo guarda en la ranura 1, las dos con la bandera `0x10001` (malla con luz, la misma de `jspk` y de `vine`), y lee `tscr` y `tdrt` (partículas de tierra). Por defecto las dos ranuras son `vine`, y el SPEL de Meanstalks cambia la primera a `dvin`. **NO VERIFICADO:** qué parte de la malla toma la ranura 0 y cuál la 1. sacengine dibuja todo el tallo solo con `vine` (renderer.d:378-388, sacobject.d:3606-3612).

### Cómo lo dibuja sacengine
- **Malla:** un tubo de 31 segmentos × 64 lados con piel (hueso por anillo) [SAC sacobject.d:3566-3604]. Radio del anillo `t` de 0 (base) a 1 (punta): de 2 m a 1,8 m en la primera mitad (Bézier 2, 2, 2, 1,8) y de 1,8 m a 0 en la segunda (1,8; 1,6; 1,0; 0). Coordenada `v` = posición a lo largo; `u` = vuelta.
- **Material:** con luz (`boneMaterialBackend`), brillo 1, rugosidad 1, metálico 0,5 [SAC renderer.d:379-387].
- **Curva:** el tallo sigue dos curvas cúbicas, `curve0` = [base, base + 10 arriba, base + curva − 10 dir, base + curva] y `curve1` = [base + curva, base + curva + 10 dir, …, punta]. `curva` = mitad del vector base→punta + una panza que empuja de lado (`0,5·(√t + t^¼)`, con `t = 900 − 0,25·largo²`, solo si el largo < 60 m) [SAC state.d:11419-11440]. Un marco (`framevec`) evita que la panza gire de golpe.
- **Pose:** cada anillo `i` toma la posición y la tangente de la curva en `t = i/31` y gira el anillo de `+z` a la tangente [SAC renderer.d:2264-2278].
- **Casting:** al lanzar, los tallos nacen 60 m **bajo** el suelo y suben mientras el progreso del lanzamiento crece (`scaleTarget = progreso`); luego `scale` sube 1/180 por tick (3 s) hasta 1. Cada 6 ticks que crecen hacen temblar la pantalla (intensidad 1, 50 m) [SAC state.d:22664-22675, 22508-22510].
- **Aparición:** 64 partículas `dirt` por tallo en un disco de 3,3 m, escala 3,75, 128 a 160 ticks de vida [SAC state.d:11403-11417]; sonido `akts` con ganancia 4.
- **Agarre:** sonido `hkts`; el tallo agarra con la punta a menos de 0,1 m del blanco, le hace los 500 de daño de hechizo directo, y lo sube hacia `base + 60` arriba con velocidad máxima 42 y aceleración 4,2; mientras lo sostiene, el centro del cuerpo está en la punta. A menos de 7 m del tope lo suelta con la velocidad de la punta y sin enfriamiento [SAC state.d:22618-22653, 22682-22688].
- **Fin:** al terminar el tiempo, sonido `fkts`, se encoge 3 s y se hunde [SAC state.d:22654-22662].
- **Luz:** el exe no llama a la luz dinámica en esta función (no hay `0x44ca20` en 0x42e040-0x42e2a0). Color de la luz del port: el dominante de `dvin` (verde amarillento).

### Para el port
| Parte | Recurso | Notas |
|---|---|---|
| Tubo | malla horneada `stalk_tube.res` (31 × 24) + `stalk.gdshader` | el shader pone cada anillo en la curva; sin hueso |
| Piel | `dvin.png` (ranura 0) y `vine.png` (ranura 1) | `vine` pinta la punta (v alta) y `dvin` el resto; mezcla con un degradado en `v`, knob en el material. NO VERIFICADO el reparto exacto |
| Tierra al nacer | `dirt.png` (ya importado), partícula nueva `stalk_dirt.tres` | 64 de escala 3,75, vida 2,1 a 2,7 s |
| Sonidos | `stka`, `stkh`, `stkf` | cues nuevos en `data/audio/fx_sounds.tres` |
| Casting del mago | partícula `heal` (`glo2`) | [SAC state.d:22498-22501] |
| Luz | `ActorLight` en cada tallo, verde `(0,6; 1,0; 0,15)` | color medio de `dvin` normalizado; sin sombras |
| Agarre (estallido) | `FxLightSpec` en el `ParticleType` del agarre | mismo verde, corta |

## Tornado (`nrot`, SPEL `torn`, Stratos, nivel 8)

### Qué dice el SPEL
- Recursos: `ttx1 = trn1`, `ttx2 = trn2`, `ttx3 = edge`, `tcst = cst0`, `fCHs = 0,25`, `ttrl = tdst`, `tsfx = seTO` (**NO VERIFICADO** qué es; contra el índice de muestras del port no existe ni `seto` ni `otes`, 2026-10-25).
- Sonidos: `nrot` (lazo; bandera 2 y `!`) y `snrt`. Al revés: `torn` y `trns`. Existen en `assets/original/audio/sfx/stra/` (`torn.wav`, `trns.wav`).
- Números en `data/catalog/spells/nrot.tres`: 25 s, velocidad 6, aceleración 0,6, alcance de vagabundeo 50 m.

### Texturas [TXTR]
| Etiqueta | Dónde | Tamaño | Color medio | Qué es |
|---|---|---|---|---|
| `trn1` | `charlie.wad` `Bloo.WAD!/Stra.FLDR/txtr.FLDR` | 256² | (0,14; 0,13; 0,13), alfa 1 | vetas de viento gris oscuro en diagonal |
| `trn2` | ídem | 256² | igual | casi igual que `trn1`, con otras vetas |
| `edge` | ídem | 256² | (0,13) con alfa medio 0,39 | 4 columnas de 64 px: el borde dentado del embudo, negro con alfa |
| `tdst` | ídem | 256² | (0,12; 0,12; 0,11), alfa 0,33 | atlas 4×4 de nubes de polvo oscuras |

### Cómo lo dibuja sacengine [SAC sacobject.d:3621-3760, renderer.d:3453-3481, state.d:4456-4505]
- **Eje:** siete puntos de control, de la **cima** (500 m sobre el punto del hechizo, fija) al **pie** (la posición del tornado, que vaga). `pie = cima + escala·(posición − cima)`. Los puntos 2 y 4 se desvían de lado `0,3 · altura · sin(fase)` con 4 fases que giran a 0,6; −0,48; −0,78; 0,36 rad/s.
- **Radios:** 300 en la cima, luego `w + (b − w)·{0,6; 0,6; 0,675; 0,75; 0,95}` con `w = 100` y `b = 1,5` (6,4 m a un séptimo de la altura sobre el pie, 1,5 m en el pie).
- **Mitades:** la mitad de arriba (puntos 0 a 3, 128 anillos) lleva `trn1` con alfa `t(3 − t)²/4` (0 en la cima); la mitad de abajo (puntos 3 a 6) lleva `trn2` con v invertida y alfa 1; sobre la mitad de abajo va una **tira** de `edge` cuyas caras miran a la cámara (un cuarto de columna cada 0,25 s, `animPhase = 15 por s`, 4 cuadros). Los tres materiales: sin luz, transparentes, energía 10 (los dos primeros) u 8 (el borde), transparencia 0,9.
- **Giro:** los vértices de cada anillo giran con `spinPhase`, una vuelta por segundo (2π por s).
- **Alfa general:** `⁴√min(1, 1,5·escala)`.
- **Polvo:** `tdst` a la altura del suelo, 0 a 2 partículas por tick según la altura del pie sobre el suelo (`0,4·(5 − h)`), disco de 15 m, escala 1,4 a 2,8, vida 1,125 s, alfa [SAC state.d:22802-22823].
- **Casting del mago:** partículas `cst0` (energía 3, 2 m) en espiral alrededor del mago que se cierran hacia él (`relativeTwirl`, 1,125 s), más un relámpago corto en su caja con 50 % de probabilidad por tick [SAC state.d:22708-22731].
- **Luz:** ninguna en el exe. Color de la luz del port: el gris neutro de `trn1`.

### Para el port
| Parte | Recurso | Notas |
|---|---|---|
| Embudo | malla horneada `funnel_rings.res` (128 anillos × 48 lados) y `tornado_funnel.gdshader` | el shader evalúa las dos cúbicas del eje desde 7 puntos y 7 radios (uniformes) |
| Tira de borde | malla horneada `funnel_edge.res` + el mismo shader (modo borde) | de cara a la cámara con `INV_VIEW_MATRIX` |
| Polvo | `tdst.png`, `tornado_dust.tres` | alfa, no aditivo |
| Casting del mago | `cst0.png` (ya importado), `tornado_cast.tres` en `CastGlow` | la espiral se aproxima con un emisor alrededor del mago (declarado) |
| Sonidos | `torn` (lazo), `trns` | cues nuevos |
| Luz | `ActorLight` en el pie, gris neutro, sin sombras | moderada |

## NO VERIFICADO
- Qué parte del tallo usa `dvin` y cuál `vine` (el reparto del port es un degradado en v).
- `tsfx = seTO` del Tornado.
- Si el exe también descuenta dos veces el tiempo del tallo (sacengine resta 1 en el cuadro de escala 1 y otra vez en el rango de modos 2 a 8: 30 s efectivos de 60). El port usa el dato (60 s).
- La energía exacta con que el exe pinta el embudo bajo su curva de tonos: los valores del port (`energy`, `opacity`) son conservadores y son knobs del material.
- La altura de 500 m de la cima de la columna (es del código de sacengine, no se leyó en el exe).
- Las partículas `pkts` (sonido del tallo al acercarse) están comentadas en sacengine: no se reproducen.

## Cómo se leyó (sin rutas personales)
- **SPEL:** `wad.walk(spells.wad)`, registro `retr` / `torn`; bytes 112-141 la tabla de sonidos `[bandera][' ' o '!'][etiqueta al revés]`; desde el 142 pares clave/valor.
- **Texturas:** `sac_formats.txtr.folder_texture` sobre `Bloo.WAD!/Pers.FLDR/tex.FLDR` y `Bloo.WAD!/Stra.FLDR/txtr.FLDR`, y promedio ponderado por alfa.
- **EXE:** buscar `push imm32` de la etiqueta `ttx2` y `objdump -d` de 0x42e040 a 0x42e1c0.
- **Importar:** `tools/import/import_ui.py` (entradas nuevas en `EXTRA_FX`: `dvin`, `trn1`, `trn2`, `edge`, `tdst`).
