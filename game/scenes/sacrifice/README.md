# scenes/sacrifice/

El sacrificio: doctor, acarreo, ritual y sus estados (`doctor_states/`, `errand_states/`).

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/sacrifice/`.

`sacrifice_system.tscn` es la puerta (fachada) y sus hijos hacen el trabajo: `Spawns` (arma doctores, vórtices y rituales), `Targets` (preguntas), `Casts` (del inicio al fin del lanzamiento) y `Starter` (empieza el ritual cuando llega el portador). `SacrificeGround` es el único punto de suelo. Los lugares salen de `SacrificeFacts` (en metros).

Check: `bash tools/lint/conventions.sh` y, con ventana, `debug/sacrifice/ritual_timeline.tscn` (línea de tiempo antes/después).
