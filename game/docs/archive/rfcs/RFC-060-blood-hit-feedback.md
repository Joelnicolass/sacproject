# RFC-060: Sangre y feedback de golpe

Estado: implementado (060a, 060c, 060b, 060d, 060z) el 2026-10-26; falta la pasada única de pruebas con ventana. Feature F390. Plan: `docs/archive/rfcs/plans/060-blood-plan.md` (reemplaza el boceto de RFC-055 §14.2).

## Decisiones del usuario (2026-10-26, mandan)

1. **Todo sangra.** Toda criatura y todo mago que pierde vida sangra, con cualquier daño (melé, disparo, hechizo, zona, muro, veneno, caída). El daño produce sangre, punto. `data/fx/blood/none.tres` existe como dato, pero ningún look lo usa.
2. **Toda la sangre es roja.** Se reusa `assets/original/scars/blud.png` (mancha) y `assets/original/fx/blud.png` (partículas). Sin verde ni negro.
3. **Manchas permanentes**, en el mismo pool de «Cantidad de marcas» que las demás cicatrices (`GroundScars`), como el original.
4. **Destello sutil** de 0,12 s (pico 0,45, blanco cálido). Sin hit-stop.
5. **El mago sangra** con los mismos nodos (`BloodFx`, `HitFlash` en `wizard_body.tscn`), sin código nuevo.
6. Opción **«Sangre»** en Opciones → Jugabilidad: apaga salpicadura, manchas, charco y destello.

## Qué hace

- `BloodFx` (hijo de `unit.tscn` y `wizard_body.tscn`) escucha `Health.changed`, que llega a todos los peers porque `Health:current` se replica. En cada baja decide con `BloodRules.kind_for` si sangra (nada, liviano o fuerte); en ese caso, `FxBus.play` del spray en el socket CENTER y `GroundScars.stamp` de `blud` en un disco alrededor de los pies (FEET).
  - Un golpe aislado (sin otra baja en `every_s` = 0,25 s) siempre sangra. Las bajas seguidas (veneno, muro) se acumulan hasta `min_lost` = 4 % y sangran como mucho cada `every_s`.
  - Una baja de al menos `heavy_from` = 40 % del máximo es fuerte: `blood_hit_heavy.tres` y 3 manchas (liviano: `blood_hit.tres` y 1).
  - Sin mancha si los pies están a más de 1 m del suelo (voladores).
  - Calla si el cuerpo está oculto (el gib trae su sangre), sin ventana (dedicado) y, en un cliente en red, durante `quiet_s` = 0,5 s al entrar.
- `SprayMarks` (uno en `match.tscn`) pinta un charco de 12 manchas en 4 m cuando suena el chorro del gib (`data/fx/blood.tres`).
- `HitFlash` pone `data/fx/blood/hit_flash.tres` como `material_overlay` y anima su `instance uniform hit_flash` de 0,45 a 0 en 0,12 s; después lo saca. No destella con el cuerpo desvanecido (sigilo, hacerse el muerto, fantasma, invocación).
- `BloodType` (`data/fx/blood/red.tres`) guarda sprays, umbrales y mancha. `BodyLook.blood` permite que un look elija otra; vacío = el `fallback` de `BloodFx` (rojo).

Solo presentación: ningún nodo escribe la simulación, no hay RPC ni RNG global, y nada corre sin ventana.

## 060s: la misma sangre en todos los peers (decisión del usuario, 2026-10-26)

Plan `docs/archive/rfcs/plans/060s-blood-sync-plan.md`. Reemplaza «en cada peer, porque `current` se replica» y el `quiet_s` de arriba: el servidor decide la herida (`BloodRules.kind_for` en segundos de `MatchClock`) y la escribe en `BloodFx.wound` (pies del servidor, índice y si es fuerte), replicada por el sincronizador del cuerpo (spawn, al cambiar). Cada peer pinta una vez cada índice nuevo, con las manchas sacadas de `MatchSeed.rng(["blood", cuerpo, índice])`; la herida que llega al aparecer (rejoin) cuenta como ya mostrada. La semilla de la partida la fija el servidor en `SacrificeFlow._apply_match_choice`, la guarda `ActiveMatch` y la lleva `MatchWire` (`"seed"`) a todos; `MatchWorld` siembra en todos los peers. `SprayMarks` saca sus manchas de la semilla y el lugar del chorro; `DebrisPiece` integra en `_physics_process`. Sin RPC nuevo.

## Criterios (los chequea `debug/fx/blood_lab.tscn`)

`-- --blood-script` (con ventana): salpicadura liviana y fuerte en el centro, 1 y 3 manchas, sin mancha en el aire, ≤ 3 salpicaduras con diez golpes del 1 % en 1 s, `none.tres` no muestra nada, pico y fin del destello, sin destello en sigilo, la opción apagada no muestra nada y el gib deja ≥ 8 manchas. `-- --blood-headless`: nada activo sin ventana. Captura medible pendiente (plan §2.8, `f390_01`/`f390_03`).

## Fuera

Clip de dolor direccional (`damageFront…`, sin importar), sangre de otro color, desvanecer manchas, hit-stop y sangre en edificios. El Sac Doctor sangra como cualquier criatura (BloodFx y HitFlash en `doctor.tscn`).
