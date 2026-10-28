# scenes/sacrifice/

What: the sacrifice, where a Sac Doctor drops from a vortex, carries a creature to the site and four doctors run the ritual; its places (ring, push, reach, hang, vortex) are nodes of `sacrifice_places.tscn`.
Not: who may be sacrificed or what the AI decides (Engagement, ai/), or the balance numbers of a round (MatchRules).
Talks to: SacrificeSystem (door) -> Spawns, Targets, Casts, Starter; Ritual and DoctorBody are replicated actors (the doctor through an `MpActor` BUFFERED, 30 Hz: on a client only that node writes its pose; the creature it carries is moved by its own actor, never by the doctor); the rules reach the places through `MatchRules.sacrifice_places` -> SacrificeFacts.
Edit: move a ring, push or reach in `sacrifice_places.tscn` (a variant is an inherited scene) · times in `data/match_rules.tres`.
Check: `bash tools/lint/conventions.sh`

---

El sacrificio: doctor, acarreo, ritual y sus estados (`doctor_states/`, `errand_states/`).

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`.

`sacrifice_system.tscn` es la puerta (fachada) y sus hijos hacen el trabajo: `Spawns` (arma doctores, vórtices y rituales), `Targets` (preguntas), `Casts` (del inicio al fin del lanzamiento) y `Starter` (empieza el ritual cuando llega el portador). `SacrificeGround` es el único punto de suelo. Los lugares salen de `SacrificeFacts` (en metros).
