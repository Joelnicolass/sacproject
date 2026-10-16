# Perdón de plataformas (catálogo)

Fuente: [Celeste & Forgiveness](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html). El addon cubre 1–4 y 7 genéricos. El resto es glue **si el juego tiene** dash / one-way / stamina.

## En PlatKit

1. **Coyote** — salto un rato después de dejar el piso.
2. **Jump buffer** — el press se guarda y se gasta al aterrizar.
3. **Apex** — hold jump → menos gravedad en el pico (más tiempo para acomodar el land).
4. **Jump corner** — techo en esquina → deslizar en X para no “bonkear”.
7. **Lift** — `get_platform_velocity()` se recuerda `lift_remember` s.

Wall jump con `wall_extra_pixels` (el artículo: 2 px en 320×180 ≈ ¼ tile). Off por default.

## Glue del juego

### Dash corner / one-way pop

Durante un dash **del título**, llamá `PlatMotor.try_side_corner_correct(delta)` y subí `side_corner_pixels`. One-way: si el dash atraviesa un `collision_one_way`, el juego hace `global_position.y` al top del collider — eso conoce tus layers; no va en el addon.

### Super wall-jump

Si hay un verbo “super” (dash up + wall jump), usá **más** `wall_extra_pixels` en ese estado (el artículo: ~5 px). Un `@export` en el estado, no un fork de PlatKit.

### Stamina refund

Si tenés dos saltos de pared con inputs parecidos (arriba vs afuera): ventana corta post-salto que **convierte** al otro y devuelve stamina. Eso es regla de **tu** recurso de stamina, no del motor.

## Intensidad

Si el usuario no dice: coyote **0.08**, buffer **0.12**, apex **0.5**. No pongas 0.4 s de coyote “para que sea justito” sin preguntar.
