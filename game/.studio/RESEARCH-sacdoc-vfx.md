# VFX del ciclo del Sac Doctor (acarreo, vórtice, ritual)

Fecha: 2026-10-13. Lectura estática. Fuentes: **[S]** sacengine (archivo:línea), **[W]** web, **[X]** exportador y datos del port. Nada se corrió.

## Resumen: cómo se ve el acarreo en el original

- La criatura va en el aire detrás del doctor, **dentro de un anillo/portal azul-cian plano** que la rodea (un aro con borde animado y un centro luminoso, dibujado como sprite que mira a cámara), de tamaño ~0,65 × la diagonal de su caja de colisión. Aparece creciendo en 1 s y se achica en 0,75 s al soltarla. [S]
- Del **extremo de la aguja** (hueso de la mano 16, a 2,2 de la mano) al **centro de la criatura** corre una **cuerda eléctrica** de 5 puntos (spline), con aspecto de rayo (textura `ltn2`, aditiva), que ondula como un resorte amortiguado detrás del doctor y pulsa de brillo. De la punta de la aguja salen chispas. [S]
- La criatura va en modo `thrashing`: animación `float2Thrash` y después `thrash` (se retuerce), no en reposo. [S]
- Esto coincide con lo que dijo el usuario («portal conectado a un rayo»). **Ninguna referencia web visual** lo confirma: no conseguí ni captura ni video donde se vea (ver «No verificado»). Lo único web: reseña alemana que dice que el doctor sale de un portal **rojo** con una jeringa gigante.

## 1. El acarreo

**[S] Dos piezas, ambas solo en `status == move` (y el vórtice también en `shrinking`):**

1. **Vórtice azul alrededor de la criatura** (`renderer.d:1638-1677`).
   - Posición: centro de la hitbox de la criatura. Escala: `vortexScale · 0,65 · (1,1·|size|, 0,9·|size|, 0)`, con `size` = tamaño de la hitbox (`renderer.d:1639-1644`). Es un sprite (`setSpriteTransformationScaled`).
   - Dos capas aditivas: `blueRim` (textura `ltn2`, energía 10) y `blueCenter` (textura `vtx3`, energía 1) (`renderer.d:222-239`).
   - Anillo (`SacVortex.createRimMeshes`, `sacobject.d:4057-4100`): corona circular de radio 1, 512 segmentos (`16·32`), grosor 0,35 del radio (tres vértices por segmento: borde, medio y fondo a 0,35). Cada una de las 16 celdas 4×4 de la textura es un fotograma; se cicla `frame % 32` a 60 fps con `updateAnimFactor=2`, es decir 16 fotogramas × 2 ticks, 0,53 s por vuelta. UV en zigzag a lo largo del anillo (la textura se repite 32 veces).
   - Centro: sprite 2×2 con la misma animación de 16 celdas (`sacobject.d:4104-4105`).
   - Aparición: `vortexScale += 1/60` por tick hasta 1 (1 s). Al soltar: `shrinking`, `-= 1/45` (0,75 s) (`state.d:2697-2698`, `15622-15624`, `15700-15701`).
