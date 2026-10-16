# Checklist UI/UX (Godot)

Usar **después** de una captura. Comparar con `VISUAL.md` y las refs.

## Jerarquía

- [ ] Lo más importante (precio, turno, CTA) es lo más grande / contrastado.
- [ ] Labels de chrome (COM/LEY, debug) no compiten con el contenido si `VISUAL.md` pide otra señal (foil, color).
- [ ] Estados vacíos y de error se leen.

## Legibilidad

- [ ] Tipo a tamaño de viewport (p. ej. 720×1280): no microtexto.
- [ ] Contraste texto/fondo (inkl. over art).
- [ ] Copy en el idioma del producto; no IDs en la HUD.

## Consistencia

- [ ] Misma familia tipográfica / tema que el resto.
- [ ] Espaciado y márgenes alineados al resto de pantallas tocadas.
- [ ] Color de rareza / facción / equipo coherente con `VISUAL.md`.

## Uso

- [ ] Hit targets usables (botones no de 32 px en móvil).
- [ ] `mouse_filter`: FX no se comen clics; HUD `IGNORE` salvo controles.
- [ ] Anclas: no se rompe al `expand` / otra resolución.

## Fidelidad

- [ ] No es un sello chico en un vacío de shader si las refs muestran cromo lleno.
- [ ] Motion: si `VISUAL.md` pide sutil, no hay balanceo fuerte.
- [ ] Pixel art: filtro nearest; no stretch que recorte mal el atlas.

Bloqueante vs nit: bloqueante impide jugar o viola una regla escrita. El resto es sugerencia.
