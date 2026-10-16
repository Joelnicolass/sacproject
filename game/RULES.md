# Rules

Producto: juego Godot 4. Checks de web, SQL, auth y negocio: no aplican.

## Stack

- Godot 4.7.2 (`/Applications/Godot.app`, binario `/Applications/Godot.app/Contents/MacOS/Godot`). Verificado con `--version`.
- GDScript.
- MpKit 0.5.0. No meter reglas de Sacrifice en el addon. Si el plugin necesita un arreglo, se edita: el autor es el mismo del juego y el cambio se sube después a `godot-studio-skills`.

## Arquitectura

Estándar. Escenas en `scenes/`. Sin `src/domain/`.

Autoload: `MpKit` antes que `SacrificeFlow`.

## Red

Online = dedicado. `host_dedicated()` en el proceso dedicado. Los clientes solo `join(ip)`. `play_solo()` no abre servidor. El host LAN no es el camino de internet.

Puntuación, textos y victoria viven fuera de `addons/mp_kit`.

## Datos

La instalación de Sacrifice se lee en local y el caché generado va a `game/cache/`, ignorado por git. No se commitean WAD, texturas ni modelos originales.

sacengine aporta los datos y los números del juego (mapa, paso medido, órdenes). En Godot el movimiento usa el motor: `CharacterBody3D`, `move_and_slide`, colisión y gravedad. No se reescribe un integrador ni un rayo de pies al lado de eso. El dedicado, cuando hay red, es quien mueve el cuerpo. El cliente manda la orden y pinta.

## Idioma

Textos de pantalla en español. Nombres de archivos y de nodos en inglés.

## IA

La IA es un jugador más. Todo lo que hace pasa por un solo puerto que llama a lo mismo que el humano (`request_cast`, `request_summon`, `Orders`): paga maná y almas y respeta enfriamientos y alcance. Sin bonificación de recursos ni trampa, en ninguna dificultad. Existe solo en el proceso que simula (solo o dedicado) y no agrega RPC. Vive fuera de `addons/mp_kit`. Las partidas con IA son reproducibles con `match_seed`.