2. **Cuerda doctor-criatura** (`SacDocTether`, `state.d:2664-2669`, `15556-15613`; render `renderer.d:1678-1703`).
   - Origen: `needle[0]` = posición de la mano (hueso 16) con offset (0,0,2,2) del modelo `sacd`, por la matriz de la animación actual, ×escala (`sacobject.d:360-366`). `needle[1]` = eje Z de ese hueso, es decir hacia dónde apunta la aguja.
   - Fin: `obj.center` de la criatura.
   - 5 puntos de control. p0 = punta de aguja; p1 = p0 + 1,5·needle[1] (la cuerda sale primero a lo largo de la aguja); p2..p4 repartidos linealmente entre p1 y el centro (`state.d:15556-15567`). p0, p1 y p4 siguen al blanco rígidamente; p2 y p3 son masas con resorte: `a = 120·|d|^(2/7)·d` (d = objetivo − posición), amortiguación `0,25` por segundo, velocidad relativa máxima 20 (`state.d:15577-15600`). Resultado: la cuerda se arquea y se queda atrás al caminar.
   - Malla: `makeLineMeshes(numSegments=19, nU=4, nV=4, length=0, size=0,3, pointy=true)` (`sacobject.d:4446-4459`, `2189-2227`). Cada segmento es un prisma de 3 caras (tres planos a 120°, radio `size=0,3`) con puntas afiladas en los extremos. Se deforma con 20 huesos (`numSegments+1`), cada uno posicionado en la curva `tether.get(i/20)` y orientado con la tangente (`renderer.d:1693-1700`). 16 fotogramas (celdas 4×4 de `ltn2`), `frame % 32` a 2 ticks por celda; textura repetida y volteada en segmentos alternos.
   - Material: aditivo, sin escritura de profundidad, sin culling, base `energy=15`. Pero se sobreescribe por tick: `energy = 0,375 + 14,625·(0,5 + 0,25·cos(7α) + 0,25·sin(11α))`, `α = π·frame/60` (`renderer.d:1688-1690`). Pulso de brillo entre ~0,4 y ~15 con dos frecuencias (3,5 y 5,5 rad por... en unidades de `π·frame/60`; período de pulso lento ≈ 0,57 s).
   - Chispas en la aguja: por tick 2 partículas `needle` (atlas `cst0`, 4×4, 1×1, energía 3), posición = punta, velocidad = `U(1,5; 2)·(needle[1] + U(0,2; 1)·dirAleatoria)` con `vz *= 2,5`, escala `U(0,5; 1)`, vida `31 + U(0..31)` ticks (`state.d:15602-15612`, `sacobject.d:1479-1484`).
3. **Cambia entre Convert y Desecrate**: no. La rama `move` es idéntica; la única diferencia es qué se lleva (criatura revivida en Convert, criatura propia viva en Desecrate) y el tamaño del vórtice depende de la hitbox (`state.d:15767-15790`). [S]
4. **Web**: no hay descripción ni imagen del acarreo (ver sección «Web»).

## 2. La criatura llevada

- `startMoving` (`state.d:15634-15660`) llama `startThrashing` (`state.d:10135-10145`): modo `thrashing`, movimiento `flying`, se deselecciona y sale de grupos.
- Animación (`state.d:8200-8223`, orden de preferencia): si venía de muerte (`death0/1/2`) y tiene `corpseRise`, usa `corpseRise`; si no, `rise` si existe; si no `float2Thrash`; si no `thrash`. Para el acarreo en Convert la criatura viene de `convertReviving` (revivida), luego `startThrashing` aplica esta regla. Tags del slot en `animations.d:26,50` (`thrash`, `float2Thrash`). Por lo tanto: **estado `thrashing`, slot `float2Thrash` → `thrash`** (o `rise`/`corpseRise` si el modelo los tiene). El port hoy no la tiene: queda en reposo.
- Posición: `sacDoc.position + rotar(facing, (0, −(2 + 0,5·|escala|), 3,5))`; se acerca a esa posición a `1,1·velocidadSuelo/60` por tick si dista >0,75 (`state.d:15767-15775`). No hay balanceo ni giro explícitos; solo lo que da la animación `thrash`.
- Mientras la sostiene el ritual: se mueve hacia `altar + (0,0,15)` con media móvil en `setupTime` (`state.d:15935-15937`).

## 3. El vórtice rojo

