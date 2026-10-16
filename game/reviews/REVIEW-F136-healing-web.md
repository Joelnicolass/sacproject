# REVIEW F136 (030h2): telaraña que cura (Scarab `slba`)

**Veredicto: PASS.** Sin bloqueantes. El revisor es de solo lectura; el orquestador guardó este informe el 2026-10-16.

- **Fidelidad:**
  - El impacto cura solo a los de su bando, sin edificios y con el tirador incluido (`state.d:23609-23627`). Usa `heal_full`, igual que `tum@`.
  - Choca con el blanco previsto o con alguien de su bando (`23633-23642`).
  - Barre el segmento solo si la caja no tocó nada, y el terreno cuenta como choque (`23655-23664`).
  - Estalla al final del alcance (`23667-23670`).
  - Para la IA, elige al aliado más herido (`12949-12958`, `28828-28842`).
  - Con una orden contra un enemigo le dispara; en contacto, ataca cuerpo a cuerpo (`12849-12855`).
- **Un solo dueño:** no hay ningún `if scarab`. Sin política, todo queda exactamente igual: lo verifiqué expresión por expresión en `pick`, `accepts` y `_can_hit`. El desvío de `is_foe` está bien:
  - `is_foe` (órdenes) significa «enemigo»;
  - `_is_valid_foe` significa «blanco que conserva».
- **Determinismo y red:** no usa RNG, corre solo en el servidor y los clientes ven el disparo y el rastro.
- **Riesgos:** ningún lector de `body.target` asume que es un enemigo. Sin orden, el blanco es estable hasta que el aliado queda lleno.
- **Composición:** las perillas viven en `.tres`, `unit_body.gd` tiene neto 0 líneas y el banco no se cumple solo.

## No bloqueantes
- **N1:** empate y visibilidad para la IA, marcar «aprox.».
- **N2:** ¿los edificios propios frenan la telaraña? Sin verificar.
- **N3:** confirmar que el alcance de `slba` sea 110.
- **N4:** comentario sobre el contrato `is_foe` / `_is_valid_foe`.
- **N5:** la regla de enemigo está escrita tres veces.
- **N6:** `is_patient` copia la validez de `is_valid_foe_of`; conviene un `is_live_target` compartido.
- **N7:** documentar los desvíos en el RFC.
- **N8:** falta el efecto al estallar.
- **N9:** la `editor_description` de la escena está desactualizada.
- `fired` sigue informando 150 de daño: cuidado si alguna auditoría lo suma.
