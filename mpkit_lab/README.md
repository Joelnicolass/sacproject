# mpkit_lab

Qué es: un proyecto Godot chico que corre el ejemplo y las pruebas de MpKit sin ningún juego (solo `MpKit` y la sonda son autoloads).
Qué no es: un juego. `addons/mp_kit` es un symlink a la copia canónica del kit. `addons/lab_editor_check` es un plugin solo del laboratorio, que no hace nada sin `MPKIT_EDITOR_CHECK`.
Quién habla con quién: `probe/lab_probe.gd` juega el ejemplo `arena_2d` desde la línea de comandos (`--probe=solo|client|late|watch|lag|observe|lagshooter|lagtarget|lobby|private|private_other|invited|badcode|flood|floodwatch|basic|…`); `run/*.sh` lanza los procesos y junta los veredictos.
Editar: nada que configurar. Con una cola de Godot compartida (p. ej. la de AgentKit), `MPKIT_GODOT_GROUP=<group.sh>` y `MPKIT_GODOT_RUN=<run.sh>`. El relay local necesita Node; la prueba web, las plantillas de export Web y un Chrome o Chromium (sin él, dice SKIP).
Verificar: `bash mpkit_lab/run/all.sh` → `MPKIT ALL PASS`. Cubre los tests del kit, solo, sesión, las reglas del relay, arena (LAN, dedicado, lag con calidad de red y demora remota, disparos con compensación de lag, inundación), salas y partida privada por ENet, WebSocket y relay, salas por `wss://`, un cliente web por WebSocket y por relay, varias instancias, el asistente 2D y 3D, y `MpWorld` y el asistente en el editor real. Qué prueba cada caso: [CASES.md](CASES.md).
Mirar en ventanas: `bash mpkit_lab/run/play.sh dedicated|listen|rooms [--watch] [--relay]` (sin `--watch` jugás vos).
