class_name AiDifficultyList
extends Resource

## The difficulties a room, a screen or a seat can name, in the order the menus list them
## (data/ai/difficulties.tres). A difficulty's id is its file name without `difficulty_`
## (difficulty_easy.tres → «easy»), the id the rooms already send. Adding one = a new
## difficulty_<id>.tres dragged into this list. It does not play nor change a difficulty.

const PATH := "res://data/ai/difficulties.tres"
const PREFIX := "difficulty_"

@export var difficulties: Array[AiDifficulty] = []


## The shared list (data/ai/difficulties.tres).
static func shared() -> AiDifficultyList:
	return load(PATH) as AiDifficultyList


## The id of a difficulty: its file name without the prefix («» for one that has no file).
static func id_of(difficulty: AiDifficulty) -> String:
	if difficulty == null or difficulty.resource_path.is_empty():
		return ""
	return difficulty.resource_path.get_file().get_basename().trim_prefix(PREFIX)


## The difficulty with that id; null for an empty or unknown one.
func find(id: String) -> AiDifficulty:
	if id.is_empty():
		return null
	for difficulty in difficulties:
		if id_of(difficulty) == id:
			return difficulty
	return null


## The ids in the order of the list.
func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for difficulty in difficulties:
		out.append(id_of(difficulty))
	return out