- Datos (`state.d:2630-2642`): radio 2,5; emerge 120 ticks (2 s), dura 120 ticks, se cierra en 60 ticks (1 s); altura 15 m sobre el terreno; distancia 20 m (Convert) / 12,5 m (Desecrate, en el ritual).
- Forma: **disco/anillo plano orientado a cámara (sprite)**, no remolino 3D. Dos capas aditivas con la misma animación de 16 celdas: `redRim` (`vtx1`, energía 10) y `redCenter` (`vtx2`, energía 1), con la misma malla de anillo (corona 512 segmentos, grosor 0,35) y centro 2×2 que el azul (`renderer.d:1616-1637`, `222-239`; `sacobject.d:4051-4052`). Escala `vortex.scale · 2,5`.
- Gotas: con `scale > 0,3`, 2 partículas por tick `redVortexDroplet` (atlas `vtx2`, 1×1, energía 3, delay 2) en un disco de radio `0,35·2,5` centrado en `−0,8·2,5` bajo el vórtice, con velocidad (≈0,1 aleatoria, −5 en z) (`state.d:15463-15485`, `sacobject.d:1503-1508`).
- Del vórtice cae el doctor: `position.z = max(z − 0,9·2,5, altura terreno)`, salta con velocidad 10 hacia el punto de aterrizaje (`state.d:15487-15506`).
- En el ritual Desecrate hay otro vórtice rojo sobre el mago enemigo, a 12,5 m de él hacia el altar, a 15 m de altura (`state.d:15878-15889`, `15961-15973`).
- Web: la reseña alemana dice «portal rojo» (coincide). Sin imagen.

## 4. El «pump» de Convert

- Se ve: animación `stab` (slot `attack0`... ver nota) del doctor; en `pumpCorpse` (`attack1`) la criatura sigue en `convertReviving` y el alma pasa a `SoulState.reviving`; sonido `convertRevive` (`jncX`) a ganancia 2,0 sobre el doctor (`state.d:15744-15750`, `8668-8682`).
- Efecto propio dibujado: **ninguno** encontrado: no hay malla, partícula ni haz para el pump en `state.d` ni `renderer.d` (solo la animación, el sonido y el revivir del modelo). [S, búsqueda por grep de `pump`; no leí todo `state.d`, por eso va también en «No verificado»]
- Duración: `(almas+1)·5 s` (`state.d:15697`).
- Nota: `startPumping` pone `stab` (`state.d:8189-8191`); `pumpCorpse` es `attack1` (`animations.d:93`), y el temporizador solo corre cuando la animación es `pumpCorpse`. Lo que se ve primero es el clavado y después el bombeo.

## 5. El ritual (4 doctores, Convert y Desecrate)

[S] `updateRitual`, `state.d:15893-16045`.
- Posiciones: radio 20 → hasta 17 m, a 45° + 90°·k (`ritualPositions`, `15854-15863`). Preparación 5 s. Ronda 13,5 s = 4,5 caminar + 4,5 tortura + 4,5 espera.
- **Rayos del doctor a la criatura** (`ritual.tethers[k]`, 4): misma `SacDocTether`/malla/material que el acarreo, pero con `needleExpansion = NaN`: **p1 = no hay codo**, los 5 puntos reparten entre aguja y centro de la criatura; al empezar (frame de animación `tortureStart = 2·5`) cada punto interior recibe una sacudida aleatoria de 3 m (`state.d:15980-15990`). Se actualizan entre frames de animación 10 y 260 (`tortureEnd = 2·130`), luego se borran.
- **Rayos del altar** (`altarBolts[2]`): `LightningBolt` de 10 segmentos desde `altar + (0,0,60)` hasta el centro de la criatura (`renderer.d:1948-1953`). Cambian de forma cada 9 frames (`changeShapeDelay`), desde `walkTime + 10 + 10` hasta `walkTime + 10 + 260` ticks. Desplazamiento aleatorio en caja de 2,5 m; material `lightning` = misma `ltn2`, aditivo, energía 15 con el mismo pulso, `makeLineMeshes(10, 4, 4, 0, 0,3, pointy)` (`sacobject.d:4465-4478`, `renderer.d:264-273`, `1876-1892`, `state.d:2815-2830`).
- **Rayos de profanación** (`desecrateBolts[3]`, solo Desecrate y mago vivo): desde el vórtice rojo hasta el centro del mago, cambian de forma cada 6 frames (`renderer.d:1954-1958`, `state.d:16005-16009`). Mientras tanto se drena vida/maná/XP del mago y se le pone un resaltado (`addHighlight`, `15916`).
- **Criatura elevada**: sube hasta `altar + (0,0,15)` en 5 s; sigue en `thrashing`.
- **Al completarse**: Convert: `obj.gib` (despedazar) en la última ronda; Desecrate: gib de la criatura, `destroyAltar` (`state.d:16024-16041`). Los 4 doctores se matan al parar (`state.d:15825`), y el vórtice se cierra en 1 s. Empuje radial de todo lo que esté en 20 m (`16046-16048`). El doctor muere con `disappear` en frame 70 de su animación `dance` usada como muerte (`state.d:13999`, `sacobject.d:710-711`).

