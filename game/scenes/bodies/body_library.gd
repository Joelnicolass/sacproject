extends Node

## Autoload facade over BodyCatalog, kept for the scripts that already call BodyLibrary.
## New code, and anything that runs in the editor, uses BodyCatalog directly.


func loads_meshes() -> bool:
	return BodyCatalog.loads_meshes()


func has_model(model: String) -> bool:
	return BodyCatalog.has_model(model)


func info(model: String) -> Dictionary:
	return BodyCatalog.info(model)


func models() -> PackedStringArray:
	return BodyCatalog.models()


func mesh(model: String) -> Mesh:
	return BodyCatalog.mesh(model)
