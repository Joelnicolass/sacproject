# REVIEW F92 — Almas y barras del mago (RFC-028, corte 028a)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: PASS.** Sin bloqueantes.

## Corridas del reviewer
`f24_cast`, `f22_mana_pt` y el respaldo sin caché: las tres AGENT_OK. Sin caché, las barras quedan en color plano y el número va en un Label.

## Criterios
Todos PASS con cifras:
- Bloque: 153,6 × 116 a 720p y 230,4 × 173 a 1080p.
- Barra de maná: 0,8227 contra 822,7/1000. Heal la baja de 1000 a 700; en la captura se ve al 71,6 %.
- Almas: de 0 a 1.
- Animación del alma: 8 cuadros en 0,533 s.
- Fantasma: barra de vida en 0 y el texto queda debajo del bloque.
- Escala en caliente de 0,6 a 1,2 sin superponerse con nada.
- `%Stats.text` conserva el formato.
- Nada del original en git: las franjas se leen de sacengine al exportar y van a `cache/`.

## Nits
1. Costura clara de 1 px a media altura de los tres marcos. sacengine usa las mismas coordenadas, así que probablemente también existe en el original. Comparar antes de tocar.
2. Asserts flojos en `f92_stats.json`: la fracción de maná del mismo cuadro y el alto de 81,6 px solo se imprimen.
3. «Mago · Dios» quedó sin margen derecho.
4. `_fit()` asigna `size` además del tamaño mínimo; es redundante.
5. `SoulCounter` no tiene knob de tamaño de texto.
6. En el editor, el bloque se ve vacío (sin `@tool`).
7. `debug/cast_heal.tscn` y `soul_pickup.tscn` tienen `spawn_creatures = false` sin declarar; hay que confirmar de qué corte viene.
8. `spir.png` lo pide el diseño, no es alcance de más.

## Decisiones del orquestador
- Pasa al playtest.
- Nits 1 y 3: el playtester compara la costura y el margen contra `orig_4_manantial.webp`.
- Nits 2, 4, 5 y 6: deuda menor.
- Nit 7: lo confirma el orquestador.