## 6. Sonidos (tags)

Solo hay uno en el ciclo del doctor en sacengine: `SoundType.convertRevive` = `jncX` (`sset.d:75`), al revivir la criatura en el pump (`state.d:15749`, ganancia 2,0); es el mismo del hechizo de revivir. El vórtice generado por el hechizo `vortex` usa `gxtv` (`state.d:11664`) pero es otro efecto. No encontré sonido para la aparición del vórtice, el acarreo, los rayos o el gib del ritual en `state.d` 15463-16050 (grep de `playSound`). Los sonidos propios de la criatura (`thrash`, daño) no se miraron.

## Web: qué respalda cada cosa

- https://www.gameswelt.de/sacrifice/test/sacrifice-2959/2 (reseña alemana de 2000): el Sac-Doctor aparece por un **portal rojo**, lleva una **jeringa gigante**, baila y corre al altar. Respalda el vórtice rojo y la aguja. No describe acarreo.
- Wiki fandom (`sacrifice-shiny.fandom.com/wiki/Convert`, `Sac_Doctor`, `Desecrate`): **no accesible** (HTTP 402). Solo vi sus resúmenes en buscador: texto «succiona el alma con una aguja gigante y la lleva al altar». No hay imagen.
- Capturas de esa misma reseña (descargué las 4 del scratchpad): ninguna muestra al doctor (un aro cian de otro hechizo y un rayo en la nieve). No sirven.
- Videos de YouTube hallados por buscador (no vistos: no puedo reproducir): https://www.youtube.com/watch?v=P9h25wwdWyQ, https://www.youtube.com/watch?v=iGvj9f3WjQ0, https://www.youtube.com/watch?v=8qcmUKw3lBg, https://www.youtube.com/watch?v=ye4w22DPGto, https://www.youtube.com/watch?v=3N5VZxwUMjU. No sé si muestran al doctor ni en qué instante.
- MobyGames https://www.mobygames.com/game/2861/sacrifice/ y Steam https://store.steampowered.com/app/38440/Sacrifice/: no abiertos.
- **Discrepancia a la vista**: la web solo habla de portal rojo (el de salida del doctor); el aro **azul** alrededor de la criatura sale únicamente de sacengine. El usuario dice «portal conectado a un rayo»: es coherente con aro azul + cuerda, pero no hay prueba visual externa.

## Especificación para implementar el efecto del acarreo (Godot 4)

Marca: **[S]** de sacengine, **[W]** visto en referencia web, **[E]** estimado.

Piezas:
1. **`CarryPortal`** (hijo de la criatura llevada, sprite que mira a cámara, `BILLBOARD_ENABLED`, sin sombra, aditivo, sin escritura de profundidad):
   - Capa A «anillo»: corona 512 segmentos [S] (en Godot basta un `QuadMesh` con shader que dibuje la corona, o `ArrayMesh` igual) radio externo 1, interno 0,65 (grosor 0,35) [S], textura `ltn2` 4×4 usando UV de zigzag en la dirección angular repetida 32 veces [S]; energía 10 [S]; fotograma = `floor(t·60/2) % 16`, 0,53 s por ciclo [S].
   - Capa B «centro»: quad 2×2 [S] con `vtx3` 4×4, misma animación, energía 1 [S].
   - Escala `s = vortexScale · 0,65 · (1,1·L, 0,9·L)` con `L` = longitud de la diagonal de la caja de la criatura [S] (el tamaño en x/y distinto es un sprite achatado; el original usa `z=0`).
   - `vortexScale`: de 0 a 1 en 1 s al empezar a llevarla, a 0 en 0,75 s al soltarla [S].
   - Centro: centro de la caja de la criatura [S].
