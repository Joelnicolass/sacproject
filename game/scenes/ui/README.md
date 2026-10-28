# scenes/ui/

What: la interfaz, una subcarpeta por pantalla o widget (`hud/`, `character_select/`, `map_picker/`, `mode_picker/`, `biome_picker/`, `ai_picker/`, `local_server/`, `online/`...).
Not: las reglas ni el cable de red. Un picker lista el catalogo y entrega el recurso elegido (`selected_map()`, `selected_mode()`, `selected_god()`); el id de red solo lo arma `MatchWire`.
Talks to: las pantallas llaman a `SacrificeFlow` (pick, jugar) y, en `online/`, a `SacrificeFlow.host_online_room` / `join_online` / `online_rooms` (salas que hospedan los jugadores); los pickers guardan el recurso como metadata de cada item y no leen ningun tag.
Edit: un dios, un mapa o un modo nuevo aparece solo en los pickers (su `.tres` o su carpeta); una pantalla nueva es una subcarpeta con su escena y su script.

---
Interfaz por pantalla o widget: `hud/`, `spell_book/`, `character_select/`, `minimap/`, `radial/`, etc. Una pantalla nueva es una subcarpeta con su escena y su script.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`.
