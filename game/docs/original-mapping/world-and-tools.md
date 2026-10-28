# Original mapping: world, presentation and tools

Where the code of the world, look, effects, audio, UI, structures, tools and the project's own addons was checked against the
original Sacrifice (sacengine sources and data). The code says what it does; this table says what it was compared with.
Paths are relative to `game/`; line numbers are sacengine's.

## scenes/audio

| Game file · symbol | Original reference | Note |
|---|---|---|
| `ambience_set.gd` · `AmbienceSet.bed` | the original has no bed loop for every god | null bed is allowed |
| `combat_gauge.gd` · `CombatGauge.wizard_damage_s` | the original: 120 s after the wizard is hurt | default 120 |
| `command_voice.gd` · `CommandVoice.annoy_after` | sacengine lastSelected > 3 |  |
| `music_mood.gd` · `MusicMood` | the original's music rules | priority list in the class doc |
| `music_set.gd` · `MusicSet.crossfade_s` | the original: 0.5 s crossfade | default 0.5 |
| `music_set.gd` · `MusicSet.extras` | the original's God Realm theme | a track no mood plays; kept in menu.tres |
| `sound_cue.gd` · `SoundCue.max_distance_m` | the original: linear falloff to 200 m | default 200 |
| `sound_emitter_3d.gd` · `SoundEmitter3D` | the original's one-shots do not follow their node either |  |
| `sound_emitter_3d.gd` · `SoundEmitter3D._on_finished` | the original's loops are imported looping |  |
| `sound_event.gd` · `SoundEvent.ANNOYED` | the original's `Xann` sound |  |
| `sound_event.gd` · `SoundEvent.ATTACK_ACK` | the original's `Xcat` sound |  |
| `voice_queue.gd` · `VoiceQueue` | sacengine queueDialogSound, dialogPolicy |  |
| `wizard_sounds.gd` · `WizardSounds` | the chant repeats 0.1 s after a clip ends until the cast is over (state.d:14263-14270), never stopped (state.d:15207) |  |

## scenes/fx