2. **`DocTether`** (cuerda): malla de 19 segmentos [S], sección de 3 planos a 120° de radio 0,3 [S] con puntas afiladas [S]; piel con 20 huesos o, más simple, `ImmediateMesh`/tubo regenerado por tick siguiendo la spline de 5 puntos [E]. Textura `ltn2` 4×4, fotograma `floor(t·60/2) % 16`, repetición en U, volteo en segmentos alternos [S]. Material: aditivo, sin profundidad, doble cara [S].
   - Brillo: `E(t) = 0,375 + 14,625·(0,5 + 0,25·cos(7α) + 0,25·sin(11α))`, `α = π·(t·60)/60 = π·t` (t en s) [S]; en Godot normalizar por 15 si el material toma `albedo·energy` [E].
   - Puntos de control [S]: P0 = punta de aguja (hueso 16 de `sacd` + offset local (0,0,2,2), ×escala), P1 = P0 + 1,5·eje Z del hueso, P4 = centro de la criatura, P2 y P3 = interpolación P1→P4 al empezar; luego simulación: `a = 120·|d|^(2/7)·d`, `v += a·dt`, `v *= 0,25^dt`, tope de velocidad relativa 20 (relativa a la media de velocidad de P0 y P1), `p += v·dt` con tick fijo de 60 Hz. P0, P1 y P4 siguen al blanco sin inercia.
   - Anclaje: hueso 16 del esqueleto `sacd` (la «mano» con la aguja) [S]. Hay que comprobar que el nombre/índice del hueso exportado coincide (ver «No verificado»).
3. **`NeedleSparks`**: 2 partículas por tick (120/s) en P0 [S]; atlas `cst0` 4×4, 1×1, energía 3, delay 1 (frame_s 0,0333) [S]; velocidad `U(1,5;2)·(eje + U(0,2;1)·dirAleatoria)` con `vz·=2,5` [S]; escala `U(0,5;1)` [S]; vida 31–62 ticks (0,52–1,03 s) [S]. Con `CPUParticles3D`/`GPUParticles3D` reutilizando el sistema `ParticleType` del port (nuevo `.tres` `needle`).
4. **Criatura**: modo `HELD/thrashing`; reproducir `float2Thrash` una vez y `thrash` en bucle (o `rise`/`corpseRise` si el modelo tiene) [S]. Posición: `doctor + rotar(facing, (0, −(2+0,5·|escala|), 3,5))`, acercándose a `1,1·velocidadSuelo` si dista >0,75 [S] (el port ya lo hace).
5. **Doctor**: durante el acarreo, animación de caminar cargando; al empezar el acarreo reproduce `pickUpCorpse` (`attack2`, clip `SDpu`) [S, `state.d:15646`; que `SDpu` sea `attack2` es [E]].

Variante para Desecrate: igual que Convert [S].

## Tabla de assets

