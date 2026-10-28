# props

Decoration scenes (arch, rock, pillar) dragged into a map's `Props` node. No script, no health, no simulation role:
anything that must block units or be destroyed is a `MapBuilding` (`structures/buildings/`). The optional collision is
for physics only; the navmesh does not know it.
New prop: copy `persephone_arch.tscn` and change the `mesh` of `Mesh` to any `meshes/<tag>.res`.
