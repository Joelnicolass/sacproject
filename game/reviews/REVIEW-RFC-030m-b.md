# REVIEW-RFC-030m-b (F150): ráfaga del Warmonger

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: APPROVE**, sin bloqueantes.

**Fidelidad (PASS)**
- 16 ráfagas de 2 rayos (32 en total) en T+2+4k, con la puntería sorteada de nuevo en cada rayo.
- El punto apuntado queda fijo y el origen sigue al tirador. Si el tirador muere, la ráfaga se corta.
- Cualquier cuerpo frena el rayo. Con `foes_only`, el aliado no recibe daño.
- Sin fogonazo: solo aparece `warmongerHit` donde termina el rayo.

**Pendientes de la review anterior**
- M1 y M2 resueltos: `source` tipado como `RangedAttack`, y `shot_origin()` ahora tiene callers.
- `class_name RangedAttack` no choca con ningún otro nombre.

**Determinismo**
- `f124` pasa a `3a9bb548`. Los carriles A, B y D no se renumeraron.

**Carril C**
- Se movió a (1375, 1155) para salir de la choza y de la loma. Está justificado y documentado.

**Reglas**
- PASS.

**Menores**
- n1: falta el newline al final de un json.
- n2: sin acción.
- n3: divergencias ya declaradas.
- n4: el look solo está verificado con números (R−B +130).
