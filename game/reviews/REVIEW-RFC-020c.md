# REVIEW RFC-020c (F59) — Desecrate: casteo, vórtice, portador y efectos

Fecha: 2026-10-13
Reviewer: studio-reviewer, dos pases de solo lectura (lógica y efectos); el orquestador resumió y guardó este informe.

## Veredictos

| Pase | Criterios | Arquitectura | Alcance |
| --- | --- | --- | --- |
| Lógica (casteo, portador, cautiva) | PASS | PASS | PASS |
| Efectos (aro, cuerda, vórtice) | PASS | PASS | PASS |

Sin bloqueantes. El primer pase había quedado en NEEDS WORK por un supuesto defecto visual («la criatura va arrastrada por el suelo») que resultó un malentendido del orquestador: el usuario había visto a la criatura en el aire, que es lo correcto, sin el efecto que la une al doctor.

## Lógica

- Camino feliz medido en solo: el doctor nace a los 5,55 s, toma a la criatura a los 8,0 s (`mode = 8`, fuera del grupo `unit`, `collision_layer = 0`) y espera a 19,8 m del altar; altar en pie y sin ganador.
- Cuadro a cuadro: la criatura sube a 3,4 m en 1 s y se mantiene a 3,5 m sobre el doctor, 3,3 a 3,8 m detrás; nada más le escribe la posición.
- Muertes: casteo interrumpido, doctor muerto caminando, doctor muerto llevándola y criatura muerta antes de la levantada: correctos. Altar enemigo que cae durante el acarreo: el portador muere y la criatura queda libre.
- Validación en el servidor antes de gastar maná: dueño, grupo, vida, estado y altar; la posición sale del cuerpo, no del cliente.
- Los `free()` de `debug/sacrifice_cases.gd` que habían abortado Godot cinco veces están corregidos; no hay `free()` en el código de producto nuevo.

## Efectos

- Solo presentación: no tocan posición, colisión, vida ni el recado; en el dedicado no se crean ni cargan texturas.
- `DoctorBody.carried` (ruta a la criatura) llega al cliente durante todo el acarreo y resuelve a la criatura correcta.
- El aro es hijo de la criatura y se cierra en 0,75 s al soltarla; la cuerda es hija del doctor. Sin `free()` nuevos.
- Todos los valores son `@export` o `.tres`, con la cita de sacengine. Las escenas abren en el editor sin errores y no guardan texturas del caché.

## Nits

1. `carried` no se limpia en el servidor si la criatura muere con un portador no válido; el cliente lo tolera.
2. `PortalDisc` deja `_process` encendido en headless; `RedVortex` usa otro criterio que el resto para no dibujar.
3. La criatura tomada es invulnerable (decisión no documentada en el RFC).
4. Una criatura en forma de roca, sigilo o haciéndose la muerta puede ser tomada y al soltarla vuelve a reposo.
5. `carry_distance` fijo en 2,7 en vez de depender de la escala.
6. `unit.tscn` re-guardada desde el editor embebe texturas y mallas del caché (`BodyVisual`): previo a este corte.
7. Segundo Desecrate con otro en curso, sin probar (lo bloquea el enfriamiento).
