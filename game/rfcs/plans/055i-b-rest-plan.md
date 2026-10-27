# Plan 055i-b (resto): identidad por tag → recursos tipados

Tech lead, 2026-10-26. Estado: **aprobado** 2026-10-26. Orden: b4 + hoja de contacto de b5 ya; b1–b3 después de integrar 060s y 069; b5 --apply al final (tras 062-3) con la tabla de nombres aprobada por el usuario.

Datos que corrigen la auditoría: no son 69 edificios sino **72 nombres crudos + 2 abreviados + 10 torres `_<tag>`**; `ModelFiles` no tiene llamadores productivos (solo `tools/bake/new_creature.gd`, `debug/`, `agent/`).

## 0. Criterios
- C18 9 → 0, C18b 5 → 0; C12 y C15 −1 cada uno; nada sube.
- El mundo lee mapa y modo una vez: `MatchWorld` ← `ActiveMatch`, y lo pasa a sus sistemas. Se borran `MapCatalog.active/current_tag` y `GameModeCatalog.active/current_tag`.
- El mago tiene un solo dato de dios: `god_type: GodType` (se borra el texto replicado `god`).
- Bioma `GodType` de punta a punta (`MatchRules.biome`, `MatchBiome.god`, `BiomeRules`); el texto solo en el cable (`scenes/net/`).
- Edificios, torres y ruinas `<dios>_<qué es>[_n]`, reescritos con script re-ejecutable.
- Ningún modelo con nombre de tag; `ModelFiles` sale del producto.

## 1. Inventario
- C18: `side_relations.gd:44,90,92,191,193`; `match_world.gd:36,74`; `nav_service.gd:182-189` (fallback `NavigationRegion3D.new()` con `MapDefinition.nav`, el mismo `nav.res` que ya tiene cada `map.tscn`: dos dueños); `spellbook.gd:50` `GameData.god(wizard.god)` (el texto `god` replicado: `wizard_body.gd:46`, `wizard_body.tscn:104,169`, `hud.gd:68`).
- C18b: `biome_rules.gd:24`; `match_biome.gd:55,58,84,101`; `match_rules.gd:23` `biome_god`; `match_setup.gd:87` (Resource → texto → búsqueda); `sacrifice_room_rules.gd:102`.
- Edificios: 96 `data/buildings/*.tres` con su `scenes/structures/buildings/<mismo>.tscn` (+47 `_ruin.tscn`); `BuildingType.scene()` deriva la escena del nombre; sin uid en header; 26 con uso fuera de su par (torres: `match.tscn:26-28,177`, `data/gods/*.tres:36-39`).
- Modelos: `model_files.gd` + `models/model_files.tres` (71); `body_model.gd:36,77-98`; `FAmr*`, `peas*` y 12 `<tag>_clips`.

## 2. Árbol
```
scenes/map/side_relations.gd        [~] use(map: MapDefinition, mode: GameMode); sin refresh() ni tags
scenes/match/match_world.gd         [~] definition/mode leídos una vez de ActiveMatch; SideRelations.use(...)
scenes/map/nav/nav_service.gd       [~] sin fallback; `region` obligatorio
scenes/map/map_definition.gd        [~] sin `nav`; maps/*/<tag>.tres (9) sin nav; tools/import/scaffold_map.py
scenes/core/catalog/map_catalog.gd, game_mode_catalog.gd   [~] sin active()/current_tag()
tools/lint/conventions.sh           [~] C18 también cuenta `ActiveMatch.` fuera de core/net/ui/match_world
scenes/wizards/wizard_body.gd/.tscn [~] solo god_type (sale `god` del sincronizador)
scenes/spells/spellbook.gd          [~] book ?? god_type.book
scenes/ui/hud/hud.gd                [~] god_type.display_name
scenes/match/match_rules.gd         [~] @export biome: GodType (null = sorteo)
scenes/core/flow/match_setup.gd     [~] copy.biome = biome
scenes/match/biome_rules.gd         [~] pick/choose con GodType; fuera has_look
scenes/match/match_biome.gd         [~] var god: GodType; sorteo con GameCatalog.shared().gods; adopt(god); sin MpKit
scenes/net/biome_link.gd            [+] dueño del canal "biome" (envía god + MatchSky al mundo listo de cada cliente)
scenes/match/match.tscn             [~] nodo BiomeLink
scenes/net/sacrifice_room_rules.gd  [~] decode_god + .look != null
scenes/bodies/models/FAmr* → familiar_model*, peas* → peasant_model*   (rename_body_models.py; + 12 <tag>_clips)
scenes/bodies/model_files.gd + models/model_files.tres  → tools/bake/model_paths.gd (+ .tres)
scenes/bodies/body_model.gd         [~] sin FILES ni helpers
tools/migrate/055ib_building_names.csv  [+] old,new + evidencia + doubtful
data/buildings/*, scenes/structures/buildings/*  renombre (rename_resources.py --csv --apply)
debug/ y agent/                     lo mínimo para que pase rules_suite
```

## 3. Renombre de edificios
Regla `<dios>_<sustantivo>[_n]`; `tag` no cambia (id del cable). Seguras: torres → `<dios>_manalith`/`<dios>_shrine`, `persephone_altar`, `ether_altar`, `persephone_fountain`, `pyro_dynamo`, `pyro_magnifryer`, `persephone_hut`. Probables (`doubtful`): `<dios>_altar_2`, `charnel_hut_1/2`, `persephone_hut_2/3`, `stratos_hut`, `charnel_mausoleum`, `charnel_tree_n`, `ether_fountain`, `ether_statue_n`. Sin nombre (~40: `mar1..5`, `cpw1/jpw1/pcpw`, `ctc_`, `mard`, `prt_`, `pcwm`, `stst`, `eis*`, `ear*`, `esb*`, `sfc*`, `stc*`, `stt*`…): hoja de contacto con Blender CLI, nombres propuestos en el CSV, **aprobación del usuario** antes de `--apply`. `--apply` al final, después de 062-3.

## 4. Riesgos
`SideRelations` fuera de un mundo ve filas vacías (warning una vez; revisar los 28 llamadores). Sin `god` replicado, el cliente depende de `SacrificeFlow.pick_for(slot)` (verificar rejoin). Sorteo de bioma idéntico (misma lista y orden). Nombres dudosos necesitan OK. `ModelFiles` a `tools/` rompe usos de debug fuera de la suite (aceptable).

## 5. Sub-cortes
b1 puentes · b2 dios del mago · b3 bioma tipado + BiomeLink · b4 modelos · b5 edificios (CSV + hoja ahora; `--apply` al final).

## 6. Dueños frente a 062-3
055i-b: `match_biome.gd`, `biome_rules.gd`, `match_rules.biome`, `match_setup.gd`, `biome_link.gd`, nodos MatchBiome/BiomeLink. 062-3: `scenes/look/**`, `data/look/**`, material del terreno. Contrato congelado: `GodType.look`, `LookRig.apply_profile(profile)`, `MatchBiome.applied(god)`.
