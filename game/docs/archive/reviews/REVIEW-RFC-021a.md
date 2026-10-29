# REVIEW RFC-021a (F62) y corrección de F58

Fecha: 2026-10-13
Reviewer: studio-reviewer (pase de solo lectura; el orquestador resumió y guardó este informe).

## A. RFC-021a — Despacho de la pestaña Estructuras

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS |
| Arquitectura | PASS |
| Alcance | PASS |

Sin bloqueantes.

- Sonda del developer repetida por el reviewer en los 10 escenarios: diff vacío contra la línea base del código viejo.
- El estado pendiente del Manalith vive solo en `ManalithAction` y se limpia en `finish` y en `cancel`. El manantial no se reserva durante el casteo: si el mago muere queda libre, y si lo ocupan a mitad de casteo la respuesta es «Sin fuente».
- `submit_structure` y la validación de sender no cambiaron. El servidor revalida todo en `_try_action`; no confía en lo que manda el cliente.
- Editor headless: `wizard_body.tscn` carga sin errores; `Caster/Actions/Manalith` muestra `tag`, `pick` y `prompt`.
- 7 escenas de regresión sin `ERROR`; `rules_suite` con `action_lookup` y `manalith_action` en PASS.
- Red: dedicado + un cliente headless; el cliente construye y ve la vida bajar hasta 1598.

No corrió: segundo cliente, clic con ventana, las ramas `OWN_UNIT`, `SOUL`, `OWN_BUILDING` en ejecución.

### ¿El contrato alcanza para Desecrate, Convert, Guardian y Teleport?

Sí, con estos huecos a tener presentes:
- No hay gancho por cuadro durante el casteo. Desecrate puede instanciar su vórtice en `begin`; Teleport puede recalcular el destino en `finish`. Si el blanco muere a mitad de casteo, `finish` recibe `target = null` y la acción tiene que manejarlo. Un `tick` opcional lo resolvería.
- `arm_status` puede decir «Lejos de un edificio propio» (Guardian).
- El cliente manda un `NodePath` arbitrario: cada acción tiene que validar dueño, grupo y estado, y tomar la posición del cuerpo, no la del cliente. Anotado por el orquestador en el comentario de `SpellAction.check`.
- `cancel()` no recibe argumentos: la acción guarda lo que necesite para saber qué cancelar.

### Nits

1. `manalith_action.gd` conserva `.call` / `has_method` y búsquedas por grupo hacia el manantial y el spawner (código movido, no nuevo).
2. `_caster` no está tipado en `match_command.gd`.
3. `action_for` recorre los hijos en cada llamada en vez de un diccionario.
4. El aviso «ClipPose: Assign mesh_path…» en `wizard_body.tscn` es preexistente.

## B. Corrección de F58 — el Sac Doctor de pie

| Dimensión | Veredicto |
| --- | --- |
| Criterios | PASS |
| Arquitectura | PASS |
| Alcance | PASS |

- `POSE AUDIT PASS`, 32 modelos. `doctor_bench` sin `ERROR`. `doctor.tscn` re-guardada no embebe mallas ni clips.
- Capturas del developer: tres doctores de pie, con los pies en el suelo; la jeringa y los brazos sobresalen de la cápsula; el cuerpo queda algo corrido según la animación.
- El mapeo pose → clip es dato editable. La animación corre solo con mallas y no toca posición, colisión ni vida. El cliente anima por `pose` y `work` replicados.
- `GAME_ACTOR_CREATURES` es una lista general del exportador, no un caso especial en el horneado.

Nit resuelto por el orquestador: `_apply_pose` corría en el editor y poner `DYING` en el inspector podía ensuciar la escena; ahora sale temprano en el editor.

No corrió: `doctor_melee`, ni nada con ventana.

## Para el playtest con ventana

Manalith desde el libro en solo; `spell_2` a `spell_5` en «No implementado»; el doctor en juego (de pie, cayendo, bajo ataque) y que un clic le acierte; con un cliente, las poses por réplica.
