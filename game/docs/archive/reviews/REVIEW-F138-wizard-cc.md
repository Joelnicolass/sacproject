# REVIEW F138 (030i-c): magos aturdidos y petrificados

**Veredicto: NEEDS WORK.** Hay un bloqueante chico. El revisor es de solo lectura; el orquestador guardó este informe el 2026-10-16.

## Bloqueante
**B1. Si el mago muere aturdido, queda levantado `body_radius` para siempre.** `Stunned._play_fallback(false)` no devuelve `Tilt.position.y` a 0 si el cuerpo está muerto, porque da por hecho que existe `Corpse`, y el mago no lo tiene. El fantasma y el mago revivido quedan flotando, también en el cliente.

## Fidelidad a sacengine: PASS
- **`canStun` y `canBePetrified`:** son equivalentes a `is_targetable()`, es decir, mago ALIVE.
- **Duración:** `(knock + get_up)·2`. El arreglo de `hitFloor` no la modifica (`sacobject.d:844-874`).
- **Piedra:** 2,5 s.
- **Corte del lanzamiento:** se pierde el maná drenado, igual que en el original (`state.d:15138`, `15206-15213`).
- **Regeneración:** sin vida mientras el mago está retenido (`1429`). El maná sigue entrando.

## Un dueño: PASS
- `pose_role` está compartido.
- Todos los lectores respetan `holds()`, vía `can_cast`: Caster, IA, `match_command`, estructuras, Manalith. La caminata queda guardada.

**Nit:** hay dos `body is WizardBody` en componentes compartidos. Conviene reemplazarlos por duck typing.

## `Mesh` → `Tilt/Mesh`: PASS
No quedan referencias viejas. Que `f20_solo` falle en `%God_persephone` (en el menú, antes del paso cambiado) no es culpa de este corte. Hay que confirmarlo contra HEAD.

## Determinismo: preexistente, no bloquea este corte, pero es una alarma real
`spellbook.gd` descuenta los enfriamientos de hechizos en `_process(delta)`, con el delta de render, y lo hace así desde el primer commit. Con ventana, el reloj de render se separa del de simulación y la IA decide distinto. **Hay que abrir un corte aparte: enfriamientos en ticks de física.** Candidato secundario: el `warm` de `ClipPosePlayer`, que tiene presupuesto en tiempo real.

## Red: PASS
El servidor simula, `shown` se replica, la entrada del cliente se descarta y `walk` queda guardado.

## Composición: PASS

## Nits
- `PathFollower` vuelve a planear la ruta mientras el mago está retenido.
- Al levantarse, `rotation.y` salta.
- No se puede armar un hechizo mientras el mago está retenido (sacengine sí deja seleccionarlo).
- Hay que confirmar que `_regenerate` → `can_cast()` no cambia la regeneración del mago libre.
