# scenes/

Codigo y escenas del producto, una carpeta por dominio (RFC-048). Cada dominio guarda sus `.gd`, `.tscn` y `.gdshader` juntos.
Los datos (`.tres` de tipos y catalogo) viven en `data/`, no aca.

Agregar algo nuevo:
- Si pertenece a un dominio que ya existe, va dentro de esa carpeta, junto a lo que lo usa.
- Si es un dominio nuevo, crear `scenes/<dominio>/` con su `README.md` y sumarlo a RULES.md (Arquitectura).
- Nada suelto en la raiz de `scenes/` (lo vigila `python3 tools/move_map.py tools/move_map/048.csv --lint`).
- El producto no nombra `res://debug`, `res://agent` ni `res://tools`.
