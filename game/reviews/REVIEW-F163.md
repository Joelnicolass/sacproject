# REVIEW F163 (030w-f, escudo de fuego del Phoenix) — CHANGES_REQUESTED (un bloqueante de costo, menor)

Fidelidad (sacengine state.d 13899-13931, 17254-17261, 218-225): PASS.
- Caja ×1,5 desde el centro, cada cuadro, no aliados (stance != ally), edificios fuera (movingObjectById), maná solo si el SPEL lo pide (rifl: 0) y se drena una vez si quemó a alguien: fire_shield.gd:62-83. Daño amount/60 como hechizo directo con pierce_shield, igual a dealFireDamage(peirceShield): fire_shield.gd:86.
- ignite también fija ignitionTime (solo para el sonido 1ngi): cosmético, no es regla. Sin duplicar Burning: no hay estado de fuego propio, el daño pasa por Health.damage_typed.
- canShield: la aproximación (vivo + is_targetable) es más estricta que el motor en un caso: un Phoenix en sigilo/cautivo pierde el escudo (el motor lo mantiene en stunned, cower, rockForm, firewalk, etc.). Un Phoenix reviviendo/fantasma queda excluido por is_dead/is_targetable. Nit, ya declarado como deuda en FEATURES.md.
- El cuerpo objetivo también debe ser is_live_body (is_targetable): el motor quema sigilosos; divergencia declarada, nit.

Costo: NEEDS WORK (bloqueante menor).
- fire_shield.gd:56: el nodo vive en TODAS las unidades y su _physics_process corre cada cuadro en cada una (has_authority + _carries con "type" in body + get). No hay set_physics_process(false) en _ready para criaturas que no son rifl. `type` se asigna en unit_body.gd:130 antes/después de _ready no está garantizado: apagar en _ready solo si type ya está puesto, o que unit_body (dueño del tipo) lo active/desactive al asignar. Pedido: cachear _carries() una vez y llamar set_physics_process(false) si no lleva la pasiva (o instanciarlo solo para rifl).
- O(n) por Phoenix por cuadro (2 grupos x todos los cuerpos, box_of por candidato): aceptable, hay a lo sumo unos pocos Phoenix; el rechazo temprano por |dx|,|dz| es barato. Sin acción.

Un dueño: PASS. Daño solo vía Health; unit_body.gd sin cambios; nodo hijo con sockets @export (body/health/mana) asignados en unit.tscn; tunables en el inspector.

Red/determinismo: PASS. _has_authority() (servidor o solo); get_nodes_in_group sigue el orden del árbol (estable); el daño por víctima es conmutativo salvo muerte en el mismo cuadro con dos Phoenix (orden de árbol, igual en las 3 corridas: digest 83189d94 en fixed/stress/window).

Nits: static var log_shield es global de banco (ai_match lo enciende): aceptable. `_burn_ticks`/`_allies_seen` crecen con ids de instancias muertas, solo con log. Visual del look (partículas de reserva) queda para studio-visual.

Veredicto: CHANGES_REQUESTED solo por apagar el _physics_process en no-rifl; el resto se puede dar por cerrado.

## Cierre (orquestador, 2026-10-17)
Corregido en 66cefff: `FireShield` duerme salvo en `rifl` (reevaluado en `_ready`, diferido y `model_changed`), y `canShield` sigue el del motor (activo aturdido, encogido, en rockForm, firewalk y sigilo; cae en DEAD, SUMMONING, REVIVING y tomado por un Doctor). `f163` 83189d94 igual; `quick` 27/27 OK; `f163_expect.py` PASS.
