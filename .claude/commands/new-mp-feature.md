---
description: "Scaffoldea un actor replicado de MpKit (script + escena) en el juego Godot."
---

Creá **una** feature multiplayer replicada en el **proyecto Godot del juego** (no en este repo de skills). Misma estructura que Project → Tools → MpKit: New replicated feature.

Si no hay `addons/mp_kit` en el juego, paramá y pedí instalar el addon.

1. Preguntá: id (`snake_case`), carpeta (`res://features` por defecto, o `src/features` si es Clean), root (`CharacterBody2D` / `CharacterBody3D` / `Node2D` / `Node3D`), si quiere `MpCustomPipe` (túnel Dictionary).
2. Creá `res://…/<id>/<id>.gd` y `<id>.tscn` con el mismo contenido que `MpFeatureScaffold` (submit_/apply_, MpReplicate, MultiplayerSynchronizer, pipe opcional). Preferí ejecutar el scaffold del addon si el usuario está en Godot; si no, escribí los archivos.
3. No pongas puntaje, copy ni loop de este título. `apply_action` queda vacío.
4. Recordá: registrar la escena en `MpSpawner` de la escena de match; LAN y dedicated usan el mismo feature; túnel = `send_custom` sin auto-broadcast.
5. Si el proyecto no tiene `.vscode/mpkit.code-snippets`, copiá `addons/mp_kit/editor/mpkit.code-snippets`.

Devolvé las rutas creadas.
