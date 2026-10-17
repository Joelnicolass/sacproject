# REVIEW-RFC-030s-a (F130): Call lightning y carga de rayo

Reviewer (Sonnet), una pasada, 2026-10-17. **Veredicto: CHANGES** (1 bloqueante, corregido por el orquestador).

## Bloqueante

**B1** (`call_lightning.gd:44`): la dirección del cielo sumaba el 6 a `uniformDirection` sin normalizarla antes. En sacengine, `uniformDirection` ya viene normalizada (state.d:29106-29110). Por eso el rayo nacía menos inclinado de lo que corresponde.

**Corregido:** primero se normaliza, después se suma `(0, 6, 0)` y se vuelve a normalizar. La réplica `f130_expect.py` quedó con la misma fórmula y da una diferencia de 0,0005 m. El digest de `f130` no cambia, porque el origen no entra en el digest.

## Revisión

- **Fidelidad:** PASS.
  - Gasto: maná −50, enfriamiento 0, `ntil` 750 con rebote y retardo de 12.
  - Fuego amigo: 0, o ×0,5 cuando está activo.
  - Carga: `int(f·daño)` con f = 4/2, ×0,25.
  - Descargas en el orden del original.
  - Golpe, precisión y paso ×1,5.
- **`Health` con `mods = 0`:** idéntico a antes.
- **Un dueño:** PASS. Solo `absorb` y `melee_factor` deciden la carga.
- **Determinismo:** PASS. Streams nombrados, y las chispas usan un RNG de presentación propio.
- **Red y reglas:** PASS.

## Menores

- **M1:** `roll_damage` con `total <= 0` no devolvía las claves del log. **Corregido.**
- **M2:** las claves extra y el log no tienen efecto en producción.
- **M3:** divergencias declaradas.
- **M4:** el rayo se ve blanco sobre blanco; queda para el pase visual.
- La carga usa float64 en lugar de float32 (puede diferir en ±1 cuadro en bordes) y decide «aliado» por slot.

## Playtest (Sonnet, una corrida)

- PASS: el rayo se ve (+73 a +99 de luminancia), las chispas del gigante cargado y 3 descargas al suelo.
- Con la carga, el paso pasa de 0,150 a 0,225 (×1,5).
- El fin de la carga y una descarga a un vecino no se vieron en ventana; los cubre el banco con la réplica.
