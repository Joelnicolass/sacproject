# REVIEW F143 (031d): Opciones → Jugabilidad

**Veredicto: FAIL.** Hay un solo bloqueante (B1). El revisor es de solo lectura, así que este informe lo guardó el orquestador (2026-10-16).

## Criterios
| # | Criterio | Estado |
|---|---|---|
| 1 | Con FF off, el log dice «no» | PASS. El Fireball = 0 queda sin medir y pasa al playtester. |
| 2 | 6 almas en los dos magos; con «soltar almas» off, P no hace nada | PASS |
| 3 | Los valores persisten | PASS |
| 4 | En partida es solo lectura y el cliente ve los valores del servidor | PASS |
| 5 | El dedicado y los bancos ignoran las preferencias | En el código, PASS; en los flows, falla por B1. |

## Lo que está bien
- **Fidelidad a sacengine:** `options.d:98/106` y `app.d:278/337-347`.
- **Trampa §2.2:** `SoulPurse` (vía `WizardSpawner`) y `SoulSystem` leen `world.rules`, también en el mago IA y en el cliente que entra tarde.
- **Red:** el cliente solo aplica lo que recibe y el servidor rechaza P. No hay RPC nuevas.
- **`--souls`:** queda un único dueño, `MatchSetup`. Esto cierra F140 N3.
- **Composición:** sin god-nodes, sin API solo para harness y sin tocar `unit_body.gd`.

## B1: las preferencias del jugador se filtran a los playtests, y los playtests escriben el archivo del jugador
- Bajo `--agent`, `GameplayPrefs` (y `HudScale`, que ya traía la fuga) lee el `user://settings.cfg` del jugador.
- Además, «boot > flag» siempre fija los 3 campos.
- Correr `pt143dev_a` deja FF off en el archivo, y eso cambia lo que miden `pt140pt_vs_ai_l4` y los flows de F139 que pasan por el boot.
- Contradice la decisión de F142.

**Corrección mínima, con un solo dueño en `UserSettings`:**
- `sandboxed()` devuelve true cuando hay `--agent=` y no hay `--user-settings`.
- En sandbox, lo que se lee son los defaults y lo que se escribe queda en un `ConfigFile` en memoria.
- `--user-settings=user://x.cfg` cambia la ruta.
- `GraphicsApplier._inert` pasa a usar `sandboxed()`, y `--user-settings` reemplaza a `--apply-graphics`.

## Desvío 1: «boot > flag»
Coincide con §3.5, pero contradice el criterio 2 de F140. Hay que anotarlo.

**Recomendación del revisor, adoptada por el orquestador:** `to_setup` fija solo los campos que el jugador eligió de verdad (están en el archivo o los tocó en la sesión). Así un flag vale cuando no hay una elección explícita.

## No bloqueantes
- **N2:** el CheckBox apagado no se ve con el tema oscuro. Unificar con el CheckButton de Gráficos.
- **N3:** `socket_warning` no se usa.
- **N4:** el `print` en cada P desactivada.
- **N5:** el menú va de 1 a 30 y `--souls=0` es válido.
- **N6:** el cliente muestra defaults antes del primer snapshot.
