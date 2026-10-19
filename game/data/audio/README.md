# data/audio/

Sets de sonido (RFC-052), un `.tres` por emisor. `SoundLibrary` los encuentra por convención, sin campos en el catálogo:

- `creatures/<tag>.tres`, `wizards/<tag>.tres`: `SoundSet` (evento -> `SoundCue`).
- `ui.tres`, `world.tres`, `advisor.tres`, `fx_sounds.tres`; `music/<dios>.tres`, `ambience/<dios>.tres` (cortes siguientes).

Lo de esta carpeta se versiona y gana. `data/audio/original/` lo hornea el importador del original desde `assets/original/audio/`; las dos carpetas están en `.gitignore` y pueden faltar: sin ellas el juego corre en silencio, sin errores.

Un sonido propio es un `.ogg` o `.wav` en `assets/custom/sounds/<kind>/<tag>/<event>[_n].{ogg,wav}` y un `SoundSet` acá que lo nombra (RFC-052 052i lo hornea solo).
