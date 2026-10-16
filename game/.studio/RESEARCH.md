# Sacrifice — núcleo de juego (investigación)

Fuente: `sacengine/source` (citas archivo:línea) y valores leídos de `spells.wad`. Tiempo: 60 fps de simulación. Cooldowns en frames (`/60` = s). Velocidad `runningSpeed*1e-2` m/s. Regeneración `regeneration/60` por segundo.

## Mago (WIZD, `spells.d:88-155`)
- Los 15 magos tienen las mismas estadísticas: vida 1500, regeneración 1000/min (16.7/s), maná 1000, carrera 10 m/s, almas iniciales 0 (sacengine da 12 por opción), vista 200.
- Por nivel: +50 vida máx., +100 maná máx. (`state.d:2297-2324`).
- **Maná: no se regenera solo.** Solo cerca de fuentes, a radio 50 y acumulable (`state.d:28578-28609`): manantial (manafount) 33.3/s para cualquiera; manalito 33.3/s para aliados; altar 16.7/s; santuario 8.33/s.
- **Vida:** se regenera a `regeneration * (mana/maxMana)` por segundo, solo quieto y sin recibir ataques (`state.d:14400`, `1429`).
- **Muerte:** si tiene altar pasa a fantasma (alfa 0.36, 1.75× más rápido, no junta almas). Cada punto de maná ganado cura 4.2 de vida. Con la vida llena vuelve a ser mago (`state.d:8827`, `13957`, `14004`). Sin altar desaparece.
- **Lanzar:** el maná se descuenta durante el lanzamiento, a 500/s (hechizos) o 125/s (edificios) (`state.d:9881`). Cooldown: el hechizo lanzado `castTime + cooldown + 1.5 s`; los demás `castTime + 1.0 + 1.5 s` (`state.d:2284`). Tiempo de lanzamiento en s = `frames/(1.35*60)`.

## Almas (`state.d:1580-1630`, `14925-14976`)
- Una criatura que muere deja un alma de valor `Cre8.souls` sobre el cadáver. Aparece en 3 s.
- Azul = tuya o sin dueño. Roja = enemiga. Verde = aliada (opcional).
- El mago vivo la junta al pasar por encima: distancia horizontal ≤ 5 y vertical ≤ 5.
- Convocar descuenta `Cre8.souls` al terminar. P suelta un alma.
- Las almas rojas se convierten con Convert (`ccas`: 800 maná, alcance 20, 180 frames) y un Sac Doctor que lleva el cadáver al altar o santuario.
- Sprite: `spir.TXTR`, grilla 4×4, 1.0 × 1.6; cuadros 0–7 azul, 8–15 rojo.

## Criaturas (CRE8, `spells.d:17-77`)
- Golpe cuerpo a cuerpo (`state.d:9231`): `facing = 1.5 + 0.5*dot(fwdA, fwdD)`, `P = acc/(acc + evasion/facing)`, `daño = facing * meleeStrength * (animSeg/ticks)`. Aturde si el daño ≥ 25 % de la vida máx.
- Daño recibido: multiplicador de resistencia `*1e-3` (cuerpo a cuerpo `0.4*res`). A vida 0 muere, deja cadáver y alma.
- Agresiva si `aggressiveness > 0`: sin orden, ataca a enemigos dentro de `sightRange*0.1`. Rango de guardia 50.
- Habilidad activa: `abilities[1]` si la criatura es a distancia, si no `abilities[0]`. Tecla Ctrl+Q o Shift+B. Gasta el maná propio (`Cre8.mana`) y tiene cooldown.

| Criatura | Vida / regen (/min) | Velocidad | Fuerza | Maná | Habilidades |
|---|---|---|---|---|---|
| Trogg `ycro` (eorc) | 960 / 1000 | 8.25 | 200 | 0 | ninguna; inmune a hechizos |
| Earthfling `palk` | 960 / 1000 | 9.0 | 90 | 200 | Escupe roca (alcance 75, 120 de daño, 5 de maná) + Forma de roca |
| Gargoyle `sohe` | 625 / 1000 | vuelo 11.25 | 75 | 250 | Granizo de tierra (alcance 40, 125) |
| Druid `nmuh` (humn) | 800 / 1750 | 11.0 | 150 | 100 | Escudo de vida (50 de maná, 20 s) |
| Ranger `amuh` (huma) | 800 / 1750 | 12.0 | 90 | 200 | Arco (alcance 110, 120) + Vista divina |
| Shrike `tbsh` (lhbt) | 450 / 1750 | vuelo 15.0 | 75 | 250 | Chorro (alcance 35, 150) + Escudo de vida |
| Manahoar `oham` (maho) | 550 | 13.5 | — | — | da maná cerca de manalitos |

Las criaturas de nivel 1 cuestan 300 de maná y 1 alma, con 2 s de cooldown. Las de nivel 9 cuestan 1900 de maná y 5 almas.

