# REVIEW-RFC-024d — Economía, captura y profanación (F75)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador (el rol es de solo lectura).

**Veredicto: NEEDS WORK.** Las cifras de la adenda §6 «024d» se cumplen en las corridas repetidas, los digests coinciden con los del developer y no hay trampa. **Un bloqueante (B1):** cada partida contra la IA escupe entre 25 y 152 `SCRIPT ERROR` por instancias liberadas en `unit_orders.gd`, no mencionados en el informe. Dos NEEDS WORK no bloquean este corte: `_check_jam` y el p99.

## Corridas del reviewer (headless, --fixed-fps 60, de a uno)

| Comando | Resultado |
|---|---|
| `ai_match ai_vs_trivial --seed=1 --minutes=30` | gana slot 2 por `desecration` en tick 46203 (12,83 min); digest `1e940c4e60924fa8…` = dev; primer Manalith tick 1166 (19,4 s); a 10 min `npc_kills` 18, `by_origin.npc` 15; libro exacto; `npc_touched` 0; `rejections {}`; `ai_ms` mean 0,139, p99 **3,076**, max 16,8; decisiones p99 0,626; `ai_orders` **36006**; `ai_jams` **33**; RSS 429 MB; 176 s; **34 SCRIPT ERROR** |
| `… --seed=5` ×2 | digest `7e594bbddba52b85…` ambas = dev; ritual tick 51084 (14,19 min); kills 14, npc 9; libro exacto; p99 2,045/2,048; decisiones 0,563; jams 18; RSS 444 MB; **100 SCRIPT ERROR cada una** (deterministas) |
| `ai_duel_seeded --seed=7` | `d0cd72835a86…`, fin 2096 = F72; 0 errores |
| `… --npcs` | `085514300ec3…`, fin 3159 = F73; 0 errores |
| `ai_guard --seed=1 --minutes=2` | `engaged_after_s 0,58` con 2 unidades (max_guarding 3); 0 errores |
| `doctor_path` | PASS: 1 alma en 47,5 s, ningún doctor trabado, portador 196 m, pasa a 25,3 m del pilar |
| `doctor_path --nofollow` | FAIL esperado (control): 1 doctor trabado, 0 almas |
| `rules_suite` | PASS, 83 casos, 4,9 s |
| `ai_no_souls --seed=1 --minutes=3` | 1 convocatoria (tick 8504, `souls_before 1`): mata Farmer5 con `kcor` (tick 2), convierte Soul1 (tick 548); libro start 0 / converted 1 / spent 1; `rejections {}` |

Semillas 2–4 tomadas de los JSON del developer (`t11_s2..4`); con las propias, criterios 5/5.

## Criterios (adenda §6 024d)

Todos PASS (primer Manalith, victoria por ritual, npc_kills, by_origin.npc, libro exacto, sin convocatorias con almas insuficientes, toda alma de NPC por Convert, ai_guard, ningún Desecrate «Blanco inválido», piezas presentes). Playtest pendiente.

## Bloqueante

**B1. `SCRIPT ERROR` por instancias liberadas, disparados por la IA** (34 en s1, 100 en s5, 25–152 en los `.time` del dev; ninguno en 024c).
- `scenes/world/units/unit_orders.gd:148` (`_hold`): `var current: Node3D = _body.get("target")` con blanco liberado; backtrace por `ai_task_board.gd:176`, `ai_command_port.gd:139/120/219`, `orders.gd:51/105`.
- `unit_orders.gd:112` (`_think`): `_guardable(target)` recibe objeto liberado.
- Corta el `_think`/`_hold` de esa unidad en ese tick. Es código compartido con el jugador: un humano que ordene guard sobre algo que muere lo dispara igual.
- Corrección: `is_instance_valid` antes de tipar `target` y `_body.get("target")` en `_think`, `_hold` y `RETREAT`.
- Cierre: `grep -c "SCRIPT ERROR"` = 0 en s1 y s5; digests de s7 con y sin NPC sin cambios; si cambian los de s1/s5, re-medir los criterios.

## Preguntas del orquestador

