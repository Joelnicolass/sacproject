# scenes/ui/

What: la interfaz, una subcarpeta por pantalla o widget (`hud/`, `lobby/`, `character_select/`, `map_picker/`, `mode_picker/`, `biome_picker/`, `ai_picker/`, `local_server/`...).
Not: las reglas ni el cable de red. Un picker lista el catalogo y entrega el recurso elegido (`selected_map()`, `selected_mode()`, `selected_god()`); el id de red solo lo arma `MatchWire`.
Talks to: las pantallas llaman a `SacrificeFlow` (pick, jugar) y a `MpLobby` (salas); los pickers guardan el recurso como metadata de cada item y no leen ningun tag.
Edit: un dios, un mapa o un modo nuevo aparece solo en los pickers (su `.tres` o su carpeta); una pantalla nueva es una subcarpeta con su escena y su script.
Check: `debug/ui/team_screens_check.tscn` (F6 o headless con `--no-flow --room-test-maps`).

---
Interfaz por pantalla o widget: `hud/`, `spell_book/`, `character_select/`, `minimap/`, `radial/`, `lobby/`, etc. Una pantalla nueva es una subcarpeta con su escena y su script.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/suite/`.