| Recurso | Para qué | ¿Exportado? | Cómo obtenerlo |
|---|---|---|---|
| `ltn2` (MAIN.WAD, `bits.FLDR`) | Aro azul, cuerda, rayos del ritual | **No** | Agregar `"ltn2": ("main.wad","MAIN.WAD!/bits.FLDR")` a `ATLASES` en `game/tools/export_particles.py:19-31` (mismo formato que `glo2`, `spd6`) |
| `vtx3` (MAIN.WAD, `bits.FLDR`) | Centro azul | **No** | Igual, en `ATLASES` |
| `vtx1` (MAIN.WAD, `bits.FLDR`) | Anillo del vórtice rojo | **No** | Igual |
| `vtx2` (MAIN.WAD, `bits.FLDR`) | Centro rojo y gotas | **No** | Igual |
| `cst0` (MAIN.WAD, `bits.FLDR`) | Chispas `needle` (y wrath/rain; ya se usa en sacengine) | **No** (el port usa `flao`, `wrth`, no `cst0`) | Igual |
| Atlas 4×4 con `n_u=4,n_v=4` | Los cinco de arriba son 4×4, ancho/alto 1 (`sacobject.d:4030-4054`) | — | Agregar entradas a `PARTICLES` (`needle`: energía 3, delay 1, vida 31..62) |
| Clips `sacd`: `SDda, SDpm, SDpu, SDrn, SDsb` | Danza, pump, recoger, correr, disparo | Sí, en `cache/look/anim_f37/sacd/` | Ya exportados; faltan los de `falling`, `hitFloor`, `tumble`, `spellcast*`, `attack0` (el RFC-020 §11 ya los lista) |
| `thrash`/`float2Thrash`/`rise`/`corpseRise` de cada criatura | Acarreo | **No verificado** | Mirar los exportadores de animaciones de `anim_f37`; son slots por criatura |
| Hueso 16 y offset (0,0,2,2) de `sacd` | Anclaje aguja | **No verificado** | Comprobar el esqueleto exportado |
| `data/fx/red_vortex.tres` | Vórtice rojo | **Placeholder** (usa `hover_blood`, 4×4, 60 partículas, sin aditivo) | Reemplazar por sprites con `vtx1/vtx2` |

El exportador toma cada TXTR por `(carpeta, tag, "TXTR")` y su paleta por el nombre en los bytes 8..12 invertidos (`export_particles.py:89-102`); para estas texturas basta con la entrada en `ATLASES`.

## Efectos que faltan en el ciclo del doctor (por prioridad)

1. **Acarreo**: aro azul alrededor de la criatura + cuerda de la aguja + chispas + animación `thrash` de la criatura.
2. **Vórtice rojo** real (anillo + centro + gotas) en la salida del doctor y sobre el mago en Desecrate.
3. **Rayos del ritual**: 4 cuerdas doctor→criatura, 2 del altar, 3 de profanación (misma malla `ltn2`).
4. **Animaciones del doctor**: `SDpu`, `SDpm`, `SDda`, `SDsb`, `SDrn`, caída y rebote.
5. **Sonido**: `jncX` en el pump.
6. **Gib/desmembrado** al final del ritual, resaltado del mago, empuje radial visual, temblor.
7. Pump: no se halló VFX propio; nada que agregar salvo lo anterior.

## No verificado

- **No encontré ninguna imagen ni video donde se vea el efecto del acarreo.** La wiki de fandom devolvió HTTP 402; los videos de YouTube no se pueden reproducir; no abrí MobyGames ni Steam. Todo lo que describo del aspecto sale del código de sacengine y de la inferencia de las texturas; no se comparó con el juego real ni con capturas.
- No abrí los PNG de `ltn2`, `vtx1/2/3`, `cst0`: los colores («azul-cian», «rojo») salen del nombre de los materiales (`blueRim`, `redRim`) y de la reseña web («portal rojo»), no de mirar la textura. Conviene exportarlas y mirarlas.
- La equivalencia `SDpu` = `pickUpCorpse` (`attack2`) y `SDpm` = `pumpCorpse` es estimada; confirmar con el exportador de clips.
- Qué hace sacengine con las 4 cuerdas cuando la criatura es grande (la hitbox) no se leyó.
- Si el original (no sacengine) dibuja algo en el pump no se puede saber desde el código de sacengine; Ghidra podría confirmarlo.
- Los sonidos que faltan pueden estar en otro lugar (animaciones con eventos de sonido en los datos del modelo `sacd`); no se revisó.
- Arreglar una imprecisión: en la sección 1 describí el período del pulso «≈0,57 s» y la frecuencia como estimación, no medida; usar la fórmula.
