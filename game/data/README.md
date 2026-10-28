# data/

Resources `.tres` (y `.res` horneados) del contenido: un archivo por tipo, ordenados por clase en `catalog/<tipo>/`, mas `gods/`, `look/`, `fx/`, `nav/`, `ui/`, etc.
Los scripts de esos Resources (`class_name`) viven en `scenes/<dominio>/`.

Las criaturas no están acá: cada una es su carpeta `res://creatures/<nombre>/`, con todo lo que usa solo ella.

Agregar un tipo: copiar el `.tres` de un hermano en la carpeta del tipo y editar el inspector; el catálogo lo levanta solo (`GameCatalog`). No se muta un `.tres` en runtime.

## Textos traducibles (`data/i18n/`)

`data/i18n/strings.csv` tiene las claves (`keys`), el español (`es`, idioma por defecto y de reserva) y una columna `en` vacía para quien traduzca. Los textos de pantalla van por clave: en una escena, `text = "UI_BOOT_SOLO"` (el Label/Button lo traduce solo); en código, `tr("UI_HUD_STATS_FORMAT") % [...]`, o `UiText.t(...)` donde no hay nodo. Para sumar un idioma: llenar su columna, reimportar y agregar `res://data/i18n/strings.<idioma>.translation` en Project Settings > Localization (Godot ignora una columna vacía, por eso hoy solo está `es`). Las razones de rechazo (`Refusal`, `&"no_mana"`) no son texto: son claves del protocolo que `CueSet` mapea a un ícono.
