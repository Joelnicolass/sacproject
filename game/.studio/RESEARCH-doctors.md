# Doctores: Convert (`ccas`) y Desecrate (`ucas`) en el original

Fecha: 2026-10-12. Resumen del orquestador sobre el informe de investigación (lectura estática, nada probado en ejecución).
Fuentes: `sacengine/source/state.d` (citas archivo:línea), `game/cache/data/*.json` (datos del original) y Ghidra 12.1.4 headless sobre `Sacrifice.exe` (direcciones `0x…`). Ghidra necesita JDK 21 (`JAVA_HOME=/opt/homebrew/opt/openjdk@21/…`); las funciones se ubicaron por la tabla de acciones FSM del ejecutable (`SACDOC_MoveTowardsCorpse` → `0x449d30`). El snapshot `.rea-snapshots/sacrifice-exe` no servía (6 registros sin relación).

## De dónde sale el doctor

Nunca sale del altar ni del shrine. Sale de un vórtice rojo a 15 m de altura junto al blanco, en los dos hechizos (`state.d:10181-10213`; exe `0x44a8e0`, `0x44ac90`). Distancia al blanco: 20 m en sacengine, 25 m (con reintento a 17,5) en el original. Cae, rebota (invulnerable hasta terminar el rebote) y aterriza a unos 10 m del blanco. F38 («desde el altar del jugador») está mal.

El doctor es la criatura `dcas` (modelo `sacd`): vida 400, velocidad 10, regeneración 83,33/s continua, 0 almas. No se selecciona ni recibe órdenes, no ataca, no se aturde. Es atacable. Al morir no deja cadáver ni alma.

## Convert

No toma un alma y la acredita. Secuencia:
1. Casteo 2,22 s, 800 de maná, rango 20. Blanco: alma roja.
2. El doctor camina al cadáver; empieza a menos de 2 m (`state.d:15693`).
3. «Pump»: parado sobre el cadáver durante (almas+1) × 5 s (`state.d:15697`; exe `0x44a0f0`). Al empezar, la criatura revive con `max(400, 50 % de su vida máxima)`.
4. Se lleva a la criatura viva, flotando, hasta el altar **o shrine** propio más cercano al mago (fijado al castear).
5. A menos de 20 m del destino empieza un ritual: el portador muere y aparecen 4 doctores. Preparación 5 s y rondas de 13,5 s; `vidaMáx/550 + 1` rondas en sacengine. Al final la criatura se desintegra y las almas se suman directo al contador del mago.

Si matan al doctor: antes de llegar, el alma sigue roja y convertible; durante el pump, el cadáver vuelve a morir y el alma reaparece con su bando; mientras la lleva, **la criatura cae viva y de su dueño original**; con el ritual abortado, la criatura queda libre y viva.

## Desecrate

1. Casteo 5,56 s, 1000 de maná, rango 20. Altar enemigo a 75 m o menos del mago. Se sacrifica una criatura **propia y viva** (no héroe, familiar ni doctor).
2. El doctor aparece junto a la criatura, la levanta (a menos de 10 m) y la lleva al altar enemigo.
3. A menos de 20 m del altar empieza el ritual: **4 doctores alrededor del altar enemigo**, radio 20 m, a 45° + 90°·k (`state.d:15854-15874`; exe `0x447b50`, `0x447d00`).
4. Preparación 5 s. Después rondas de 13,5 s (caminar un cuarto de vuelta, disparar, esperar). Por ronda, al mago enemigo se le drena **200·(1+almas) de vida** y **40·(1+almas) de maná** (`state.d:16009-16013`; exe `0x465530`, `0x448190`). Al mago no lo arrastran.
5. **No hay duración fija.** Termina cuando el mago muere. Con un mago de 1500 de vida y una criatura de 1 alma son unas 4 rondas, unos 55 s.
6. Si el mago muere bajo ritual no pasa a fantasma: desaparece. El altar se destruye de inmediato (animación de 11 s) y el bando queda derrotado (`state.d:15901-15903`, `5289-5291`, `26062`).

Cancela: muere **cualquiera de los 4 doctores**, o el altar deja de existir. Antes del ritual: muere el portador o el blanco deja de ser válido. El ritual empuja hacia afuera todo lo que esté a menos de 20 m del altar.

## Qué cambia respecto de RFC-017

- `desecrate_chant_s = 7,5` no existe en el original: va `ritual_setup_s = 5`, `ritual_round_s = 13.5`, daño y maná por ronda, y fin por muerte del mago.
- La condición de victoria es al revés de lo que asume 017a: el ritual mata al mago y **eso** destruye el altar; no «altar destruido y después muere el mago».
- El doctor no nace «donde estaba la criatura sacrificada»: la criatura sigue viva hasta el final.
- Un Sac Doctor muerto mientras carga suelta una criatura viva y enemiga, no un alma sin bando.
- `give_up_s` no existe: el doctor espera si el altar está ocupado y aborta si el blanco deja de ser válido.
- Matar al doctor durante el pump de Convert es la ventana real de contrajuego.

## Sin verificar

Qué hace el original con un mago en fantasma durante el ritual; si la IA ataca sola a los doctores; los datos FSM del doctor en los WAD; la preparación de 5 s en el original.
