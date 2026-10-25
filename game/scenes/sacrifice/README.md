# scenes/sacrifice/

What: the sacrifice, where a Sac Doctor drops from a vortex, carries a creature to the site and four doctors run the ritual; its places (ring, push, reach, hang, vortex) are nodes of `sacrifice_places.tscn`.
Not: who may be sacrificed or what the AI decides (Engagement, ai/), or the balance numbers of a round (MatchRules).
Talks to: SacrificeSystem (door) -> Spawns, Targets, Casts, Starter; Ritual and DoctorBody are replicated actors; the rules reach the places through `MatchRules.sacrifice_places` -> SacrificeFacts.
Edit: move a ring, push or reach in `sacrifice_places.tscn` (a variant is an inherited scene, e.g. debug/sacrifice/barrier_places.tscn) · times in `data/match_rules.tres`.
Check: `bash tools/lint/conventions.sh` · debug/sacrifice/ritual_timeline.tscn (F6) · rules_suite sacrifice_places_cases and ritual_parts_cases.

---

El sacrificio: doctor, acarreo, ritual y sus estados (`doctor_states/`, `errand_states/`).

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/sacrifice/`.

`sacrifice_system.tscn` es la puerta (fachada) y sus hijos hacen el trabajo: `Spawns` (arma doctores, vórtices y rituales), `Targets` (preguntas), `Casts` (del inicio al fin del lanzamiento) y `Starter` (empieza el ritual cuando llega el portador). `SacrificeGround` es el único punto de suelo. Los lugares salen de `SacrificeFacts` (en metros).

La línea de tiempo antes/después se mide con `debug/sacrifice/ritual_timeline.tscn`.