1. **Puerto único y sin trampa — PASS.** Todo por `AiCommandPort`; `apply_for` (`orders.gd:47-51`) valida en `_own_units`/`_can_order`; sin RPC; `AiSide`/`AiPerception` apagados en clientes. Almas reales con el epsilon del Caster. `fount.is_free` en vivo solo cerca del manantial (= `canCastSpellOn`). Manantiales marcados por visión para siempre = sacengine (state.d:29668). Almas sin filtro de visión = sacengine (shiny.d:583, 633).
2. **`_check_jam` — NEEDS WORK (no bloquea).** El comentario (`wizard_brain.gd:174-178`) es falso: unidades `collision_layer 2`/`mask 1` y mago máscara 1 no chocan físicamente; el bloqueo viene de `BodySeparation` (port de `positionAfterCollision`, state.d:14446+), que en sacengine tampoco exime al propio bando. Recomendación: dejar el workaround como desvío declarado y corregir el comentario; sacar/marcar los knobs `jam_*` de `AiProfile` (`ai_profile.gd:88-94`) como desvío; ticket en la capa de juego: probar si un mago HUMANO con escolta en guard también queda encerrado y, si sí, arreglarlo donde vive (escolta detrás del sentido de marcha, cuerpo propio quieto que abre paso, o PathFollower que replanifica con cuerpos). 33 jams en s1 y 18 en s5. Nit: ángulo con `t.id % 628` (instance id) en `wizard_brain.gd:196`: derivarlo de MatchSeed o del nombre.
3. **p99 de 3 ms — NEEDS WORK (bloquea 024e).** p99 del tick completo subió de 0,70 (024c) a 2,0–3,1. No lo explican las 36 convocatorias por partida sino el volumen de órdenes: 36006 en 12,8 min (~9 por tick de k5; 024c daba 3845 en 3 min). Cada orden paga `Orders._apply` (formación, `PathFollower.go_to`, A*) y un `print` (`orders.gd:107`). Recomendación: mantener el criterio sobre el tick completo; antes de 024e medir cuántas órdenes repiten la misma orden a la misma unidad (sospechas: `_has_live_order` falso al volver `command` a NONE; `SAME_POS_SQ` de 1 m con anclas móviles, `ai_command_port.gd:113-118`); sacar o condicionar el `print`; anotar en el RFC el escalonado k3/k5 (`ai_side.gd:42-44`, desvío de shiny.d:459-500). Nit: comentario de `ms_stats` (`ai_side.gd:191`).
4. **Fidelidad a shiny.d — PASS con nits.** CaptureTask (shiny.d:2118-2194, 2262-2286), ConvertPhase (3088-3114), SupportPhase (3073-3087), ManahoarBrain (2572-2608), ruta de almas (3339-3346), bloque cmd 2 (3348-3382) y fantasma (3306-3326) coinciden. Omitida (declarado) la rama de caza del mago (shiny.d:2147-2151): anotarla en el RFC. Nit: `pick_guard_creature` (`wizard_brain.gd:106-129`) no excluye criaturas atadas por Guardian (`isGuardianEnt`, shiny.d:3032).
5. **Cambios fuera de la IA — PASS.** Doctor con PathFollower (apagado en clientes, `path_follower.gd:54`); StuckGuard reinicia por tramo (nit: comentario viejo `stuck_guard.gd:5-6`); NavService 7 ms por reconstrucción, ~6 por partida; SideVision y orders.gd cubiertos; el camino humano de `submit_order` no cambia.
6. **Criterio de `ai_no_souls` — NEEDS WORK documental.** El cambio es legítimo (la IA mata, convierte y convoca con 1 alma) pero un developer no reescribe un criterio de la adenda. Propuesta: «toda convocatoria con `souls_before ≥ cost_souls`, `rejections["Sin almas"] == 0`, libro exacto», o apagar los NPC en `ai_no_souls.tres`.
7. **Determinismo y red — PASS.** Digests reproducibles; sin RPC; sin azar nuevo en `scenes/world/ai` (salvo el nit del instance id).

## Composición — PASS con nits
`ai_side_trivial.tscn` es copia justificada (no se pueden borrar hijos heredados) pero está en `scenes/world/ai/` y el RFC lo pide en `debug/`. `AiSide._wizard_info` (`ai_side.gd:238-263`) es diagnóstico dentro de un nodo de producto: moverlo a `AiAudit` o `debug/`.

## Nits
1. `wizard_brain.gd:174-178` comentario falso. 2. `ai_profile.gd:88-94` knobs `jam_*` mezclados. 3. `wizard_brain.gd:196` instance id. 4. `wizard_brain.gd:106-129` exclusión de guardianes. 5. `ai_side.gd:191` comentario. 6. `stuck_guard.gd:5-6` comentario. 7. `orders.gd:107` print por orden. 8. `ai_side_trivial.tscn` fuera de `debug/`. 9. RFC: anotar escalonado k3/k5 y la rama de caza omitida. 10. El developer violó ~2 s la regla de un proceso.

## ¿Se cierra?
No todavía: una corrección para B1. Después, playtester con ventana sobre `ai_match` semilla 1 y `ai_endgame`. Diferibles con ticket: el encierro del mago en la capa de juego y el volumen de órdenes (antes de 024e). Criterio de `ai_no_souls`: lo reescribe el orquestador/tech lead.

Salidas: `agent/out/ai/rev75_{s1,s5a,s5b,s7,s7npc,guard,nosouls}.json` y `.log`, `rev75_doc.log`, `rev75_doc_nf.log`, `rev75_suite.log`.
