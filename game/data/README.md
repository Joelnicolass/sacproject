# data/

Resources `.tres` (y `.res` horneados) del contenido: un archivo por tipo, ordenados por clase en `catalog/<tipo>/`, mas `gods/`, `look/`, `fx/`, `nav/`, `ui/`, etc.
Los scripts de esos Resources (`class_name`) viven en `scenes/<dominio>/`.

Agregar un tipo: copiar el `.tres` de un hermano en la carpeta del tipo y editar el inspector; el catalogo lo levanta solo (`GameData`). No se muta un `.tres` en runtime.
