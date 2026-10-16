---
description: "Escribe VISUAL.md (pilares, referencias, jerarquía, no-goals) a partir del estilo y las refs del usuario."
---

Si el usuario ya dijo estilo, referencias o no-goals de look, escribí `VISUAL.md` en el mismo directorio que `PRD.md` / `RULES.md` (raíz del juego Godot o del repo de producto).

Si **no** hay estilo ni refs: preguntá primero (pixel, FUT, flat, …; 2–5 imágenes/URLs; qué no querés). No inventes una estética.

`VISUAL.md` es constitución de look, no un moodboard eterno. Corto:

1. **Pilares** — 3–6 frases (jerarquía, tipo, paleta, motion).
2. **Referencias** — links o paths en el repo + qué se toma de cada una (cromo lleno, foil no chip de rareza, respiración no balanceo…).
3. **Jerarquía en pantalla** — qué es hero (puja, CTA, carta) vs chrome.
4. **Tipo y filtro** — fuente, nearest vs linear, viewport de diseño (p. ej. 720×1280).
5. **No-goals** — lo que ya rechazaron (microtexto, pitch verde, stamp en vacío de shader…).
6. **Pantallas cubiertas** — lobby, mesa, menú… lo que exista.

Autoridad: debajo de RULES.md, encima del RFC (ver skill `godot-studio-workflow` / spec-loop). El pase `studio-visual` se mide contra este archivo.

No copies un design system genérico. No pongas números de balance ni reglas de subasta acá (eso es RULES / RFC).
