# Rules

Producto: juego Godot 4. Checks de web, SQL, auth y negocio: no aplican.

## Stack

- Godot 4.7.2 (`/Applications/Godot.app`, binario `/Applications/Godot.app/Contents/MacOS/Godot`). Verificado con `--version`.
- GDScript.
- MpKit 0.6.0 (`plugin.cfg`); RFC-034 la lleva a 0.7.0 dentro del juego hasta el RC del kit. No meter reglas de Sacrifice en el addon. Si el plugin necesita un arreglo, se edita: el autor es el mismo del juego y el cambio se sube después a `godot-studio-skills`.

## Arquitectura

Estándar. Escenas en `scenes/`. Sin `src/domain/`.

Autoload: `MpKit` antes que `SacrificeFlow`.

## Red

Online = servidor de salas + dedicado por partida. El dedicado admite solo con ticket (`MpKit.admission`; sin `admission` queda el modo directo `join(ip)` de hoy, para pruebas y banco). Los clientes no escriben IP: `MpLobby` + `join_endpoint`. `play_solo()` no abre servidor. El host LAN no es el camino de internet. Lo genérico de salas vive en `addons/mp_kit/lobby/` sin textos ni reglas de Sacrifice; validadores, opciones y resultado van en `scenes/net/`.

Puntuación, textos y victoria viven fuera de `addons/mp_kit`.

## Datos

La instalación de Sacrifice se lee en local. Los WAD no se commitean nunca.

Desde el 2026-10-17 (decisión del usuario, RFC-023), los assets finales del port se versionan en `game/assets/original/` con git LFS: cada modelo es un `.glb` con su esqueleto y todas sus animaciones, uno por modelo, sin copias por cuadro. El port no depende de ninguna caché: todo sale de `assets/original/` (RFC-033).

sacengine aporta los datos y los números del juego (mapa, paso medido, órdenes). En Godot el movimiento usa el motor: `CharacterBody3D`, `move_and_slide`, colisión y gravedad. No se reescribe un integrador ni un rayo de pies al lado de eso. El dedicado, cuando hay red, es quien mueve el cuerpo. El cliente manda la orden y pinta.

## Idioma

Textos de pantalla en español. Nombres de archivos y de nodos en inglés.

## IA

La IA es un jugador más. Todo lo que hace pasa por un solo puerto que llama a lo mismo que el humano (`request_cast`, `request_summon`, `Orders`): paga maná y almas y respeta enfriamientos y alcance. Sin bonificación de recursos ni trampa, en ninguna dificultad. Existe solo en el proceso que simula (solo o dedicado) y no agrega RPC. Vive fuera de `addons/mp_kit`. Las partidas con IA son reproducibles con `match_seed`.
