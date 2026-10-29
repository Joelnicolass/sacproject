@tool
class_name PropScatterRun
extends RefCounted

## Runs every PropScatter3D and PropScatter2D under a scene, in tree order: the editor's
## Tools menu, and `scatter_scene.gd` from the command line.


## Scatters every PropScatter3D / PropScatter2D under `scene` (owned by `scene`); how many props.
static func run_all(scene: Node) -> int:
	# The scatters first: each scatter frees its old children, which a list of every node holds.
	var scatters: Array[Node] = []
	for node in scene.find_children("*", "", true, false):
		if node is PropScatter3D or node is PropScatter2D:
			scatters.append(node)
	var planted := 0
	for node in scatters:
		if not is_instance_valid(node):
			continue
		if node is PropScatter3D:
			planted += (node as PropScatter3D).scatter(scene)
		else:
			planted += (node as PropScatter2D).scatter(scene)
	return planted
