# debug/

Escenas y reglas solo de desarrollo: bancos, galerias, casos del `rules_suite` y partidas de prueba. Una carpeta por dominio del producto; `suite/` junta los casos del banco y `rules/` las `MatchRules` de prueba.
Esta carpeta no entra en el export (`export_presets.cfg` excluye `debug/*`); el modo `--world=res://debug/...` anda solo con el binario del editor.

Agregar uno: crear la escena en la carpeta de su dominio (instancia packed scenes y `.tres` del producto, sin tocar `scenes/`), y si es un caso del banco sumarlo a `suite/` y a `agent/det_cases.txt`. Nada suelto en la raiz de `debug/`.
