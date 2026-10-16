# REVIEW RFC-017c (F46) — Higiene de red

Fecha: 2026-10-12
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).
Arquitectura: estándar. Multijugador: online dedicado.

## Veredictos

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS |
| Arquitectura | PASS |
| Alcance | PASS |

Sin bloqueantes. El corte se cierra; queda el playtest de dos clientes.

## Qué corrió el reviewer

| Corrida | Resultado |
| --- | --- |
| Parseo headless | exit 0, sin `ERROR` |
| `debug/rules_suite.tscn` | 5 casos PASS, `RULES SUITE PASS` |
| `structure_siege`, `cast_heal`, `orders_group`, `soul_pickup` en solo | sin `ERROR` |
| Dedicado real con `--world=res://debug/structure_siege.tscn` | `dedicated listo puerto 7831`, `en high noon slot 0`, sin errores |
| Mini-proyecto (servidor + cliente tardío, mismo patrón que `structure.tscn`), 4 variantes | ver «Entrada tardía» |

No corrió: flows con ventana, un cliente real contra el dedicado, segundo cliente, `submit_ability` por RPC ni caminos de rechazo por red. Los `AGENT_OK` y la bajada de vida 3000 → 2647 son declaración del developer.

## Validación de sender: equivalencia

Antes: `is_server()` y `owner_slot > 0` y `slot_for_peer(sender) == owner_slot`. Ahora: `is_networked()` y `is_server()` y `sender == peer_id_for(owner_slot)`.

| Caso | Antes | Ahora |
| --- | --- | --- |
| Dedicado, RPC del dueño | acepta | acepta |
| Dedicado, peer sobre actor ajeno | rechaza | rechaza |
| Dedicado, `owner_slot` ≤ 0 | rechaza | rechaza |
| Dedicado, slot sin peer | rechaza | rechaza |
| Dedicado, peer sin slot | rechaza | rechaza |
| Cliente | rechaza | rechaza |
| Solo | rechaza | rechaza |

Las tablas slot ↔ peer de `mp_ids.gd` son biyectivas, así que comparar por peer o por slot da lo mismo. En solo los `request_*` siguen sin pasar por RPC. `command_slot` y el README son genéricos: no nombran nada de Sacrifice.

Única diferencia teórica: una llamada directa (no RPC) en el servidor a `submit_drive`, `submit_walk` o `submit_ability` sobre un actor de slot 0 o sin peer ahora se aceptaría. No hay ningún caller así. Es comportamiento previo de `accept_command` del kit.

## Sincronizador y `MpSpawner`

Con el sincronizador en la escena, `MpSpawner` ya no crea el `MpSpawnGate`; lo captura al entrar al árbol, lo oculta y lo revela a los peers con `world_ready`. Mismo camino que `unit.tscn`.

## Entrada tardía

El motor aplica el spawn state antes de `_ready`, y `structure_body._apply_health()` lo pisaba en el cliente con el máximo. Medido en el mini-proyecto: el primer delta lo corrige en menos de 0,2 s. Nit, no bloqueante. Resuelto por el orquestador: `_apply_health()` no corre en el cliente.

## Nits

1. `_apply_health()` en el cliente. Resuelto.
2. `.claude/skills/godot-mp-kit/kit-api.md` no lista `command_slot`. Va con la subida al kit.
3. `accept_command` acepta una llamada directa con sender 0 sobre un slot sin peer. Del kit, previo; anotarlo al subir `command_slot`.
4. `agent/out/multiplayer_suite.png` quedó huérfano.
5. F42 en `FEATURES.md` seguía con el nombre viejo. Resuelto por el orquestador.

## Para playtest

- `rfc017c_siege_a/_b` con dedicado y dos clientes: B ve `Structures/Structure1/Health.current < 3000`.
- Entrada tardía con la estructura ya dañada.
- Regresión con ventana: `f20_client_a/b`, `f24`, `f27_pt`, `f30_pt`, `f31`.
- `submit_ability` por RPC.
- Un rechazo: B ordenando o casteando sobre un actor del slot 1 no debe tener efecto.
