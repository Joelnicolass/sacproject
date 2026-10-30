# map/maps/_template

The starting point of every new map: «New map…» copies this folder to `maps/<tag>/`. Change `map.tscn` here to change
what every new map starts with. It has no `_template.tres`, so it is never listed as a map and is not exported.
Keep the `.import` of its 256² PNGs as they are (lossless, no mipmaps, `fix_alpha_border=false`).