## Selección y órdenes (`dagonBackend.d:965-1290`, `state.d:30142`)
- Clic: selecciona. Shift+clic: alterna. Ctrl+clic: todas las del mismo tipo a 50 m. Doble clic: todas. Arrastre ≥ 3 px: rectángulo.
- Grupos: 1–0. Ctrl+número define el grupo; número solo lo elige. Máximo 12 por grupo. Lo que se convoca entra a la selección.
- Clic derecho: suelo = mover; enemigo = atacar; aliado = escoltar; cadáver = guardar zona; alma azul = ir; alma roja = Convert; manantial = Manalito.
- Órdenes: move, attack, guard, guardArea, advance, retreat (Ctrl+Espacio), useAbility, setFormation.

## Libro de hechizos (`state.d:2138-2173`)
- Pestañas: criaturas, hechizos y estructuras, ordenadas por `spellOrder`.
- Nivel 0 (todos los dioses): Manahoar; Speedup y Heal; Manalito, Guardian, Convert, Desecrate y Teleport.
- Nivel 1: las primeras 3 criaturas del dios y su primer hechizo. James: Trogg, Earthfling, Gargoyle y **Rock**. Persephone: Druid, Ranger, Shrike y **Wrath**.

| Hechizo | Maná | Alcance | Cooldown | Frames | Efecto |
|---|---|---|---|---|---|
| Speedup `pups` | 300 | 100 | 1 s | 60 | ×1.75 de velocidad; 6.5 s en un mago |
| Heal `laeh` | 300 | 100 | 1 s | 30 | 1000 de vida a 240/s |
| Rock `kcor` | 300 | 125 | 8 s | 60 | 650 de daño, velocidad 30 |
| Wrath `oalf` | 300 | 100 | 10 s | 60 | 550 de daño, radio 5 |
| Manalito `htlm` | 800 | 20 | 10 s | 900 | sobre un manantial |

## Teclas por defecto (`hotkeys_.d:236-307`)
- Original: avanzar E, retroceder D, girar S y F. **El usuario pidió WASD**: W, S, A, D.
- Criaturas 1–11: Q, Shift+Q, Shift+W, Shift+R, …
- Hechizos 1–11: X, R, C, LAlt, W, T, Espacio, … (el hechizo 5, W, choca con WASD y se reasigna).
- Ctrl+R atacar, Ctrl+A escoltar, Ctrl+Espacio retirada, Ctrl+Q habilidad, P soltar alma. Zoom: = y −.

## Cámara (`dagonBackend.d:356-452`, `1305-1400`; `renderer.d:17-34`)
- `zoom` va de 0 a 1, arranca en 0.125 y se suaviza hacia `targetZoom`.
- `distancia = max(4.5, 0.6 + 2.32h) * (0.6 + 3.13*zoom)`; `altura = (1.75h − 1.15) * (0.6 + 2.8*zoom)`, con h = alto del mago.
- **Borde de pantalla, 100 px:** el borde izquierdo o derecho gira a 36°/s más el movimiento del mouse; el superior acerca y el inferior aleja, a 0.5/s más el movimiento.
- Rueda: ±0.04. Arrastre con el botón central o Ctrl+izquierdo: vista libre.
- La cámara se vuelve detrás del mago a 171°/s cuando él gira.

## Cielo (`sacobject.d:1026-1109`, `renderer.d:1203-1238`)
- `scaling` 10240. `skyt`: cilindro de radio 5120, de z 0 a 2560, la textura se repite 8 veces. `skyb`: anillo de radio 4096 en z −2560 a radio 5120 en z 0. Nubes `SKY_`: plano de 10240 en z 1792, UV 0–4. `undr`: plano en z −2560. Sol: quad en z 2560.
- **Movimiento:** cilindro y anillo rotan 2π/512 rad/s. Las nubes se desplazan (1, −1) cada 64 s.

## Dioses / biomas
- Dioses: persephone `prsc`, pyro `PY_A`, james `JA_A`, stratos `ST_A`, charnel `char`.
- Cada uno cambia el atlas MAPT, el detalle, el borde y el cielo.
- Sol: persephone 6, pyro 2, james 14, stratos 12, charnel 4.

## Partículas (`sacobject.d:1206-1812`)
- 74 tipos. Cada uno: atlas TXTR de nU×nV (4×4), ancho/alto, energía, delay, gravedad y modo.
- Lanzar: `castJames` `cstj.TXTR`; `castPersephone` `cstl.TXTR`. Heal: `glo2`. Speedup: `spd6`.
- Rock al impactar: 100 `rock` + 20 `dirt`. Muerte: 40 `hoverBlood` + 200 `blood`.

## Magos (`nttData.d:1219`)
- Jadugarr (jnwr), Seerix (serx), Marduk (mrdk), The Ragman (xwiz), Acheron (quil), Sorcha (gret), Abraxus (ABRX), Mithras (sage), Eldred (hero), Ambassador Buta (buta), Grakkus (rigl), Charlotte (spdr), Shakti (shkt), Yogo (YOGO), Hachimen (brod).
- El mago es solo cosmético. El dios se elige aparte y define el libro de hechizos.

## Victoria
- Desecrate (1000 de maná, 450 frames): un Sac Doctor lleva una criatura propia al altar enemigo. Cada ronda drena `200*(1+almas)` de vida al mago enemigo. Si el mago muere durante el ritual, pierde.
