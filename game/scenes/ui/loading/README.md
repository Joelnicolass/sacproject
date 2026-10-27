# ui/loading

What: la pantalla negra mientras carga una partida (título, «Cargando el mundo» / «Preparando los gráficos», barra fina); se va con un fundido cuando el mundo avisa que está listo. Mientras se ve, el juego no recibe input (Esc no abre la pausa detrás).
Not: qué se carga ni cuándo arranca la partida (`MpWorldLoader` del flow, `MpMatchGate`); el precalentado (`scenes/look/warmup/`).
Talks to: `SacrificeFlow` (su padre) conecta `world_load_progressed` a `show_progress(ratio, phase)`; nada más. Corre con el árbol pausado (`PROCESS_MODE_ALWAYS`).
Edit: `scenes/core/flow/sacrifice_flow.tscn` → `LoadingScreen` (`fade_s`, claves de texto); colores y tamaños en `loading_screen.tscn`; textos `UI_LOADING_*` en `data/i18n/strings.csv`. Quitarla = borrar el nodo y vaciar `loading_screen` del flow; la carga sigue igual.
