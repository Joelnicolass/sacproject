class_name OriginalAssets
extends RefCounted

## RFC-033: the one place that knows where the original's assets live under res://assets/original/.
## Only the importers in tools/ write there; the game only reads. Moving a family is a one-line change here.
## Consumers migrate one family at a time (033b: textures, via OriginalMaterial; 033c: props and sizes, via BodyCatalog).

const ROOT := "res://assets/original/"
const TEXTURES_DIR := ROOT + "textures/"
const PROPS_DIR := ROOT + "props/"
const MODELS_DIR := ROOT + "models/"
const UI_DIR := ROOT + "ui/"
const FX_DIR := ROOT + "fx/"
const THEMES_DIR := ROOT + "themes/"
const MAPS_DIR := ROOT + "maps/"
const DATA_DIR := ROOT + "data/"
const UI_ICONS_DIR := UI_DIR + "icons/"
const UI_HUD_DIR := UI_DIR + "hud/"
const UI_CURSORS_DIR := UI_DIR + "cursors/"
const UI_XMENU_DIR := UI_DIR + "xmenu/"
const FX_CATALOG := FX_DIR + "fx.json"


## A model's texture: textures/<model>/<label>.png (label like "001").
static func texture(model: String, label: String) -> String:
	return TEXTURES_DIR + "%s/%s.png" % [model, label]


static func textures(model: String) -> String:
	return TEXTURES_DIR + model + "/"


## textures/index.json: which texture each model's material label uses (see tools/import_textures.py).
static func texture_index() -> String:
	return TEXTURES_DIR + "index.json"


static func prop(name: String) -> String:
	return PROPS_DIR + name + ".glb"


static func model(name: String) -> String:
	return MODELS_DIR + name + ".glb"


## models/sizes.json: {"bodies": {...}, "props": {...}}, the measurements of every body and prop (tools/import_props.py).
static func sizes() -> String:
	return MODELS_DIR + "sizes.json"


## family: "icons", "hud", "cursors" or "xmenu".
static func ui(family: String, name: String) -> String:
	return UI_DIR + "%s/%s.png" % [family, name]


static func fx(tag: String) -> String:
	return FX_DIR + tag + ".png"


static func fx_catalog() -> String:
	return FX_CATALOG


## themes/<god>: the folder with a god's tileset, sky, sun and envi.tres.
static func theme_dir(god: String) -> String:
	return THEMES_DIR + god


## A theme file: themes/<god>/<name>.png (atlas, edge, sky, skyb, skyt, sun, undr).
static func theme(god: String, name: String) -> String:
	return THEMES_DIR + "%s/%s.png" % [god, name]


static func theme_envi(god: String) -> String:
	return THEMES_DIR + god + "/envi.tres"


## A map file: maps/<map>/<file> (terrain.res, tiles.png, light.png, ntts.json, widgets.json).
static func map(map_name: String, file: String) -> String:
	return MAPS_DIR + "%s/%s" % [map_name, file]


## A game data file: data/<name>.json (creatures, spells, abilities, wizards, books, buildings).
static func data(name: String) -> String:
	return DATA_DIR + name + ".json"