| Game file · symbol | Original reference | Note |
|---|---|---|
| `beam_fx.gd` · `BeamFx` | sacengine Lightning renderer.d:1873-1905; end.center state.d:16372 |  |
| `beam_fx.gd` · `BeamFx._add_ribbon` | sacengine makeLineMesh, sacobject.d:2189-2227 |  |
| `beam_fx.gd` · `BeamFx._arc_point` | sacengine RainbowEffect |  |
| `beam_type.gd` · `BeamType` | sacengine state.d:2815-2850 (shape and timing), sacobject.d:2281-2295 (ltn2 atlas, 4×4 cells, 10 segments, fins of 0.3), renderer.d:264-272 (additive, energy 15), renderer.d:1877-1905 (pose, travel and brightness pulse) |  |
| `beam_type.gd` · `BeamType` | the original's lightning bolt shape |  |
| `beam_type.gd` · `BeamType.bolts` | sacengine `bolts[2]` |  |
| `beam_type.gd` · `BeamType.change_s` | sacengine changeShapeDelay 6 ticks |  |
| `beam_type.gd` · `BeamType.energy_min` | sacengine renderer.d:1881-1882 |  |
| `beam_type.gd` · `BeamType.energy_scale / Tether.energy_scale` | 1 = the original's brightness numbers |  |
| `beam_type.gd` · `BeamType.frame_s` | sacengine 2 ticks, getFrame(i / updateAnimFactor) |  |
| `beam_type.gd` · `BeamType.jitter_m` | sacengine changeShape size 2.5 |  |
| `beam_type.gd` · `BeamType.life_s` | sacengine Lightning.totalFrames 64 ticks |  |
| `beam_type.gd` · `BeamType.segments` | sacengine numLightningSegments |  |
| `beam_type.gd` · `BeamType.span_at` | sacengine renderer.d:1898-1903 |  |
| `beam_type.gd` · `BeamType.travel_s` | sacengine travelDelay 12 ticks |  |
| `beam_type.gd` · `BeamType.width_m` | sacengine makeLineMeshes size 0.3 |  |
| `fx_atlas.gd` · `FxAtlas.shader_for` | unshaded mix sprites like the original |  |
| `lightning_bolt.gd` · `LightningBolt` | port of sacengine LightningBolt, state.d:2816-2833; renderer.d:1879 |  |
| `lightning_bolt.gd` · `LightningBolt` | the original draws the bolt from the simulation's RNG (`state.uniform`); stores z as 10·k/n and scales by 0.1·length | here a generator of its own |
| `lightning_bolt.gd` · `LightningBolt.change_shape` | sacengine changeShape |  |
| `lightning_bolt.gd` · `LightningBolt.sample` | sacengine lintp |  |
| `order_marker.gd` · `OrderMarker` | sacengine CommandCone, sacobject.d:4483-4505, renderer.d:3690-3730, state.d:29261-29264 |  |
| `order_marker.gd` · `OrderMarker._mesh` | sacengine builds it along z |  |
| `order_marker.gd` · `OrderMarker.lifetime_s` | sacengine 0.5 |  |
| `order_marker.gd` · `OrderMarker.size_scale / color` | the original's 10 m by 0.7 m cone and its colors |  |
| `order_marker.tscn` · `OrderMarker` | sacengine CommandCone |  |
| `particle_type.gd` · `ParticleType.alpha_ramp` | sacengine getAlpha |  |
| `particle_type.gd` · `ParticleType.energy / lit` | the original's shadeless material; unshaded look of the original |  |
| `particle_type.gd` · `ParticleType.fade_s` | sacengine getAlpha |  |
| `particle_type.gd` · `ParticleType.frame_s` | delay * 2 / 60 in sacengine |  |
| `particle_type.gd` · `ParticleType.gravity` | sacengine uses 15 when gravity is on |  |
| `particle_type.gd` · `ParticleType.scale_curve` | sacengine getScale |  |
| `particle_type.gd` · `ParticleType.scale_fade_s` | sacengine getScale |  |
| `portal_disc.gd` · `PortalDisc` | sacengine SacVortex, renderer.d:1616-1677 |  |
| `portal_disc.gd` · `PortalDisc.close_s` | sacengine 1/45 per tick (state.d:2698): 0.75 s |  |
| `portal_disc.gd` · `PortalDisc.open_s` | sacengine vortexScale += 1/60 per tick (state.d:2697): 1 s |  |
| `portal_disc.gd` · `PortalDisc.radius` | the original flattens the disc (1.1 x 0.9) |  |
| `portal_look.gd` · `PortalLook` | sacengine SacVortex, sacobject.d:4045-4108, renderer.d:222-239 |  |
| `portal_look.gd` · `PortalLook.frame_s` | 2 ticks at 60 Hz, sacobject.d:4101-4105 |  |
| `portal_look.gd` · `PortalLook.inner_ratio` | sacengine sacobject.d:4079 |  |
| `portal_look.gd` · `PortalLook.rim_energy` | sacengine rim 10, center 1 (renderer.d:222-239) |  |
| `portal_look.gd` · `PortalLook.zigzag_repeats` | sacengine sacobject.d:4062-4093 |  |
| `quake_ring.gd` · `QuakeRing` | sacengine Quake.displacement (state.d:5187-5225: a crest that moves out at waveRange/waveDur with a width of |  |
| `quake_ring.gd` · `QuakeRing` | sacengine Quake.displacement (state.d:5187-5225): a crest that moves out at waveRange/waveDur with a width of (0.15 + 0.65·(1 − p)²)·waveRange |  |
| `side_colors.gd` · `SideColors` | sacengine player colors sids.d:9-16, Manalith column state.d:30104-30116, neutral side 31 |  |
| `spike_field.gd` · `SpikeField` | sacengine Spike state.d:3875-3885, updateSpike 20473-20478, placeSpike 25008-25015; drawn as renderer.d:2627-2638, SacSpike sacobject.d:2984-2994, makeSpikeMesh(32, 0.6, 0.75, 0.3, 0.25) |  |
| `spike_field.gd` · `SpikeField / spike_mesh` | sacengine placeSpike (skip off-land spikes); makeSpikeMesh(numV, texBase 0.6, base, baseRadius, topRadius), numU 2; radial UVs as the original |  |
| `spike_field.gd` · `SpikeField.lifetime_s` | sacengine Spike.lifetime, 2·60/3 updates |  |
| `spike_field.gd` · `SpikeField.play` | sacengine spikeHeight |  |
| `spike_field.gd` · `SpikeField.sides` | sacengine 32 |  |
| `spike_field.gd` · `SpikeField.tilt` | sacengine uniformDisk(…, 2.0) |  |
| `spike_field.tscn` · `SpikeField` | Spike, state.d:3875-3885; SacSpike, sacobject.d:2984-2994 |  |
| `sprite_emitter.gd` · `SpriteEmitter.set_tint` | sacengine manaEnergy |  |
| `sprite_emitter.gd` · `SpriteEmitter.tint` | the original tints Manalith smoke with the side color |  |
| `sprite_particles.gd` · `SpriteParticles` | sacengine getAlpha |  |
| `teleport_rings.gd` · `TeleportRings` | sacengine TeleportEffect / TeleportRing, state.d:16074-16101, renderer.d:1749-1756 |  |
| `teleport_rings.gd` · `TeleportRings.MESH_SIDE` | sacengine renderer.d:1754 |  |
| `teleport_rings.gd` · `TeleportRings.TICKS_PER_ATLAS_FRAME` | sacengine ringAnimationDelay * updateAnimFactor, sacobject.d:2149 |  |
| `teleport_rings.gd` · `TeleportRings.UP_STEPS` | sacengine state.d:16078-16091 |  |
| `teleport_rings.gd` · `TeleportRings.ring_height` | sacengine state.d:16074-16091 |  |
| `tether.gd` · `Tether` | sacengine SacDocTether state.d:15556-15613, spring state.d:15577-15600; mesh makeLineMeshes sacobject.d:2189-2227, 4446-4459; render renderer.d:1678-1703, pulse renderer.d:1688 |  |
| `tether.gd` · `Tether._curve` | sacengine cintp, util.d:562 |  |
| `tether.gd` · `Tether._targets` | sacengine getSacDocTetherTargetLocations, state.d:15556-15567 |  |
| `tether.gd` · `Tether.damping_per_s` | sacengine exp(log(0.25)/60) per tick |  |
| `tether.gd` · `Tether.elbow` | sacengine needleExpansion 1.5; state.d:15563 |  |
| `tether.gd` · `Tether.energy_min` | sacengine 0.375 + 14.625 * (...), renderer.d:1688-1690 |  |
| `tether.gd` · `Tether.frame_s` | 2 ticks of the original per atlas cell |  |
| `tether.gd` · `Tether.max_relative_speed` | sacengine state.d:15594 |  |
| `tether.gd` · `Tether.radius` | sacengine 0.3 |  |
| `tether.gd` · `Tether.segments` | sacengine 19 (renderer.d numSegments, sacobject.d:4446) |  |
| `tether.gd` · `Tether.spring_gain` | sacengine state.d:15580 |  |
| `wall_spike.tscn` · `WallSpike` | the original's spks sound (the Rhinok's is rspk) |  |

