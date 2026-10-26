# Visual — Sacrifice (port fan)

Guía visual del proyecto. La definió el usuario el 2026-10-13 con cuatro imágenes de referencia y sus decisiones. Manda sobre los RFC y sobre cualquier plan generado.

## Referencia principal: el juego original (2026-10-14)

El usuario mostró cuatro capturas del Sacrifice original (`visual/refs/original/`, fuera de git) y dijo: «ve el cielo y la composición en general, es homogénea, se siente inmersivo. Busco esto». **Esta es la guía que manda sobre las cuatro referencias de abajo.** Qué hace que se vea así:

- **Una sola paleta por mapa.** Cielo, suelo, niebla y luz comparten la misma familia de color: en Pyro todo es naranja-rojo (cielo de fuego, suelo rojizo, sombras ocres); en la pradera, verde saturado abajo y azul-rosado arriba, sin choques.
- **El horizonte se funde con el cielo.** Las lomas lejanas pierden contraste y toman el color del cielo; no hay corte duro entre tierra y cielo.
- **Cielo grande y pintado.** Nubes arremolinadas, muy llamativas, que ocupan la mitad superior; se mueven.
- **Suelo vivo y saturado** (verde intenso en la pradera, rojo en Pyro), con textura visible pero sin ruido fotográfico.
- **Efectos que brillan dentro de esa paleta** (chorro del manantial, columnas de luz), sin quemar el resto.
- **Nada «realista» que rompa la unidad:** la inmersión viene de la coherencia, no del detalle.

## Referencias (estilo de render, secundarias)

En `visual/refs/`. Son el objetivo de aspecto, no capturas del juego:

| Archivo | Ambiente | Dios |
| --- | --- | --- |
| `ref_1_desierto_dia.webp` | Desierto árido de día: polvo, piedras, matas secas, cielo nublado con claros | James |
| `ref_2_pradera_atardecer.webp` | Pradera con pasto alto, flores y rocas; atardecer con rayos de sol entre nubes | Persephone |
| `ref_3_noche.webp` | Noche nublada con luna, luciérnagas, luz azul fría del altar | Charnel |
| `ref_4_fuego.webp` | Tierra quemada: brasas, focos de fuego, lava, humo, cielo rojo | Pyro |

El quinto ambiente, Stratos, es de altura fría y ventosa, de día, y se diseña con el mismo criterio.

## Qué pidió el usuario (textual)

«Esta es la estética visual que busco. Bloom, post process, VFX, niebla volumétrica, iluminación. Hay que trabajar mucho los shaders de los materiales y que no nos ate usar los de sacengine. Necesitamos agregarle mapas de normales, AO, etc.»

Antes había pedido: «god rays, hacer el cielo un poco más llamativo, efectos de iluminación que generen una estética más actual sin perder la esencia».

## Pilares

1. **Remaster, no réplica.** El aspecto es actual: materiales PBR, luz y atmósfera de hoy. El render no tiene que parecerse al de sacengine ni usar sus shaders.
2. **La esencia son las formas y la lectura.** Se reconocen las siluetas de magos, criaturas y altar, el HUD, la cámara y el encuadre del juego original.
3. **Cada dios es un ambiente completo.** Suelo, vegetación, cielo, luz, niebla y partículas cambian juntos; no es un filtro de color.
4. **La atmósfera manda.** Niebla volumétrica, rayos de sol, nubes con volumen y bloom en lo que emite luz.
5. **Se juega bien.** Una unidad se distingue del suelo y de la vegetación a la distancia de la cámara del juego, con sol y a la sombra.

## Sí

- Suelo con relieve: materiales PBR con normales, AO y rugosidad; mezcla por pendiente y altura; pasto, matas, flores y rocas instanciados.
- Mapas de normales y AO en personajes, altar y estructuras, generados a partir de sus texturas originales.
- **Cielo: se conserva la estética del original** (decisión del usuario, 2026-10-14: «era algo muy llamativo en el juego original»). Las nubes, colores y movimiento del cielo del juego se ven como en el original; nada de nubes nuevas ni saturación extra. Se puede construir un cielo nuevo por shader (técnicas de godotshaders/shadertoy) que reproduzca esa estética con más resolución e impacto, pero el cielo original queda siempre disponible como modo legacy. **Actualización 2026-10-26 (RFC-058):** el día/noche y el clima pueden cambiar el cielo (estrellas, luna, nubes de tormenta) mientras la estética se parezca a la del original; el modo legacy ya no es obligatorio. Sigue sin bloom fuerte.
- Niebla volumétrica y de altura; polvo, brasas, luciérnagas y esporas en el aire según el bioma.
- Bloom fuerte en el portal del altar, hechizos, manantiales y fuego.
- Sombras suaves y relleno de luz: nunca negro puro sobre un personaje.
- Corrección de color con carácter por dios.

## No

- Motion blur, profundidad de campo que desenfoque el campo de juego, aberración cromática, grano y destellos de lente.
- Vegetación o niebla que tapen a las unidades o al cursor.
- Brillo plástico en personajes.
- Cambiar las siluetas o las proporciones de los modelos originales.

## Assets

- **Suelo, pasto, rocas y cielo:** bibliotecas libres CC0 (ambientCG, Poly Haven u otras con la misma licencia). Se commitean por Git LFS, a 2K–4K, con su procedencia anotada.
- **Normales y AO de personajes y edificios:** generados desde las texturas del original. Van al caché, no a git.
- **Escalable:** el sistema de materiales tiene que aceptar texturas nuevas que el usuario quiera sumar más adelante, por bioma o por pieza, sin tocar código.
- Nada del juego original se commitea.

## Rendimiento

Mac con Apple M4 (GPU de 10 núcleos), pantalla Retina. Calidad media a 60 fps, renderizando a menor resolución con reescalado; calidad alta con todo encendido a 30–45 fps; calidad baja para máquinas más chicas. Todo por presets.

## Jerarquía de lectura

Unidades y bando > hechizos y efectos > estructuras > suelo y vegetación > cielo.

## Cómo se trabaja

Cada capa se puede apagar y se ajusta desde el editor, por bioma. El pase visual se juzga con capturas de los ambientes desde cámaras fijas, comparadas con las referencias.
