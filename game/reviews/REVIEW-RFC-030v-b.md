# REVIEW RFC-030 030v-b (F160)

Veredicto: APPROVE. Sin bloqueantes.

1. Fidelidad: PASS. Duraciones (max(duration, 6/5 s) en ticks), FX (dirt +0.3, spit_trail +1.0), costo/cooldown (fire true -> _pay + _start_cooldown(true) en active_ability.gd use()) y caparazon de Rockform (rockform.gd:36-64) coinciden con las ramas borradas. Rockform sigue cerrando via UnitBody:872 -> active_ability.gd:205 -> efecto.
   - Cambio menor: status() ahora aplica `using.is_on() -> BAD_TARGET` tambien a estas tres (active_ability.gd, rama `if _effect`). Solo afecta con UsingAbility activo, que sin windup no ocurre con estas habilidades. Nit.
   - Orden del apagado: antes iba al inicio del _physics_process de ActiveAbility; ahora en el nodo hijo Effect (corre despues del padre, mismo tick). Sin lectores intermedios en ese tick; nit.
2. Exports borrados: PASS. grep en .tscn/.tres: ninguna escena ni recurso seteaba rock_* ni stealth_alpha (unit.tscn:212-214 solo setea `catalog`). Nada se pierde.
3. Un dueno: PASS con nit. El timer (_until) tiene un solo escritor (timed_state_ability.gd). El flag lo tocan tambien UnitBody.clear_special_states (muerte) y Divine Sight (divine_sight.gd:21), igual que antes.
   - Nit: `body_setter` como StringName con guard `has_method` (timed_state_ability.gd:36,47): un typo falla en silencio. Sugerencia opcional: push_warning si !has_method en setup.
   - Sin codigo solo-harness: no hay `func agent_*` nuevo.
4. Red: PASS. fire() exige _has_authority() (timed_state_ability.gd:34, rockform.gd:28); _physics_process del efecto solo se enciende desde fire(), asi que en clientes nunca corre. ActiveAbility sigue apagando su physics en clientes.

Alcance: sin extras. Look de Rockform en rockform.tscn con defaults (editable en inspector).
