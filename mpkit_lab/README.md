# mpkit_lab

Qué es: un proyecto Godot chico que corre el ejemplo y las pruebas de MpKit sin ningún juego (solo `MpKit` y la sonda son autoloads).
Qué no es: un juego. `addons/mp_kit` es un symlink a `../addons/mp_kit`: prueba la copia canónica del kit.
Quién habla con quién: `probe/lab_probe.gd` juega el ejemplo `arena_2d` desde la línea de comandos (`--probe=solo|client|late|watch|lag|observe|lobby|private|invited|badcode|flood|floodwatch|basic`); `run/*.sh` lanza los procesos y junta los veredictos.
Editar: nada que configurar. Con una cola de Godot compartida (p. ej. la de AgentKit), `MPKIT_GODOT_GROUP=<group.sh>` y `MPKIT_GODOT_RUN=<run.sh>`.
Verificar: `bash mpkit_lab/run/all.sh` → `MPKIT ALL PASS` (tests, solo, LAN, dedicado, lag, inundación, salas por ENet, WebSocket y `wss://`, partida privada, varias instancias, asistente 2D y 3D). La prueba web es aparte: `bash mpkit_lab/run/web.sh` y abrir la URL que imprime en una pestaña visible.