## scenes/look

| Game file · symbol | Original reference | Note |
|---|---|---|
| `ground/ground_role.gd` · `GroundRole.albedo / tile_m / detail_strength` | the original lights flat ground this way and paints one tile per 10 m map cell; grain strength 1 = the original's |  |
| `lights/actor_light.gd` · `ActorLight.enabled` | the original has no light pool under bodies; only the wizard carries a reveal light |  |
| `sky/sky_underside.gd` · `SkyUnderside` | sacobject.d:1101-1107 (undr quad 0.25 * 10240 m under the sky base, itself 511 m under the map's zero) |  |
| `stone_look.gd` · `StoneLook` | sacengine effects.stoneEffect = petrified \|\| skinOfStone, stats.d:91; dagon bone.d:189-192 |  |
| `stone_look.gd` · `StoneLook.apply_stone` | the original's bone shader grey for stone |  |
| `stone_look.gd` · `StoneLook.tint` | dagon bone.d:189-192 |  |
| `vegetation/vegetation_species.gd` · `VegetationSpecies.tag` | the original's plant tags (CAH1, PYA2...) | hashed by FloraPlacement |

## scenes/map

| Game file · symbol | Original reference | Note |
|---|---|---|
| `nav/path_follower.gd` · `PathFollower` | sacengine pops a node within sqrt(2)*5 m, state.d:607, and repaths every 2 s, state.d:593 |  |
| `nav/path_follower.gd` · `PathFollower.repath_s` | sacengine 2 s |  |
| `props/altar.gd` · `Altar` | sacengine updateAltarDestruction, state.d:25999-26062 |  |
| `props/altar_collapse.gd` · `AltarCollapse` | sacengine AltarDestruction disappearDuration, floatDuration, explodeDuration, state.d:5289-5291 |  |
| `props/altar_collapse.gd` · `AltarCollapse.duration_s` | sacengine state.d:5289-5291 |  |
| `props/altar_collapse.gd` · `AltarCollapse.duration_s` | the original's 4 + 4 + 3 s |  |
| `props/build_area.gd` · `BuildArea` | sacengine pushAll(position, 5, 15, 5) every frame of a structure cast, state.d:15259 |  |
| `props/mana_source.gd` · `ManaSource` | sacengine updateCreatureStats state.d:14409, canRegenerateMana |  |
| `side_relations.gd` · `SideRelations` | sacengine sids.d, Sides.getStance (state.d), stanceSettings |  |
| `side_relations.gd` · `SideRelations.set_rows` | sacengine multiplayerSide(i) |  |
| `terrain/falling_chunk.gd` · `FallingChunk` | sacengine updateFallingLandChunk (state.d:26094-26101) |  |
| `terrain/falling_chunk.gd` · `FallingChunk.gravity` | sacengine fallingLandChunkAcceleration |  |
| `terrain/falling_chunk_rules.gd` · `FallingChunkRules` | sacengine makeFallingLandChunkMesh (sacmap.d:388-480) |  |
| `terrain/falling_chunk_rules.gd` · `FallingChunkRules.SKIRT_M` | sacengine mapDepth |  |
| `terrain/ground_scar_rules.gd` · `GroundScarRules` | docs/archive/rfcs/research/061S-scar-ground-marks.md, sections 1.2, 2.1, 2.2 |  |
| `terrain/hole_rules.gd` · `HoleRules` | sacengine canRemoveLandVertex (state.d:28999-29026); the base is its checkGround (state.d:29013-29023) |  |
| `terrain/hole_rules.gd` · `HoleRules.DEPTH_BAND_M` | sacengine mapDepth |  |
| `terrain/hole_wall_rules.gd` · `HoleWallRules` | sacengine appendEdgeWall, dynamicEdgeMesh (sacmap.d:343-366, 780-813) |  |
| `terrain/hole_wall_rules.gd` · `HoleWallRules.DEPTH_M` | sacengine mapDepth |  |
| `terrain/pin_rules.gd` · `PinRules` | in the original a stamp also moves the land under an altar or a manafount | declared deviation: bases stay level |
| `terrain/stamp_carry.gd` · `StampCarry` | moveOnGround (state.d:14700); the immobilized ones only go up in the original (state.d:14657-14662) |  |
| `terrain/terrain_faces.gd` · `TerrainFaces` | hntr(), get_faces() and edge_wall_exists() of tools/import/sac_formats/terrain.py up to 22edea77 | faces parity PASS on the 7 original maps |
| `terrain/terrain_mesh_arrays.gd` · `TerrainMeshArrays` | sacmap.d generateNormals, appendEdgeWall |  |
| `terrain/terrain_rules.gd` · `TerrainRules` | sacmap.d getTriangles, isInside, getGroundHeight |  |
| `terrain/wall_uv_rules.gd` · `WallUvRules` | sacmap.d appendEdgeWall (780-813: the texture once down the 50 m wall, mirrored-repeat sampler, sacmap.d:204-205) |  |

## scenes/structures

| Game file · symbol | Original reference | Note |
|---|---|---|
| `breaking/structure_break.gd` · `StructureBreak` | sacengine updateBuildingDestruction and destructionAnimation (state.d:15157-15181, 27650-27660) |  |
| `reveal/build_edge.gd` · `BuildEdge` | state.d:15237-15244 (BlueRing: rings in the band of the cut, none in the last 0.5 s) |  |
| `reveal/build_reveal.gd` · `BuildReveal` | state.d:15231 (the line goes from 2 m under the base to the top over the casting time), buildingSummon.d:155, 465-470 |  |
| `structure_inspector.gd` · `StructureInspector` | sacengine mouse-over box, renderer.d:5036-5230 |  |
| `structure_inspector.gd` · `StructureInspector` | the original only has the mouse-over box | the health bar on click is a port extension |
| `towers/cast_tower.gd` · `CastTower` | sacengine makeBuilding(inactive \| cannotDamage) at the cast start, destroy on interrupt, activate on finish (state.d:10072-10083, 15259-15274) |  |
| `towers/tower_rules.gd` · `TowerRules.has_room` | sacengine spellStatus checks no bodies at all (state.d:29534-29573); the port keeps buildings out of the way |  |

## scenes/ui

| Game file · symbol | Original reference | Note |
|---|---|---|
| `command_cue/command_cue.gd` · `CommandCue` | renderer.d:4113-4165 renderCursor (4/32 of the icon below the cursor) |  |
| `command_cue/cursor_skin.gd` · `CursorSkin` | sacengine `cursor()` (state.d:30830); renderer.d:4113 renderCursor (32 units, ×1.2) |  |
| `command_cue/cursor_skin.gd` · `CursorSkin` | the original game's cursor set `C*` / `T*` of curs.FLDR |  |
| `command_cue/target_probe.gd` · `TargetProbe` | sacengine `cursor()` (state.d:30830) |  |
| `hover_frame/hover_frame.gd` · `HoverFrame` | renderer.d:3976-4021 (renderTargetFrame), dagonBackend.d:2890-2990 (mesh), colorHUD2.d (material) |  |
| `hover_frame/hover_frame.gd` · `HoverFrame / HoverFrameRules` | the original's target frame mesh: four wedges; the original adds no padding and frames buildings only with an icon waiting |  |
| `hover_frame/hover_frame_rules.gd` · `HoverFrameRules` | renderer.d:3976-4021 (renderTargetFrame), dagonBackend.d:2890-2990 (the frame mesh) |  |
| `hud/hud.gd` · `Hud` | the original's stats block in the top-right corner |  |
| `hud/hud.gd` · `hud.gd._fraction` | getRelativeHealth / getRelativeMana, renderer.d:4799-4806 |  |
| `minimap/minimap.gd` · `Minimap.compass` | sacengine minimapCompass |  |
| `minimap/minimap_markers.gd` · `MinimapMarkers` | as in the original: dead or hidden foes left out, souls in the viewer's color; allied vision shows what allies see |  |
| `minimap/minimap_markers.gd` · `minimap_markers` | sacengine minimap |  |
| `minimap/minimap_markers.gd` · `minimap_markers.gd._is_mine` | sacengine minimapVisibleToSide, renderer.d:4641-4643 |  |
| `minimap/minimap_style_set.gd` · `MinimapStyleSet.background_color / ground_tint` | the original: background 0, 65/255, 66/255; terrain drawn at 0.5 gray |  |
| `minimap/minimap_view.gd` · `MinimapView.lead_factor` | the original uses 3.73 |  |
| `radial/radial_layout.gd` · `RadialLayout.hold_s` | sacengine xmenuTime |  |
| `radial/radial_layout.gd` · `RadialLayout.hold_s` | 15 frames at 60 Hz in the original |  |
| `selection_roster/roster_cell.gd` · `RosterCell` | renderer.d:4400-4466 renderSelectionRoster (sizes ×1.2) |  |
| `selection_roster/roster_cell.gd` · `RosterCell.health_color` | sacobject.d:1155 healthColor |  |
| `selection_roster/roster_cell.gd` · `RosterCell.mana_color` | sacobject.d:1156 manaColor |  |
| `selection_roster/selection_roster.gd` · `SelectionRoster` | renderer.d:4400-4466 renderSelectionRoster (sizes ×1.2) |  |
| `spell_book/spell_book.gd` · `spell_book` | renderer.d:4872-4975 renderSpellbook (sizes ×1.2), dagonBackend.d:80,104 switchSpellbookTab, state.d:28104 spellbookVisible |  |
| `spell_book/spell_book.gd` · `spell_book.gd.show_tab` | sacengine switchSpellbookTab |  |
| `spell_book/spell_slot.gd` · `SpellSlot` | renderer.d:4912-4975 renderSpellbook |  |
| `spell_book/spell_slot.gd` · `SpellSlot.show_readiness` | sacengine |  |
| `target_info/target_info.gd` · `TargetInfo` | sacengine renderer.d:5036-5230 |  |
| `target_info/target_info.gd` · `TargetInfo / TargetInfoPanel` | the original's mouse-over info box, described not copied |  |
| `target_info/target_info_panel.gd` · `TargetInfoPanel` | renderer.d:66, 5036-5230 |  |
| `target_info/target_info_panel.gd` · `TargetInfoPanel.delay_s` | renderer.d:66 |  |
| `wizard_stats/wizard_stats.gd` · `WizardStats` | renderer.d:4770-4830 renderStats |  |

## tools/bake

| Game file · symbol | Original reference | Note |
|---|---|---|
| `bake_volcano_meshes.gd` · `bake_volcano_meshes` | sacengine makeVolcanoLavaMeshes, SacVolcanoSpatter.createMeshes (sacobject.d:3351-3399, 3510-3543) |  |
| `make_soul_wind_funnel.gd` · `make_soul_wind_funnel` | sacengine SacSoulWind.createMeshes (sacobject.d:2711-2750) |  |
| `make_stalk_tube.gd` · `make_stalk_tube` | sacengine makeMeanstalkMesh (sacobject.d:3566-3604) |  |
| `make_tornado_funnel.gd` · `make_tornado_funnel` | sacengine SacTornado.ensureMeshes (sacobject.d:3638-3688) |  |
