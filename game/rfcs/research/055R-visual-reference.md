# 055R: referencia visual del original (videos del usuario, 2026-10-23)

Fuente: dos grabaciones de pantalla del usuario con partidas del juego original (un 2v2 multijugador de unos 13 minutos en un mapa de hielo y cristal, y un mapa verde de colinas de unos 21 minutos), más cortes de la intro. Se miraron 16 cuadros, uno cada 6 s. Los cuadros no se versionan.

## Qué se ve

| Rasgo | Detalle observado | Dónde cae en el plan |
|---|---|---|
| Brillo y bloom | Manantiales de maná como chorros blanco-cian que estallan en partículas; almas como estelas blancas; todo lo mágico emite luz y satura a blanco | 055b: `glow` del `Environment` en `LookProfile` + emisión aditiva de FX |
| Estelas de hechizos | Rayos y proyectiles con estelas largas y luminosas (rosa, violeta, cian) | 055e: cada hechizo es escena con `Trail` y `ActorLight` |
| Partículas del entorno | Esquirlas y cristales flotando, polvo de colores, enjambres de puntos oscuros, luciérnagas verdes en el mapa de colinas | RFC-058 `AmbientLife` |
| Suelo de colores | Degradés de color fuertes en el suelo (rosa, magenta, verde agua, cian) mezclados por zonas; manchas oscuras de quemado y sangre | 055d `TerrainShape` + material; decals como nodos |
| Bioma verde | Colinas sinuosas y altas, pasto verde con parches marrones, árboles altos tipo sauce de follaje en capas, plantas y flores naranjas sueltas, arcos de piedra en las cimas | RFC-059 bioma Persephone |
| Escenografía grande | Pilares de cristal gigantes, arcos, anillos, columnas que enmarcan el horizonte | 055d `BiomeProp` + RFC-059 kit en Blender |
| Cielo | Degradé amarillo-verde luminoso en el mapa de hielo; nubes dramáticas de tormenta en Charnel y en las colinas | 055b `SkyLook` (shader de cielo) |
| Ritmo | Cámara cercana y rápida, muchas unidades y efectos a la vez, todo en movimiento | Presupuesto de luces y partículas de 055b y RFC-058 |

## Conclusión
El look objetivo es saturado, luminoso y muy animado: casi todo lo mágico emite luz y deja estela, y el entorno nunca está quieto. El port hoy es correcto en formas pero apagado: le faltan bloom, emisión, estelas, partículas de ambiente y la vegetación alta del bioma verde.
