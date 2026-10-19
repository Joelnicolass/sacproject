# CHANGE-REQUEST-003: audio del juego (RFC-052)

Fecha: 2026-10-19.
Pedido del usuario: «si, hagamos esto para tener el juego completo».
Las decisiones de la cola están delegadas («iterar la cola sin preguntar»). Las del §14 de RFC-052 las tomó el orquestador y el usuario puede cambiarlas.

## Clasificación

- **Tipo:** Scope Change. Feature nueva, Large, Must have.
- **Qué saca de los no-goals:** «audio original» estaba fuera del primer corte en `PRD.md` y en `FEATURES.md` (Won't).

## Conflicto

- **PRD «Fuera del primer corte»:** se saca «audio original». La razón original era el alcance del primer corte, que ya está cumplido: el juego se juega completo en solo, contra la IA y online. Esa razón ya no aplica.
- **RULES:**
  - No se viola ninguna regla.
  - El audio es presentación del cliente, así que no toca la simulación ni el banco de determinismo.
  - El importador cumple «portable para cualquiera»: avisa que necesita el original y el juego anda sin él.
  - Se agrega el dominio `scenes/audio/` y la carpeta `data/audio/`.

## Impacto

- **Sin cambios de reglas de juego.** Cero RPC nuevas.
- **Riesgo para el banco:** el generador global. Se mide primero, en 052a.
- **Tamaño:** el audio importado pesa unos 230 MB. No se versiona por ahora (RFC-052 §14.1).

## Alternativas rechazadas

- **Solo sonidos propios, sin importador del original:** el juego sonaría distinto al original, que sigue siendo la meta visual y sonora cuando no cuesta fidelidad.
- **Versionar el audio importado en LFS ya:** el usuario dejó diferida la decisión de LFS y el repo es público. Es reversible más tarde.
- **Convertir a `.ogg` al importar:** exigiría ffmpeg en la máquina, y eso rompe «portable para cualquiera».

## Artefactos actualizados

- `PRD.md` (fuera del primer corte)
- `FEATURES.md` (Won't)
- `RULES.md` (dominios y datos)
- `rfcs/RFC-052-audio.md` (nuevo, F360–F369)
