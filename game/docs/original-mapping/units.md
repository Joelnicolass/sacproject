# Original mapping: units, souls, sacrifice, wizards, bodies, gods

Where the code of `scenes/units/`, `scenes/souls/`, `scenes/sacrifice/`, `scenes/wizards/`, `scenes/bodies/` and `scenes/gods/` comes from in the original game (the sacengine port and the original executable). The code itself does not cite the original; look a class, a member or a scene (`editor_description`) up here.

Line numbers are of sacengine (`state.d` unless another file is named). «Note» says what the original does where this game differs.

| File | Symbol | Original reference | Note |
|---|---|---|---|
| `bodies/body_box.gd` | `BodyBox` | getFormationOffsets | — |
| `bodies/body_frame.gd` | `model_id` | — | the original calls the model id the «body» |
| `bodies/clip_facts.gd` | `seconds_at_30()` | sacengine animFPS. | — |
| `bodies/clip_playback.gd` | `frozen` | sacengine petrified, bone.d / state.d:11631-11640. | — |
| `bodies/hand_fx.gd` | `HandFx` | sacengine animateCasting (state.d:16165-16195). | — |
| `bodies/see_through_look.gd` | `SeeThroughLook` | sacengine shadelessBoneMaterialBackend (energy 1 -> ghostEnergy). | the original renderer (dagon) shadeless energy |
| `bodies/see_through_look.gd` | `ghost_alpha` | sacengine ghostAlpha / ghostEnergy. | — |
| `gods/book_unlock.gd` | `BookUnlock` | computeDefaultSpells | — |
| `gods/god_book.gd` | `up_to()` | sacengine `getSpells`, state.d:29512. | — |
| `sacrifice/carry_errand.gd` | `CarryErrand` | sacengine SacDocCarry; sacengine `soul.state.among(normal, emerging)`, state.d:15681; freeSoulImpl, state.d:15617 | — |
| `sacrifice/carry_rope.gd` | `CarryRope` | sacengine SacDocTether + needle sparks, state.d:15556-15613; the tip is bone 16 of `sacd` (sacobject.d:360-366). | — |
| `sacrifice/carry_rope.gd` | `spark_type` | sacengine 2 per tick (120/s). | — |
| `sacrifice/carry_rope.gd` | `spark_period_s` | — | the original emits 2 sparks per tick (120/s) |
| `sacrifice/doctor_body.gd` | `DoctorBody` | sacengine CRE8 `dcas`, model `sacd`. | — |
| `sacrifice/doctor_look.gd` | `DoctorLook` | sacengine animations.d (stab = attack, pumpCorpse = attack2, pickUpCorpse = attack3; torture has no clip: it uses the stab). | — |
| `sacrifice/doctor_motor.gd` | `DoctorMotor` | sacengine state.d:15480-15504 (the ground step), stats.d:104 (turn rate). | — |
| `sacrifice/doctor_motor.gd` | `turn_rate` | sacengine | — |
| `sacrifice/doctor_states/dropping.gd` | `dropping` | state.d:15480-15504 (launch), 14184-14190 and 14220-14224 (expelled, hitFloor). | — |
| `sacrifice/errand_states/approach.gd` | `approach` | sacengine SacDocCarry `walk`, state.d:15676-15722. | — |
| `sacrifice/errand_states/haul.gd` | `haul` | sacengine SacDocCarry `move`, state.d:15750-15790. | — |
| `sacrifice/errand_states/pump.gd` | `pump` | sacengine SacDocCarry `pump`, state.d:15725-15748; exe 0x44a0f0. | — |
| `sacrifice/errand_states/pump.gd` | `enter()` | sacengine convertRevive | — |
| `sacrifice/errand_states/pump.gd` | `_drop_soul()` | state.d:15668-15672 | — |
| `sacrifice/red_vortex.gd` | `RedVortex` | sacengine RedVortex, state.d:15463-15543 | — |
| `sacrifice/red_vortex.gd` | `drops_after` | state.d:15465: scale > 0.3 | — |
| `sacrifice/red_vortex.gd` | `drops_depth` | state.d:15471: -0.8 | — |
| `sacrifice/red_vortex.gd` | `pulse_s` | — | the original drops 2 per tick (120/s) |
| `sacrifice/ritual.gd` | `Ritual` | sacengine state.d:15854-16045. | — |
| `sacrifice/ritual.gd` | `abort()` | stopRitual, state.d:15817-15833 | the original throws the creature toward the start point |
| `sacrifice/ritual_drain.gd` | `RitualDrain` | sacengine state.d:15901-15903, 15997-16011. | — |
| `sacrifice/ritual_fx.gd` | `RitualFx` | sacengine RedVortex.desecrateDistance / desecrateHeight (state.d:15878-15889, 15961-15973), altarBolts / desecrateBolts end at the `center` of the creature and the wizard (renderer.d:1948-1958). | estimated: the original draws LightningBolts that change shape every 6-9 ticks |
| `sacrifice/ritual_lift.gd` | `RitualLift` | sacengine state.d:15928-15930. | — |
| `sacrifice/ritual_payoff.gd` | `RitualPayoff` | sacengine state.d:8341-8350, 16020-16041. | — |
| `sacrifice/ritual_push.gd` | `RitualPush` | sacengine pushAll, state.d:16046-16051, 8606-8628, 8623-8627. | — |
| `sacrifice/ritual_starter.gd` | `RitualStarter` | sacengine updateSacDocCasting / ritual start, state.d:15780, 15866. | — |
| `sacrifice/ritual_states/setup.gd` | `setup` | sacengine setupTime; state.d:2713 | — |
| `sacrifice/ritual_states/shoot.gd` | `shoot` | sacengine state.d:15975, 15997-16011, 16020-16042. | — |
| `sacrifice/ritual_states/walk.gd` | `walk` | sacengine ritualPositions, state.d:15854-15863, 15953-15972. | — |
| `sacrifice/ritual_type.gd` | `RitualType` | sacengine state.d:15817-16045. | — |
| `sacrifice/ritual_watch.gd` | `RitualWatch` | sacengine state.d:15921-15925. | — |
| `sacrifice/sacrifice_casts.gd` | `begin_cast()` | sacengine castDesecrate with closestEnemyAltar when the cast starts, state.d:10198-10213. | — |
| `sacrifice/sacrifice_casts.gd` | `begin_convert_cast()` | sacengine castConvert with closestShrine, state.d:10181-10196, 9907. | — |
| `sacrifice/sacrifice_casts.gd` | `cancel_cast()` | sacengine updateSacDocCasting `interrupted`, state.d:15526-15530. | — |
| `sacrifice/sacrifice_casts.gd` | `_cast_problem()` | sacengine updateSacDocCasting, state.d:15519-15545. | — |
| `sacrifice/sacrifice_casts.gd` | `_open_vortex()` | sacengine castDesecrate / castConvert, state.d:10162-10213; the doctor never comes out below the ground, state.d:15489. | — |
| `sacrifice/sacrifice_math.gd` | `drop_positions()` | sacengine findSacDocPositions; state.d:10162-10179, 10205; Convert, castConvert state.d:10190; as castDesecrate calls findSacDocPositions | the sign of the turn can be mirrored from the original because its z axis is up |
| `sacrifice/sacrifice_math.gd` | `ring_point()` | sacengine ritualPositions; state.d:15854-15863 | the original swaps the doctors' slots each round; the original's y axis is north and Godot's z is south, so the point is mirrored in z: the ring is the same set of four points |
| `sacrifice/sacrifice_math.gd` | `desecrate_health()` | state.d:16010 | — |
| `sacrifice/sacrifice_math.gd` | `desecrate_mana()` | state.d:16011 | — |
| `sacrifice/sacrifice_math.gd` | `convert_rounds()` | state.d:16027; maxHealth / 550 | — |
| `sacrifice/sacrifice_math.gd` | `pump_seconds()` | state.d:15697 | — |
| `sacrifice/sacrifice_math.gd` | `revive_health()` | convertRevive, state.d:8679 | — |
| `sacrifice/sacrifice_math.gd` | `SEARCH_STEPS` | findSacDocPositions | — |
| `sacrifice/sacrifice_spawns.gd` | `SacrificeSpawns` | sacengine sacDoc castings and ritual state, state.d:15489-15866. | — |
| `sacrifice/sacrifice_targets.gd` | `closest_enemy_altar()` | sacengine closestEnemyAltar, state.d:28083. | — |
| `sacrifice/sacrifice_targets.gd` | `altar_status()` | sacengine mustBeNearEnemyAltar, state.d:29562. | — |
| `sacrifice/sacrifice_targets.gd` | `closest_own_site()` | sacengine closestShrine, state.d:28060-28095. | — |
| `sacrifice/sacrifice_targets.gd` | `convert_arm_status()` | sacengine mustBeConnectedToConversion, state.d:29563. | — |
| `sacrifice/sacrifice_targets.gd` | `desecration_matches()` | sacengine desecrationOngoing, shiny.d:3079 over the `sacDocCastings`. | — |
| `sacrifice/stuck_guard.gd` | `StuckGuard` | — | not in the original, which pushes until the doctor dies or the target stops being valid |
| `souls/soul.gd` | `Soul` | sacengine Soul, state.d:1580, updateSoul 14904; sacengine devourSoul, severSoul, updateSoul: state.d:13138, 17925, 14991 | — |
| `souls/soul.gd` | `ANIM_FPS` | sacobject.d:1174; SacSoul.getMesh(color, frame/2) with frame at 30 fps | — |
| `souls/soul.gd` | `SPRITE_SIZE` | sacobject.d:1163; SacSoul soulWidth, soulHeight, soulRadius | — |
| `souls/soul.gd` | `SPRITE_LIFT` | renderer.d:1533 | — |
| `souls/soul.gd` | `attached` | sacengine creatureId != 0 | — |
| `souls/soul.gd` | `dropped` | sacengine `dropped` | — |
| `souls/soul.gd` | `devour_shrink_per_s` | state.d:14998 | — |
| `souls/soul.gd` | `vanish_depth_m` | soulVanishDepth = mapDepth (sacmap.d:108). | — |
| `souls/soul.gd` | `ring_turn_per_s` | sacengine | — |
| `souls/soul.gd` | `side()` | sacengine Soul.side | — |
| `souls/soul.gd` | `can_be_collected_by()` | state.d:14951 | — |
| `souls/soul.gd` | `can_convert_by()` | sacengine convertSideMask and spellStatus (no soul state check), state.d:1588, 10184, 29547, 30822. | — |
| `souls/soul.gd` | `is_free_or_own()` | isApplicable of Devour, state.d:30820-30825 | — |
| `souls/soul.gd` | `begin_devour()` | devourSoul, state.d:13138-13148 | — |
| `souls/soul.gd` | `sever()` | severSoul, state.d:17925-17935 | — |
| `souls/soul.gd` | `burst()` | updateRendShoot, state.d:25867-25890; severSoul | — |
| `souls/soul.gd` | `_settle()` | updateSoul (state.d:14912-14920), soulVanishDepth = mapDepth (sacmap.d:108). | — |
| `souls/soul.gd` | `_devour_step()` | state.d:14991-15006; updateSoul | — |
| `souls/soul.gd` | `fall_gravity` | — | the original comes down at a flat 1 m/s |
| `souls/soul.gd` | `energy` | — | the original uses 20 with its own tonemap |
| `souls/soul.gd` | `release_for()` | freeSoulImpl | — |
| `souls/soul.gd` | `reserve_for()` | castConvert clears the side's bit | — |
| `souls/soul_system.gd` | `SoulSystem` | sacengine spawnSoul when dying ends, state.d:14016; updateSoul, state.d:14925; dropSoul, state.d:9501 | — |
| `souls/soul_system.gd` | `Stance` | state.d:14926, CollectStance | — |
| `souls/soul_system.gd` | `drop_allowed()` | options.d:106; | — |
| `souls/soul_system.gd` | `drop_soul()` | sacengine dropSoul | — |
| `souls/soul_system.gd` | `_can_collect()` | canCollectSouls, state.d:243 | — |
| `souls/soul_system.gd` | `_spawn_free()` | sacengine gib, state.d:8341-8365 | — |
| `units/abilities/ability_effect.gd` | `AbilityEffect` | sacengine useAbility (state.d:13463-13561: the function each SpellTag calls), abilityStatus 29582-29604, apply 13467-13470. | — |
| `units/abilities/ability_effect.gd` | `windup_s` | sacengine startUsingAbility … shoot tick. | — |
| `units/abilities/ability_effect.gd` | `starts_cooldown` | state.d:12738-12739. | the original's pull returns before setting the cooldown |
| `units/abilities/ability_effect.gd` | `pays_upfront` | sacengine act, state.d:13495-13510. | — |
| `units/abilities/ability_port.gd` | `use()` | sacengine useAbility. | — |
| `units/abilities/ability_slot.gd` | `AbilitySlot` | sacengine abilityStatus (state.d:29582-29604) and useAbility (state.d:13463-13561). | — |
| `units/abilities/ability_slot.gd` | `MANA_EPSILON` | sacengine manaEpsilon (abilityStatus). | — |
| `units/abilities/ability_slot.gd` | `locked` | activeAbility, state.d:1414. | — |
| `units/abilities/ability_slot.gd` | `cost()` | abilityStatus, useAbility: state.d:29584, 13468. | — |
| `units/abilities/ability_slot.gd` | `start_cooldown()` | state.d:12746-12748. | — |
| `units/abilities/ability_windup.gd` | `AbilityWindup` | sacengine startUsingAbility, loadOnTick (state.d:12592-12605), act (state.d:13495-13510). Server (or solo) only. | — |
| `units/abilities/bovine_quake_wave.tscn` | `editor_description` | sacengine Quake with stunMaxRange 25 for ivob, state.d:25743 | — |
| `units/abilities/breath_of_life.gd` | `BreathOfLife` | Dragon filb, sacengine breathOfLifeShoot (state.d:13238-13248), updateBreathOfLife 25943-25975, animateBreathOfLifeHead. | the original's ray and particles are not ported |
| `units/abilities/breath_of_life.gd` | `_origin()` | sacengine shotPosition. | — |
| `units/abilities/breath_of_life.gd` | `_arrive()` | updateBreathOfLife | — |
| `units/abilities/breath_of_life.gd` | `arrive_speed` | updateBreathOfLife | — |
| `units/abilities/breath_of_life_ability.gd` | `BreathOfLifeAbility` | Dragon filb (flags targetSouls \| targetCorpses \| onlyAlly = 4106), sacengine useAbility → shoot (state.d:13470-13493), breathOfLifeShoot 13238-13248, 12746-12748, abilityStatus 29582-29604, 13241-13244, revive 8651-8664. | the original decides `onlyAlly` by side; here by slot |
| `units/abilities/breath_of_life_ability.gd` | `fire()` | breathOfLifeShoot; the original also spends the mana when nothing is launched | — |
| `units/abilities/cage_thread.tscn` | `editor_description` | renderer.d:1931-1946 (cagePulls) | — |
| `units/abilities/call_lightning.gd` | `CallLightning` | Storm Giant gsba, sacengine callLightning (state.d:13121-13129), lightning 10474-10491, dealDamage 8961. | the draws are in the original's axes (x, y, z up) |
| `units/abilities/call_lightning.gd` | `sky_lift` | sacengine adds (0, 0, 6). | — |
| `units/abilities/call_lightning.gd` | `fire()` | state.d:29106-29110, 13123. | — |
| `units/abilities/devour.gd` | `Devour` | Netherfiend crpd, Hellmouth nomd, Devour ifna (flags 4098), sacengine useAbility → shoot1 (state.d:13463-13561; PCes c36, DMes c46), devourSoul 12735-12736, 13138-13163, isApplicable/summarize 30820-30825, useAbilityDistance 12474, moveWithinRange2D 12526-12529. | the original walks closer and turns |
| `units/abilities/devour.gd` | `fire()` | devourSoul | — |
| `units/abilities/divine_sight.gd` | `DivineSight` | Ranger eesd, sacengine divineSight (state.d:13102-13109, called by useAbility 13527-13528), updateDivineSight 25161-25214. | the original plays no sound at the cast either |
| `units/abilities/divine_sight.gd` | `spawn_ahead` | sacengine `object.position + 2.0f * direction`. | — |
| `units/abilities/divine_sight_eye.gd` | `DivineSightEye` | Ranger eesd, sacengine DivineSight (state.d:5058-5067), updateDivineSight 25159-25214, SacDivineSight renderer.d:882-891 and 3517-3530, animationDelay, updateAnimFactor.; frontOfAIQueue: the original looks for the target only on the ticks its creature is at the front of the side's AI queue | the original does not divide the acceleration by the tick rate |
| `units/abilities/divine_sight_eye.gd` | `flying_height` | sacengine divineSightFlyingHeight. | — |
| `units/abilities/divine_sight_eye.gd` | `rising_s` | sacengine divineSightNumRisingFrames (45 ticks). | — |
| `units/abilities/divine_sight_eye.gd` | `refresh_s` | sacengine updateVision `refresh` = updateFPS / 2. | — |
| `units/abilities/divine_sight_eye.gd` | `target_groups` | sacengine. | — |
| `units/abilities/divine_sight_eye.gd` | `frames_h` | sacengine animationDelay, updateAnimFactor. | — |
| `units/abilities/divine_sight_eye.gd` | `_height()` | sacengine getHeight. | — |
| `units/abilities/divine_sight_eye.gd` | `_step()` | updateDivineSight | — |
| `units/abilities/divine_sight_eye.gd` | `_alive()` | isValidTarget(target, creature) | — |
| `units/abilities/fast_revive.gd` | `FastRevive` | sacengine revive(fast) (state.d:8651-8664), reviveTime 14101-14131.; reviveTime, reviveHeight | the original tumbles it down and calls newCreatureAddToSelection |
| `units/abilities/fast_revive.gd` | `revive_s` | creatureStats.reviveTime 5 s / 2 when fast. | — |
| `units/abilities/fast_revive.gd` | `rise_s` | reviveTime / 2 in the original's tick count (150 / 2). | — |
| `units/abilities/fast_revive.gd` | `rise_height` | creatureStats.reviveHeight | — |
| `units/abilities/firewalk.gd` | `Firewalk` | Warmonger wfhg (flags targetGround), sacengine useAbility → shoot!false (state.d:13470-13493), firewalk 13213-13217, 12746-12748, isOnGround, sacspell.d:208. | the original walks closer first |
| `units/abilities/firewalk.gd` | `range_factor` | sacengine SacSpell `if(tag==SpellTag.firewalk) range*=0.75f`. | — |
| `units/abilities/halo_of_earth.gd` | `HaloOfEarth` | Rhinok HRba, sacengine haloOfEarth (state.d:13232-13236), updateHaloOfEarth 19284-19321, canCarryHaloOfEarth 202-209, despawnHaloOfEarth 19272-19282, updateHaloRock 19212-19270, cintp2 util.d:554-560, closestNonAllyInRange 28825, haloRockExplosion 19076-19100, swap 19311-19313.; isCasting | the original's line of sight is a box |
| `units/abilities/halo_of_earth.gd` | `_rocks_due()` | REA HaloOfEarthRun | — |
| `units/abilities/halo_of_earth.gd` | `bury_depth` | haloRockBuryDepth | — |
| `units/abilities/halo_of_earth.gd` | `_can_carry()` | canCarryHaloOfEarth | — |
| `units/abilities/halo_of_earth.gd` | `_center()` | haloRockCenterPosition | — |
| `units/abilities/halo_of_earth.gd` | `_direction()` | state.uniformDirection | — |
| `units/abilities/halo_of_earth.gd` | `_cap()` | updateHaloRock capVelocity | — |
| `units/abilities/halo_of_earth.gd` | `_seek()` | updateHaloOfEarth, 19296-19316 | — |
| `units/abilities/halo_of_earth.gd` | `_despawn_free()` | despawnHaloOfEarth | — |
| `units/abilities/halo_of_earth.gd` | `_explode()` | haloRockExplosion | — |
| `units/abilities/halo_of_earth.gd` | `_hurt()` | dealSpellDamage(target, spell, …, DamageMod.none) | — |
| `units/abilities/halo_of_earth.gd` | `_valid()` | isValidTarget | — |
| `units/abilities/halo_of_earth.gd` | `_attackable()` | isValidAttackTarget | — |
| `units/abilities/halo_of_earth.gd` | `orbit_height` | HaloRock.centerHeight | — |
| `units/abilities/halo_of_earth.gd` | `_orbit_only()` | updateHaloRock with isCasting | — |
| `units/abilities/halo_of_earth.gd` | `_in_ball()` | state.uniformDisk (3D) | — |
| `units/abilities/halo_of_earth.gd` | `spawn_box_scale` | haloRockSpawnPosition | — |
| `units/abilities/halo_of_earth_ability.gd` | `HaloOfEarthAbility` | Rhinok HRba, sacengine haloOfEarth (state.d:13232-13236). | — |
| `units/abilities/life_shield_ability.gd` | `LifeShieldAbility` | hsba, sacengine lifeShield (state.d:13092-13100); Protector HSba. | — |
| `units/abilities/lightning_strike.gd` | `LightningStrike` | sacengine `lightning` (state.d:10474-10491, Lightning 2831-2840, updateLightning 16366-16386), updateTargets 10475-10484, dealSpellDamage 16380-16383, 28892-28899.; updateTargets = false | — |
| `units/abilities/lightning_strike.gd` | `travel_s` | Lightning.travelDelay (12 ticks). | — |
| `units/abilities/lightning_strike.gd` | `retarget` | updateTargets | — |
| `units/abilities/lightning_strike.gd` | `is_valid_target()` | isValidTarget | — |
| `units/abilities/lightning_strike.gd` | `_retarget()` | updateTargets | — |
| `units/abilities/lightning_strike.gd` | `hit_fx` | sparkAnimation, state.d:16376 | — |
| `units/abilities/lightning_strike.tscn` | `editor_description` | sacengine `lightning` | — |
| `units/abilities/lob_ability.gd` | `LobAbility` | Ikarus acia, Pyrodactyl kcfa, sacengine useAbility → shoot!true (state.d:13463-13493), stickyBombShoot / oilShoot 13179-13194, 12746-12748, getShotDirectionWithGravity 11506-11510, uniformDirection 29106-29111, predictShotTargetPosition, checkAbility 13451-13458, sacspell.d:123. | — |
| `units/abilities/lob_ability.gd` | `shots` | sacengine foreach(i;0..10) in stickyBombShoot. | — |
| `units/abilities/lob_ability.gd` | `spread` | sacengine 0.2·uniformDirection. | — |
| `units/abilities/lob_ability.gd` | `falling` | sacspell.d:123. | — |
| `units/abilities/lob_ability.gd` | `fire()` | getShotDirectionWithGravity | — |
| `units/abilities/lob_ability.gd` | `_uniform_direction()` | state.uniformDirection | — |
| `units/abilities/protector.gd` | `Protector` | Ent HSba, sacengine protector (state.d:13196-13202), lifeShield(hsba) 13092-13100, updateProtector 25698-25713. | — |
| `units/abilities/protector.gd` | `allies_delay_ticks` | sacengine. | — |
| `units/abilities/protector.gd` | `_valid()` | sacengine isValidTarget(creature). | — |
| `units/abilities/pull.gd` | `Pull` | Gremlin psla, Seraph psaa, `pull!(PullType.webPull \| cagePull)`, sacengine useAbility → shoot (state.d:13470-13493; LSs1 / SPs1), loadOnTick 12592-12605, 12738-12739, abilityStatus + isApplicable 29582-29604, sacspell.d:43-66, 171 (`tflags&shielded\|\|!tag.among(webPull, cagePull)`; flags 8197), pull 13166-13175. | — |
| `units/abilities/pull.gd` | `pull_speed` | sacengine Pull.pullSpeed. | — |
| `units/abilities/pull.gd` | `pull_s` | sacengine Pull.numPullFrames (25 ticks). | — |
| `units/abilities/pull.gd` | `stun_s` | sacengine stunCooldownFrames (480 ticks). | — |
| `units/abilities/pull.gd` | `min_thread` | sacengine Pull.minThreadLength. | — |
| `units/abilities/pull.gd` | `max_pulls` | sacengine. | — |
| `units/abilities/pull.gd` | `break_fx` | sacengine animateWebPullBreaking / animateCagePullBreaking. | — |
| `units/abilities/pull.gd` | `first_body_on_path()` | sacengine collideRay. | — |
| `units/abilities/pull.gd` | `loop_ticks()` | sacengine. | — |
| `units/abilities/pull.gd` | `is_live()` | sacengine isValidTarget + isValidAttackTarget. | — |
| `units/abilities/pull.gd` | `_origin()` | sacengine shotPosition. | — |
| `units/abilities/pull.gd` | `applicable()` | checkAbility | — |
| `units/abilities/pull_thread.gd` | `PullThread` | renderer.d webPulls 3551-3565, cagePulls 1931-1946, renderCord, changeShape 5126-5136. | — |
| `units/abilities/pull_thread.gd` | `grow_s` | sacengine Pull.numShootFrames. | — |
| `units/abilities/pull_thread.gd` | `reshape_s` | sacengine changeShapeDelay. | — |
| `units/abilities/pull_thread.gd` | `ramp_s` | sacengine boltScaleGrowth. | — |
| `units/abilities/pull_thread.gd` | `_origin()` | sacengine shotPosition. | — |
| `units/abilities/pull_thread.tscn` | `editor_description` | renderer.d:3551-3565 (webPulls) | — |
| `units/abilities/quake.gd` | `Quake` | Jabberocky kauq, sacengine useAbility → act (state.d:13495-13510; shoot0), quake 13204-13207. | — |
| `units/abilities/quake_wave.gd` | `QuakeWave` | sacengine Quake (state.d:5187-5225, displacement 5204-5222, part of Displacement 28929-28931), updateQuake (25737-25759), quake (13204-13207); effects before creatures (29331 against 29345).; canStun | — |
| `units/abilities/quake_wave.gd` | `wave_range` | sacengine Quake.waveRange, waveDur. | — |
| `units/abilities/quake_wave.gd` | `stun_min` | sacengine stunMinRange / stunMaxRange. | — |
| `units/abilities/quake_wave.gd` | `band` | sacengine. | — |
| `units/abilities/quake_wave.gd` | `cooldown_s` | sacengine stunCooldownFrames = 8·updateFPS. | — |
| `units/abilities/quake_wave.gd` | `life_s` | sacengine totalFrames = int(waveDur·updateFPS + 0.5). | — |
| `units/abilities/quake_wave.gd` | `groups` | sacengine movingObjects. | — |
| `units/abilities/quake_wave.gd` | `_stun()` | sacengine stunWithCooldown. | — |
| `units/abilities/quake_wave.gd` | `band_meters()` | waveDur·updateFPS | — |
| `units/abilities/quake_wave.gd` | `wave_at()` | waveLoc = waveRange·(float(frame)/updateFPS)/waveDur | — |
| `units/abilities/quake_wave.gd` | `_explode()` | quakeExplosion | — |
| `units/abilities/quake_wave.tscn` | `editor_description` | Quake, state.d:5187-5225 | — |
| `units/abilities/rend_soul.gd` | `RendSoul` | Styx dner, sacengine useAbility → shoot0 (state.d:13463-13561), rendShoot 12750, 13226-13230, canRend 13219-13225. | — |
| `units/abilities/rend_soul.gd` | `can_rend()` | canRend | — |
| `units/abilities/rend_soul.gd` | `fire()` | rendShoot | — |
| `units/abilities/rockform.gd` | `Rockform` | sacengine rockForm (state.d:13052-13065, 25040-25067), renderer.d:2084-2091. | — |
| `units/abilities/rockform.gd` | `rock_grow_s` | sacengine RockForm.numFrames at 60 fps. | — |
| `units/abilities/rockform.gd` | `emerge_fx` | — | the original only plays a sound here |
| `units/abilities/run_away.gd` | `RunAway` | !nur. | — |
| `units/abilities/viscous_oil.tscn` | `editor_description` | oilShoot, state.d:13189-13194 | — |
| `units/afflictions/affliction.gd` | `cc_ticks()` | sacengine Freeze 10701-10702, Grasping Vines 10806. | — |
| `units/afflictions/affliction_type.gd` | `holds` | sacengine stunned. | — |
| `units/afflictions/affliction_type.gd` | `hides` | sacengine mode firewalk, state.d:124, 135, 141. | — |
| `units/afflictions/affliction_type.gd` | `drops_fliers` | sacengine petrify startTumbling, state.d:11636. | — |
| `units/afflictions/affliction_type.gd` | `breaks_special_modes` | sacengine petrify sets mode = stunned, state.d:11631-11640. | — |
| `units/afflictions/affliction_type.gd` | `damage_factor` | state.d:8965; dealDamage's `!peirceShield` block, state.d:8962-8969. | — |
| `units/afflictions/affliction_type.gd` | `pins` | sacengine effects.fixed = vined, state.d:8588-8590, stats.d:94. | — |
| `units/afflictions/affliction_type.gd` | `blocks_regeneration` | sacengine regenerationBlocked: immobilized, rings of fire, slimed, vined, stats.d:73. | — |
| `units/afflictions/affliction_type.gd` | `cc_protects` | state.d:11631-11640. | — |
| `units/afflictions/affliction_type.gd` | `rages` | sacengine isBlindlyRaging, state.d:1143. | — |
| `units/afflictions/affliction_type.gd` | `cancels` | sacengine canStun refuses `stunned`. | — |
| `units/afflictions/afflictions.gd` | `wards` | stats.d:86-90 (shielded). | — |
| `units/afflictions/afflictions.gd` | `pins()` | sacengine effects.vined → fixed. | — |
| `units/afflictions/afflictions.gd` | `fixed()` | sacengine effects.fixed (state.d:8588-8590). | — |
| `units/afflictions/afflictions.gd` | `blocks_regeneration()` | sacengine regenerationBlocked (stats.d:83). | — |
| `units/afflictions/afflictions.gd` | `damage_factor()` | state.d:8965. | — |
| `units/afflictions/afflictions.gd` | `steer()` | sacengine CreatureMovement.tumbling. | — |
| `units/afflictions/afflictions.gd` | `admit()` | sacengine canStun state.d:8546-8553. | — |
| `units/afflictions/afflictions.tscn` | `editor_description` | — | the original uses alpha 0.2 for the ice block; energy 8 as the original |
| `units/afflictions/firewalking.gd` | `Firewalking` | sacengine updateFirewalk (state.d:25802-25846; target 141, obstacle 124, 135, damage 8922, immobilize 193; catapult 25838-25840), startIdling.; isOnGround | — |
| `units/afflictions/firewalking.gd` | `walk_s` | sacengine Firewalk.numFrames (60 ticks). | — |
| `units/afflictions/firewalking.gd` | `animated_distance` | sacengine Firewalk.animatedDistance. | — |
| `units/afflictions/firewalking.gd` | `trail_fx` | sacengine placeFirewalkParticles at warmongerFlame (state.d:25761-25783, sacobject.d:389). | — |
| `units/afflictions/firewalking.gd` | `burst_fx` | sacengine animateFirewalk. | — |
| `units/afflictions/firewalking.gd` | `walk()` | sacengine firewalk. | — |
| `units/afflictions/firewalking.gd` | `trail_every_s` | — | the original places 6 flames every tick |
| `units/afflictions/frozen.gd` | `Frozen` | sacengine frozen (rdba, zerf), tryFreezeWithCooldown state.d:10710-10725, stats.d:89, canCC 226-234, 13935, freeze 10693-10708, canBeFrozen 189-198, startTumbling, updateFreeze 17579-17614, dealRawDamage 9034-9037, dealSpellDamage(zerf). | the original sets the mode stunned over the tumble; the original shatters in the same frame when the Freeze effect updates after the hit; the exe loads `icec` for the spell |
| `units/afflictions/frozen.gd` | `max_cooldown_s` | sacengine maxFreezeCooldown = 10·updateFPS (state.d:10709). | — |
| `units/afflictions/frozen.gd` | `shards_fx` | sacengine ParticleType.shard, 17596-17609. | — |
| `units/afflictions/frozen.gd` | `_start_frame` | sacengine state.d:26445 and 27399. | — |
| `units/afflictions/frozen.gd` | `inflict()` | zerf. | — |
| `units/afflictions/frozen.gd` | `lay()` | sacengine castFreeze (state.d:10687-10708). | — |
| `units/afflictions/frozen.gd` | `try_freeze_with_cooldown()` | sacengine tryFreezeWithCooldown(wizard, side, target, spell). | — |
| `units/afflictions/frozen.gd` | `freeze()` | sacengine freeze(wizard, side, target, spell). | — |
| `units/afflictions/frozen.gd` | `lifetime_ticks()` | state.d:10701-10702. | — |
| `units/afflictions/frozen.gd` | `can_be_frozen()` | canBeFrozen = canBeImmobilized (state.d:189-198, 204). | — |
| `units/afflictions/frozen.gd` | `_can_cc()` | canCC (state.d:226-234). | — |
| `units/afflictions/frozen.gd` | `_roll()` | state.uniform(maxFreezeCooldown). | — |
| `units/afflictions/frozen.gd` | `_on_hit()` | dealRawDamage; sacengine unfreeze, state.d:9013. | — |
| `units/afflictions/frozen.gd` | `_shatter()` | dealSpellDamage, DamageMod.none. | — |
| `units/afflictions/frozen.gd` | `_end_by_time()` | updateFreeze | — |
| `units/afflictions/looks/affliction_emitter.gd` | `AfflictionEmitter` | sacengine slime splash and animateSlime (state.d:17730-17786). | — |
| `units/afflictions/looks/body_box_look.gd` | `BodyBoxLook` | sacengine Freeze (state.d:3037-3045, renderer.d:2183-2207). | — |
| `units/afflictions/looks/rings_look.gd` | `RingsLook` | sacengine animateRingsOfFire, updateRingsOfFire (state.d:17662-17704). | — |
| `units/afflictions/looks/vine_look.gd` | `VineLook` | sacengine GraspingVines (state.d:17825-17876, renderer.d:2232-2259). | — |
| `units/afflictions/oiled.gd` | `Oiled` | sacengine Oil (state.d:25653-25676), `creatureStats.effects.oiled / oilStatus`, updateOil, 13647-13649, canBeOiled = canBePoisoned, dealRawDamage 9028-9031, igniteOil 25639-25651, setAblaze(target, 60, false, 0), dealDamage 8961. | the original blasts two oiled bodies in the order of their Oil effects (creation order) |
| `units/afflictions/oiled.gd` | `blast_fx` | sacengine animateFireballExplosion, 25650. | — |
| `units/afflictions/oiled.gd` | `start()` | sacengine oilExplosion's callback + Oil. | — |
| `units/afflictions/oiled.gd` | `can_be_oiled()` | sacengine canBeOiled = canBePoisoned(mode). | — |
| `units/afflictions/oiled.gd` | `ignite()` | sacengine igniteOil 25632-25634. | — |
| `units/afflictions/oiled.gd` | `fire_fx` | setAblaze(…, updateFPS) | — |
| `units/afflictions/oiled.gd` | `_blast()` | igniteOil | — |
| `units/afflictions/petrified.gd` | `Petrified` | sacengine petrified, petrify state.d:11631-11645, stats.d:89, state.d:189-197, startTumbling, 8965, updatePetrification 23732-23764, damageStun. | — |
| `units/afflictions/petrified.gd` | `knock_cooldown_s` | sacengine damageStunCooldownFrames = 4·updateFPS. | — |
| `units/afflictions/petrified.gd` | `petrify()` | sacengine petrify(obj, lifetime). | — |
| `units/afflictions/petrified.gd` | `can_be_immobilized()` | canBeImmobilized = canBePetrified = canBeFrozen (state.d:189-198). | — |
| `units/afflictions/petrified.gd` | `_physics_process()` | updatePetrification (state.d:23758-23761). | — |
| `units/afflictions/petrified.gd` | `_burst_rocks()` | removePetrification (state.d:23740-23753). | — |
| `units/afflictions/petrified.gd` | `_shown()` | state.d:23759-23760. | — |
| `units/afflictions/pulling.gd` | `Pulling` | sacengine mode `pulling` (startPulling, state.d:10108-10113), updatePull 25434-25519.; numShootFrames; isValidAttackTarget; startIdling; checkAbility | the original's ray stops on a structure or soul and the pull ends at frame 20 |
| `units/afflictions/pulling.gd` | `SHOOT_FRAMES` | sacengine Pull.numShootFrames. | — |
| `units/afflictions/pulling.gd` | `OUTWARD_RADIUS_FACTOR` | sacengine updatePull 25462-25481, 25485. | — |
| `units/afflictions/pulling.gd` | `start()` | sacengine startPulling + the Pull effect. | — |
| `units/afflictions/pulling.gd` | `steer()` | sacengine. | — |
| `units/afflictions/pulling.gd` | `box_distance()` | sacengine boxPointDistance. | — |
| `units/afflictions/spell_affliction.gd` | `SpellAffliction` | sacengine ringsOfFire / updateRingsOfFire (state.d:10726-10742, 17687-17704), slime / updateSlime (10744-10764, 17765-17786), 1381-1383, 8950, 9237. | — |
| `units/afflictions/stunned.gd` | `Stunned` | sacengine stunned, stunWithCooldown state.d:8561-8568, canStun 8546-8553, 8138-8150, 14170-14212, fasterStandupTimes sacobject.d:844-874. | the original's faster-standup fix only swaps hitFloor, which a stun on the ground never plays |
| `units/afflictions/stunned.gd` | `FRAME_TICKS` | sacengine updateAnimFactor. | — |
| `units/afflictions/stunned.gd` | `fall_type` | state.d:14175-14212. | — |
| `units/afflictions/stunned.gd` | `stun_with_cooldown()` | sacengine stunWithCooldown. | — |
| `units/afflictions/stunned.gd` | `fall_down()` | sacengine state.d:14182-14212. | — |
| `units/afflictions/stunned.gd` | `knock()` | sacengine damageStun (state.d:23732-23739, 8569-8577). | — |
| `units/afflictions/stunned.gd` | `_body_allows()` | canStun (state.d:8546-8553). | — |
| `units/afflictions/stunned.gd` | `_measure()` | — | without knock or get_up the original creature stands in stance1 for one loop |
| `units/afflictions/stunned.gd` | `_from_fall` | hitFloor + getUp | — |
| `units/afflictions/tumbling.gd` | `Tumbling` | sacengine catapult + CreatureMovement.tumbling (state.d:8579-8599), steer 14781-14797, 14175-14197, dealFallDamage 9429-9438, 14176-14181.; antiGravityTime | the original's hybrid flier flies on at the top of the arc |
| `units/afflictions/tumbling.gd` | `falling_acceleration` | sacengine CreatureStats.fallingAcceleration (stats.d:142-144). | — |
| `units/afflictions/tumbling.gd` | `damp_xz` | sacengine dampFactorXY / dampFactorZ (state.d:14783-14784). | — |
| `units/afflictions/tumbling.gd` | `fall_damage_limit` | sacengine fallDamageLimit / fallDamageFactor (state.d:9430-9433). | — |
| `units/afflictions/tumbling.gd` | `velocity` | sacengine fallingVelocity. | — |
| `units/afflictions/tumbling.gd` | `attacker_slot` | sacengine tumbleAttackerSide. | — |
| `units/afflictions/tumbling.gd` | `drive()` | sacengine `fallingVelocity = v`. | — |
| `units/afflictions/tumbling.gd` | `catapult()` | sacengine catapult(side, velocity). | — |
| `units/afflictions/tumbling.gd` | `add_velocity()` | sacengine fallingVelocity += v, state.d:24024-24026. | — |
| `units/afflictions/tumbling.gd` | `lift()` | sacengine antiGravityTime = frame, state.d:23955. | — |
| `units/afflictions/tumbling.gd` | `shift()` | sacengine `position += v`, state.d:24663-24666. | the original's own «hack» |
| `units/afflictions/tumbling.gd` | `_body_allows()` | canCatapult (state.d:250-255, 8579-8584). | — |
| `units/afflictions/tumbling.gd` | `_physics_process()` | sacengine positionAfterCollision, state.d:14446-14564. | — |
| `units/afflictions/vined.gd` | `Vined` | sacengine graspingVines (eniv, passiveOnHit of grdg; state.d:10795-10812, isHitboxFlying 10799), updateGraspingVines 17852-17876, stats.d:73-94 (vined → regenerationBlocked, ccProtected, fixed), numVines, canPersistCC. | the original's xy position is the port's xz |
| `units/afflictions/vined.gd` | `lay_within()` | sacengine vinewallGraspingVines, state.d:20370-20383. | — |
| `units/afflictions/vined.gd` | `grasp()` | sacengine graspingVines(target, spell). | — |
| `units/afflictions/vined.gd` | `_physics_process()` | updateGraspingVines | — |
| `units/attacks/droplet_rain.gd` | `DropletRain` | sacengine updateAbominationDroplet state.d:24488-24505, 24481-24487, 24494, 24497-24498, collisionTarget 16442-16447 and 30033.; dealRangedDamage(target, amount, …, DamageMod.none); abominationDropletSize; isProjectileObstacle; collisionTarget's rank by stance | — |
| `units/attacks/freeze_touch.gd` | `FreezeTouch` | sacengine updateSilverbackProjectile state.d:24758-24831.; tryFreezeWithCooldown; toFreeze | — |
| `units/attacks/ground_hug_flight.gd` | `GroundHugFlight` | sacengine updateRhinokProjectile state.d:24963-24974, rhinokProjectileSize 24933, 24961-24978, spikes 25017-25022. | the range counts like the original's remainingDistance; the original flies on the ground |
| `units/attacks/ground_hug_flight.gd` | `spikes_per_tick` | movingSpikeRate | — |
| `units/attacks/ground_hug_flight.gd` | `spike_radius` | movingRange | — |
| `units/attacks/ground_hug_flight.tscn` | `editor_description` | updateRhinokProjectile phase moving, state.d:24963-24974 | — |
| `units/attacks/growing_wave.gd` | `GrowingWave` | sacengine updateSilverbackProjectile state.d:24758-24831, updateSpitfireProjectile 23025-23069, updateGargoyleProjectile 23079-23113.; damagedTargets; dealRangedDamage; dealDamageAt with the callback of the shooter | the original takes a body whose box holds the point on the first update |
| `units/attacks/growing_wave.gd` | `_touched` | damagedTargets | — |
| `units/attacks/ignite_touch.gd` | `IgniteTouch` | fhba, sacengine updateSpitfireProjectile state.d:23025-23069.; setAblaze(id, lifetime, true, 0.0f, …) | — |
| `units/attacks/ignite_touch.gd` | `fire_s` | sacengine updateFPS / 2. | — |
| `units/attacks/ignite_touch.gd` | `fire_damage` | — | the original sets it to 0 |
| `units/attacks/mite_hop.gd` | `MiteHop` | sacengine updateBlightMite state.d:25271-25340, closestCreatureInRange 25235-25260 and state.d:28778, 25311-25318, uniformDirection state.d:29106-29111.; isOnGround and getGroundHeight > position.z; closestCreatureInRange | the original skips the collision once the mite has stopped |
| `units/attacks/mite_hop.tscn` | `editor_description` | updateBlightMite, state.d:25271-25340 | — |
| `units/attacks/ranged_shot.gd` | `RangedShot` | sacengine updateEarthflingProjectile state.d:23178-23198, earthflingProjectileCollisionTarget 23145, earthflingProjectileExplosion 23152-23154.; earthflingProjectileCollisionTarget; earthflingProjectileExplosion; getShotDirection | — |
| `units/attacks/ranged_shot.gd` | `ground_height()` | sacengine getHeight. | — |
| `units/attacks/ranged_shot.gd` | `_can_hit()` | earthflingProjectileCollisionTarget / scarabProjectileCollisionTarget | — |
| `units/attacks/shot_aim.gd` | `ShotAim` | sacengine applyRangedAccuracy (state.d:11491), predictShotTargetPosition, getShotTargetPosition, hasClearShot (state.d:12460). | — |
| `units/attacks/shot_aim.gd` | `scatter()` | sacengine applyRangedAccuracy state.d:11491-11498. | the original's z-up axes map to Godot as z → Y, x → X |
| `units/attacks/shot_aim.gd` | `shot_position()` | sacengine shotPosition. | — |
| `units/attacks/shot_aim.gd` | `predicted()` | sacengine predictShotTargetPosition. | — |
| `units/attacks/shot_aim.gd` | `box_point()` | sacengine getShotTargetPosition. | — |
| `units/attacks/shot_aim.gd` | `clear_shot()` | sacengine hasClearShot. | — |
| `units/attacks/shot_dropper.gd` | `ShotDropper` | sacengine animateAbominationProjectile state.d:24441-24452, AbominationDroplet 4838-4845, 4844, 24481, 24491, updateAbominationProjectile 24454-24460. | — |
| `units/attacks/shot_dropper.gd` | `hit_size` | abominationDropletSize | — |
| `units/attacks/shot_impact.gd` | `ShotImpact` | sacengine earthflingProjectileExplosion.; earthflingProjectileExplosion | — |
| `units/attacks/shot_impact.gd` | `land()` | sacengine earthflingProjectileExplosion state.d:23152-23154, gnomeShoot dealRangedDamage 11731. | — |
| `units/attacks/shot_in_flight.gd` | `ShotInFlight` | sacengine animateAbominationProjectile state.d:24454-24460, updateSilverbackProjectile 24760-24831. | — |
| `units/attacks/shot_look.gd` | `hits_allies` | sacengine scarabProjectileCollisionTarget state.d:23637-23642.; scarabProjectileCollisionTarget | — |
| `units/attacks/shot_look.gd` | `hits_every_side` | sacengine state.d:25580-25586. | — |
| `units/attacks/shot_look.gd` | `hits_only_poisonable` | sacengine blightMiteCollisionTarget state.d:25262-25269.; blightMiteCollisionTarget | — |
| `units/attacks/shot_look.gd` | `ignites` | sacengine state.d:23247, 24521. | — |
| `units/attacks/shot_look.gd` | `sweep` | sacengine updateScarabProjectile state.d:23655-23664, lineOfSightWithoutSide 23863, 23992.; lineOfSightWithoutSide; lineOfSight in updateScarabProjectile; lineOfSightWithoutSide | — |
| `units/attacks/shot_look.gd` | `burst_at_range_end` | sacengine updateScarabProjectile state.d:23667-23670, 23866. | — |
| `units/attacks/shot_look.gd` | `in_flight` | sacengine animateAbominationProjectile state.d:24441-24452, updateSilverbackProjectile 24758-24831. | — |
| `units/attacks/shot_look.gd` | `volley` | sacengine boulderdashShoot state.d:11806-11808.; boulderdashShoot | — |
| `units/attacks/shot_look.gd` | `range_factor` | sacengine state.d:11799. | — |
| `units/attacks/split_flight.gd` | `SplitFlight` | sacengine boulderdashShoot state.d:11793-11813, 11794, updateBoulderdashProjectile 24729-24755, θ 24740. | the original turns around the shooter's «up»; the order of updateBoulderdashProjectile |
| `units/attacks/split_flight.gd` | `before_target_m` | boulderdashSplitDistance | — |
| `units/attacks/split_flight.gd` | `_step_m()` | distanceUntilSplit -= rangedAttack.speed/updateFPS | — |
| `units/attacks/split_flight.tscn` | `editor_description` | updateBoulderdashProjectile, state.d:24729-24755 | — |
| `units/attacks/wave_touch.gd` | `WaveTouch` | sacengine state.d:23035-23063. | — |
| `units/captive.gd` | `Captive` | sacengine state.d:15759-15766. | — |
| `units/captive.gd` | `revive()` | sacengine convertRevive state.d:8679. | — |
| `units/captive_look.gd` | `SEQUENCE` | sacengine state.d:8200-8223, 14329-14342. | — |
| `units/captive_ring.gd` | `CaptiveRing` | sacengine renderer.d:1638-1677. | — |
| `units/corpse.gd` | `Corpse` | sacengine dying -> dead, when the soul appears (state.d:14026). | — |
| `units/creature_fx.gd` | `CreatureFx` | sacengine manahoarManaOffset, state.d animateManahoar.; animateManahoar takes the rate addManahoar returns | the socket plays the original's manahoarManaOffset |
| `units/creature_type.gd` | `drain` | shiny.d:241 fillStats. | — |
| `units/creature_type.gd` | `is_hybrid_flier()` | sacengine sacobject.d:81-83, 113-115.; canFly && !mustFly | — |
| `units/creature_type.gd` | `model_id()` | — | the original calls the model id the «body» |
| `units/death_clouds/death_cloud.gd` | `DeathCloud` | sacengine kill state.d:8274-8278, state.d:25216-25254, 25674-25697. | — |
| `units/death_clouds/death_cloud.gd` | `dead` | sacengine state.d:25239.; dealDamageAt directTarget | — |
| `units/death_clouds/death_cloud.gd` | `GROUPS` | movingObjects | — |
| `units/death_clouds/death_cloud_spawner.gd` | `_center()` | sacengine boxCenter(hitbox). | — |
| `units/death_clouds/death_cloud_type.gd` | `DeathCloudType` | sacengine kill runs the clouds of passiveAbility / passiveAbility2 (state.d:8274-8278). | — |
| `units/death_clouds/healing_shower.gd` | `healing_shower` | sacengine updateHealingShower state.d:25674-25697, heal 10444-10458, 10446-10449, satAdd 10455, sacspell.d:211, updateHeal 16293-16310.; updateHeal; canHeal; satAdd; risH | — |
| `units/death_clouds/healing_shower.gd` | `HealingShower` | healSpeed 240 | — |
| `units/death_clouds/poison_cloud.gd` | `poison_cloud` | sacengine updatePoisonCloud state.d:25235-25254, 25241, 11610-11614. | — |
| `units/death_clouds/poison_cloud.gd` | `nerf_factor` | poisonNerfFactor | — |
| `units/death_clouds/poison_cloud.gd` | `PoisonCloud` | poison(obj, ability); poisonNerfFactor | — |
| `units/death_clouds/steam_cloud.gd` | `steam_cloud` | sacengine updateSteamCloud state.d:25216-25233, 9053-9056. | — |
| `units/death_clouds/steam_cloud.gd` | `SteamCloud` | dealSplashSpellDamageAt | — |
| `units/death_rules.gd` | `on_carrier_lost()` | sacengine frees a carried creature alive (state.d:15776-15779): dying on the drop is our own rule. | — |
| `units/gib.gd` | `Gib` | sacengine gib (state.d:8310-8364), the blood of gibAnimation. | — |
| `units/gib.gd` | `fall_into_hole()` | sacengine gib(state, -2) (state.d:8341-8365). | — |
| `units/impacts/bombard_impact.tscn` | `editor_description` | bombardProjectileExplosion, state.d:24518-24528 | — |
| `units/impacts/burn_impact.gd` | `BurnImpact` | Tickferno sfba (updateTickfernoProjectile state.d:23797-23810, setAblazeWithManaDrain), Pyromaniac lffa (updatePyromaniacRocket 24314-24321, setAblaze), Bombard cfba (bombardProjectileExplosion 24518-24528).; igniteBuilding is not ported | — |
| `units/impacts/burn_impact.gd` | `pierce_shield` | sacengine DamageMod.peirceShield. | — |
| `units/impacts/burn_impact.gd` | `fire_fx` | sacengine spawnFireParticles. | — |
| `units/impacts/direct_impact.gd` | `DirectImpact` | dealRangedDamage with DamageMod.none: Squall amba state.d:24001-24003, Vortick cita 23869-23873. | — |
| `units/impacts/disease_impact.tscn` | `editor_description` | updateNecrylProjectile, state.d:23515-23527 | — |
| `units/impacts/flummox_impact.tscn` | `editor_description` | flummoxProjectileExplosion, state.d:24059-24067; the callback stuns before the damage | — |
| `units/impacts/heal_impact.gd` | `HealImpact` | sacengine scarabProjectileHit (state.d:23609-23627, dealSplashSpellDamageAt(-1, …, effectRange)), slba sacspell.d:211, satAdd 10443-10458. | — |
| `units/impacts/heal_impact.gd` | `groups` | sacengine movingObjects. | — |
| `units/impacts/heat_ray_impact.tscn` | `editor_description` | updateTickfernoProjectile, state.d:23797-23810 | — |
| `units/impacts/implosion.gd` | `Implosion` | sacengine FlurryImplosion (state.d:4868-4876, updateFlurryImplosion 24619-24672), state.d:29331. | vz = 0 is the original's own «hack»; the original's axes (x, y, z up) are the port's (x, z, y up) |
| `units/impacts/implosion.gd` | `influence_speed` | sacengine FlurryImplosion.influenceSpeed. | — |
| `units/impacts/implosion.tscn` | `editor_description` | FlurryImplosion, state.d:4868-4876, 24619-24672 | — |
| `units/impacts/implosion_impact.gd` | `ImplosionImpact` | Flurry caba (flurryProjectileImplosion, state.d:24577-24598). | — |
| `units/impacts/implosion_impact.tscn` | `editor_description` | flurryProjectileImplosion, state.d:24577-24598 | — |
| `units/impacts/lob_splash_impact.tscn` | `editor_description` | flummoxProjectileExplosion, state.d:24059-24067: dealSplashRangedDamageAt(0, …, effectRange) | — |
| `units/impacts/oil_impact.gd` | `OilImpact` | Pyrodactyl kcfa, sacengine oilExplosion (state.d:25588-25612), dealDamageAt(0, 0.0, effectRange), canBeOiled.; state.d:25604 TODO (the scar on the ground) | — |
| `units/impacts/oil_impact.tscn` | `editor_description` | oilExplosion | — |
| `units/impacts/petrify_impact.gd` | `PetrifyImpact` | Basilisk dpsf, updateBasiliskProjectile (state.d:23686-23725), petrify 11641-11645. | — |
| `units/impacts/petrify_impact.gd` | `cap_s` | sacengine petrify. | — |
| `units/impacts/petrify_impact.tscn` | `editor_description` | updateBasiliskProjectile, state.d:23686-23725 | — |
| `units/impacts/poison_impact.gd` | `PoisonImpact` | Necryl cena, Deadeye lfda, Hellmouth mhba; updateNecrylProjectile (state.d:23515-23527), Deadeye 24332-24372, Hellmouth 24838-24900, healFromDrain CRE8 8834-8840, poison(target, ability, infectious, DamageMod.ranged) 11610-11614, dealPoisonDamage -> dealDamage 23585, 9415-9419, 8933-8947.; healFromDrain(shooter, amount), state.d:23523, 24360, 24879 | — |
| `units/impacts/poison_impact.gd` | `nerf_factor` | sacengine poisonNerfFactor (state.d:11610). | — |
| `units/impacts/poison_impact.gd` | `building_groups` | sacengine TargetType.building. | — |
| `units/impacts/poison_impact.gd` | `_affect()` | dealRangedDamage, 9369 | — |
| `units/impacts/push_impact.gd` | `PushImpact` | Squall amba (updateSquallProjectile, state.d:23996-24003), pushback 11677-11685, tumbleAttackerSide. | — |
| `units/impacts/push_impact.gd` | `groups` | sacengine movingObjects. | — |
| `units/impacts/push_impact.tscn` | `editor_description` | updateSquallProjectile, state.d:23996-24003 | — |
| `units/impacts/pushback.gd` | `Pushback` | sacengine Pushback (state.d:4768-4776, updatePushback 24017-24031), state.d:29331. | — |
| `units/impacts/pushback.gd` | `speed` | sacengine pushDistance / pushDuration. | — |
| `units/impacts/pushback.tscn` | `editor_description` | Pushback, state.d:4768-4776, 24017-24031 | — |
| `units/impacts/rend_blast_impact.tscn` | `editor_description` | updateRendShoot, state.d:25867-25890: dealSplashRangedDamageAt(0, …, damageRange 40) | — |
| `units/impacts/rocket_impact.tscn` | `editor_description` | updatePyromaniacRocket, state.d:24314-24321 | — |
| `units/impacts/spike_impact.gd` | `SpikeImpact` | Rhinok hrba, sacengine updateRhinokProjectile phase moving (state.d:24961-24983), dealRangedDamage DamageMod.splash, centerTarget, getHeight, state.d:8961. | the original applies its own friendly-fire rule there too |
| `units/impacts/spike_impact.tscn` | `editor_description` | updateRhinokProjectile phase moving, state.d:24961-24983 | — |
| `units/impacts/spike_wave.gd` | `SpikeWave` | sacengine RhinokProjectile phase spreading (state.d:4996-5025, updateRhinokProjectile 24942-25037), dealDamageAt callback 24985-25001, dealRangedDamage DamageMod.splash, state.d:29331, Spike effects 25023-25030, spreadingSpikeRate. | the original's axes (x, y, z up) are the port's (x, z, y up); the original's ally is by the stance of the sides |
| `units/impacts/spike_wave.gd` | `damage_at_s` | sacengine damageFrames (15−1, 30−1, 45−1, 60−1, 90−1 ticks). | — |
| `units/impacts/spike_wave.gd` | `strip` | sacengine stripSize. | — |
| `units/impacts/spike_wave.gd` | `min_radius` | sacengine minRadius. | — |
| `units/impacts/spike_wave.gd` | `max_height` | sacengine maxDamageHeight. | — |
| `units/impacts/spike_wave.gd` | `life_s` | sacengine numProjectileFrames (90 ticks). | — |
| `units/impacts/spike_wave.gd` | `spike_height` | sacengine placeSpike(…, 2.5). | — |
| `units/impacts/spike_wave.gd` | `intended` | sacengine intendedTarget, actualTarget. | — |
| `units/impacts/spike_wave.gd` | `begin()` | sacengine hitframe. | — |
| `units/impacts/spike_wave.gd` | `ring_bounds()` | sacengine. | — |
| `units/impacts/spike_wave.gd` | `_ring()` | dealDamageAt (state.d:24985-25001). | — |
| `units/impacts/spike_wave.gd` | `_excluded()` | sacengine. | — |
| `units/impacts/spike_wave.gd` | `spikes_per_m2` | — | the original keeps about 30 per update · 40 updates = 1200 standing on the circle at full radius |
| `units/impacts/spike_wave.gd` | `spike_life_s` | — | the original: 2/3 s, spawned all the time on the growing circle |
| `units/impacts/spike_wave.tscn` | `editor_description` | RhinokProjectile phase spreading, state.d:4996-5025, 24942-25037 | — |
| `units/impacts/splash_impact.gd` | `SplashImpact` | sacengine dealSplashRangedDamageAt (state.d:9400) = dealDamageAt with DamageMod.splash\|ranged, state.d:9055-9088, resistance 8952-8954, 9077, mutantProjectileExplosion 24381-24387, abominationProjectileExplosion 24432-24439, flummoxProjectileExplosion 24059-24067. | — |
| `units/impacts/stick_impact.gd` | `StickImpact` | Ikarus acia, sacengine updateStickyBomb (state.d:25531-25578), canBeStickyBombed = canBePoisoned 25524-25529, `++infectionTime <= updateFPS·duration`. | in the original the bomb flies through it |
| `units/impacts/stick_impact.gd` | `factor` | sacengine numStickyBombs, numBlightMites. | — |
| `units/impacts/stun_hit_impact.tscn` | `editor_description` | updateBrainiacProjectile 22886-22936, updateShrikeProjectile 22952-22989: stunWithCooldown, then goto dealRangedDamage | — |
| `units/impacts/stun_impact.gd` | `StunImpact` | sacengine flummoxProjectileExplosion (state.d:24059-24067), dealSplashRangedDamageAt, stunWithCooldown(target, 480), dealDamageAt 9075-9089.; stunWithCooldown, then goto dealRangedDamage | — |
| `units/impacts/stun_impact.gd` | `cooldown_s` | sacengine stunCooldownFrames = 8·updateFPS. | — |
| `units/impacts/stun_impact.gd` | `groups` | sacengine movingObjects. | — |
| `units/impacts/stun_impact.gd` | `target_only` | updateBrainiacProjectile 22924-22929, updateShrikeProjectile 22978-22983 | — |
| `units/impacts/vortex.gd` | `Vortex` | sacengine VortexEffect (state.d:4736-4751, updateVortexEffect 23922-23960), direction 23946-23949, vortexForceField 23891-23898, antiGravityTime, state.d:29331. | the original's axes (x, y, z up) are the port's (x, z, y up) |
| `units/impacts/vortex.gd` | `radius` | sacengine radiusFactor·effectRange. | — |
| `units/impacts/vortex.gd` | `height` | sacengine maxHeight. | — |
| `units/impacts/vortex.gd` | `field` | sacengine vortexForceField. | — |
| `units/impacts/vortex.gd` | `side` | sacengine tumbleAttackerSide. | — |
| `units/impacts/vortex.tscn` | `editor_description` | VortexEffect, state.d:4736-4751, 23922-23960 | — |
| `units/impacts/vortex_impact.gd` | `VortexImpact` | Vortick cita (updateVortickProjectile, state.d:23840-23879), spawnVortex 11663-11667, oldPosition. | — |
| `units/impacts/vortex_impact.tscn` | `editor_description` | updateVortickProjectile, state.d:23840-23879 | — |
| `units/movement/body_avoidance.gd` | `BodyAvoidance` | sacengine positionAfterCollision. | replaces the original's boxes and pushes |
| `units/movement/body_nudge.gd` | `BodyNudge` | sacengine push state.d:8604-8612. | — |
| `units/movement/body_nudge.gd` | `push_speed()` | sacengine pushAll, state.d:8614-8628. | — |
| `units/movement/body_nudge.gd` | `fixed()` | sacengine effects.fixed state.d:8588-8590. | — |
| `units/movement/fall_check.gd` | `FallCheck` | sacengine state.d:14800-14821.; gibDepth; moveOnGround | — |
| `units/movement/fall_check.gd` | `FALL_DEPTH` | sacengine state.d:14444, sacmap.d:108.; gibDepth = 0.5 * mapDepth | — |
| `units/movement/fall_check.gd` | `ALTAR_RETURN_DISTANCE` | sacengine state.d:2357.; wizardAltarDistance | — |
| `units/movement/fall_check.gd` | `altar_return_spot()` | sacengine getTeleportPosition state.d:10215. | — |
| `units/movement/flight.gd` | `Flight` | sacengine canFly && !mustFly, takeoff state.d:12335-12339, startFlying 8692-8704, sacobject.d:125-128, state.d:14141-14150, 14756-14763, 8113-8126, 14155-14160, land 8706-8716. | the original only lands with `land` (a debug key); stopped fliers hover down to height 0 and stay «flying» |
| `units/movement/flight.gd` | `flying_height` | sacengine CreatureStats.flyingHeight stats.d:154.; flyingHeight | — |
| `units/movement/flight.gd` | `downward_hover_speed` | sacengine stats.d:148.; downwardHoverSpeed | — |
| `units/movement/flight.gd` | `landing_speed_factor` | sacengine stats.d:145-147. | — |
| `units/movement/flight.gd` | `afflictions` | sacengine state.d:8138-8150, 14170-14212. | the original keeps creatureState.movement |
| `units/movement/flight.gd` | `goes_by_air()` | sacengine state.d:12298. | — |
| `units/movement/flight.gd` | `is_dropped()` | sacengine petrify startTumbling state.d:11636. | — |
| `units/passives/fire_shield.gd` | `FireShield` | sacengine runPhoenixPassive state.d:13899-13919, updateCreatureStats runPassive 13921-13931, canShield 218-225.; dealFireDamage(0, amount / 60, …, peirceShield); movingObjectById; passiveOnDamage, called every frame from updateCreatureStats; canShield; dealFireDamage(0, amount / 60, …, peirceShield); movingObjectById | — |
| `units/passives/fire_shield.gd` | `_can_shield()` | sacengine canShield state.d:218-225.; canShield | — |
| `units/passives/fire_shield.gd` | `box_scale` | scaleBox(object.hitbox, 1.5f) | — |
| `units/passives/life_drain.gd` | `LifeDrain` | sacengine healFromDrain state.d:8834-8840, dealDamage 8940, heal 8815-8817, 9193-9195, 9119-9141, 8933-8947, dealFireDamage 9421-9427.; healFromDrain; dealFireDamage; healFromDrain, called by dealDamage; dealDamage(building, …, attacker) → damageGuardians → the creature overload | — |
| `units/passives/life_shield.gd` | `LifeShield` | sacengine lifeShield (state.d:13092-13100), updateLifeShield removes it at frame 1200 (state.d:25122-25155). | — |
| `units/passives/lightning_charge.gd` | `LightningCharge` | sacengine dealRawDamage state.d:9017-9022, lightningCharge 13131-13136, updateLightningCharge 25342-25386, stats.d:122, state.d:8885, dealMeleeDamage 9237.; updateLightningCharge; movementSpeed; attackDamageFactor; dealMeleeDamage; passiveOnDamage | the original orders the candidates by proximity |
| `units/passives/lightning_charge.gd` | `spark_rate` | sacengine LightningCharge.sparkRate.; sparkRate | — |
| `units/passives/lightning_charge.gd` | `melee_factor()` | attackDamageFactor; dealMeleeDamage | — |
| `units/passives/lightning_charge.gd` | `add()` | lightningCharge | — |
| `units/passives/lightning_charge.gd` | `_simulate()` | updateLightningCharge | — |
| `units/passives/shield_bubble.tscn` | `editor_description` | sacengine draws the shield sphere scaled to the body box | — |
| `units/regeneration.gd` | `Regeneration` | sacengine isRegenerating (state.d:1428-1434), updateCreatureStats (state.d:14400-14403). | — |
| `units/special_forms.gd` | `SpecialForms` | sacengine rockForm (state.d:13052), the Fallen's Play Dead and the Sylph's Stealth. | — |
| `units/states/attack_state.gd` | `AttackState` | meleeAttacking | — |
| `units/states/cower_state.gd` | `CowerState` | sacengine cower state.d:8164-8171. | — |
| `units/states/idle_state.gd` | `IdleState` | sacengine patrol state.d:13029, state.d:7957-7992. | — |
| `units/states/rock_form_state.gd` | `ROCK_FORM_DAMAGE` | sacengine dealDamage state.d:8964. | — |
| `units/states/shoot_state.gd` | `ShootState` | sacengine shooting. | — |
| `units/states/summoning_state.gd` | `SummoningState` | sacengine preSpawning. | — |
| `units/states/summoning_state.gd` | `SUMMONING_ALPHA` | sacengine startCasting setAlpha. | — |
| `units/status/burning.gd` | `Burning` | sacengine Fire state.d:2578-2587, setAblaze 27670-27676, updateFire 15112-15130, 15117-15118, dealFireDamage 9421-9427, peirceShield 8962-8969, drainMana 8822-8825, Bombard fire 24521-24527, dealDamage 8940, refreshAblaze.; dealFireDamage; setAblaze / setAblazeWithManaDrain; updateFire; dealFireDamage -> dealDamage with the attacker | — |
| `units/status/burning.gd` | `fire_fx` | sacengine spawnFireParticles 15124-15127. | — |
| `units/status/burning.gd` | `mana_drain_per_tick` | manaDrainPerFrame | — |
| `units/status/burning.gd` | `ignite()` | setAblaze / setAblazeWithManaDrain | — |
| `units/status/clinging.gd` | `Clinging` | sacengine effects.numStickyBombs / numBlightMites stats.d:122, updateStickyBomb, canBeStickyBombed state.d:186.; updateStickyBomb: `++infectionTime <= updateFPS·duration`; canBeStickyBombed = canBePoisoned | numStickyBombs / numBlightMites in the original; the original keeps where each piece hit |
| `units/status/clinging.gd` | `poisoning` | canBePoisoned | — |
| `units/status/damage_over_time.gd` | `DamageOverTime` | sacengine updatePoison state.d:23582-23588. | — |
| `units/status/damage_over_time.gd` | `attacker_path` | sacengine poison 23585, 9415-9419, drain 8940. | the original's tick calls dealDamage with the attacker, which drains |
| `units/status/devour_growth.gd` | `DevourGrowth` | sacengine devourSoul state.d:13138-13163, bulk 13943-13948. | the original bulges bones |
| `units/status/devour_growth.gd` | `regeneration_over_s` | state.d:13138-13163 (increment / updateFPS). | — |
| `units/status/pace_factors.gd` | `PaceFactors` | sacengine movementSpeed effectFactor stats.d:122. | — |
| `units/status/poisoned.gd` | `Poisoned` | sacengine poison state.d:11601-11614, updatePoison 23535-23590, dealPoisonDamage 9415-9419, resistance 8950, regeneration 14403, numManaBlocks 23556-23558, giveMana 8829.; numManaBlocks | the original adds a Poison effect per dose; updatePoison deals poisonDamage/60 per frame through dealPoisonDamage, which always passes ignoreFriendly |
| `units/status/poisoned.gd` | `mana_block_frame` | manaBlockDelay | — |
| `units/status/poisoning.gd` | `Poisoning` | sacengine Effects stats.d:50-55, resistance state.d:8950-8957, poison 11604, restorePoisonRegeneration 26103-26112, giveMana 8829, 23556-23558, updatePoison 23537-23552.; updatePoison | the original checks infection only on the turn of its AI queue |
| `units/status/poisoning.gd` | `mana_block_s` | sacengine Poison.manaBlockDelay = 2·updateFPS. | — |
| `units/status/poisoning.gd` | `infection_margin_m` | sacengine updatePoison. | — |
| `units/status/poisoning.gd` | `infection_cooldown_extra_s` | sacengine infectionCooldown = lifetime + 3·updateFPS. | — |
| `units/status/poisoning.gd` | `dose_fx` | sacengine state.d:23565-23575. | — |
| `units/status/poisoning.gd` | `dose()` | sacengine poison state.d:11601-11607. | — |
| `units/status/poisoning.gd` | `can_be_poisoned()` | sacengine canBePoisoned state.d:177-184. | — |
| `units/status/poisoning.gd` | `groups` | movingObjects | — |
| `units/strikes/gnome_ray.tscn` | `editor_description` | gnomeShoot state.d:11724-11735; GnomeEffect | — |
| `units/strikes/locust_ray.tscn` | `editor_description` | locustShoot 11527-11531, updateLocustShoot 22992-23005, LocustProjectile 23007-23022 | — |
| `units/strikes/ray_strike.gd` | `RayStrike` | sacengine gnomeShoot state.d:11724-11735, WarmongerGun 11815-11819, 24121-24135, 11833-11850, collideRay. | — |
| `units/strikes/ray_strike.gd` | `beam_length` | sacengine sacobject.d:4268-4283.; GnomeEffect, createGunFlameMeshes | — |
| `units/strikes/ray_strike.gd` | `miss_fraction` | sacengine updateLocustShoot state.d:23003-23005. | — |
| `units/strikes/ray_strike.gd` | `_cast()` | — | the original's collideRay with `entry.id != attacker && isValidTarget` |
| `units/strikes/shot_strike.gd` | `ShotStrike` | sacengine gnomeShoot state.d:11724-11735, StyxShoot 11852-11855, 24154-24172, effects before creatures 29331 vs 29345. | — |
| `units/strikes/soul_strike.gd` | `SoulStrike` | sacengine updateRendShoot state.d:25867-25890.; dealSplashRangedDamageAt(0, …, damageRange); RendShoot, canRend; dealSplashRangedDamageAt(0, …, damageRange) | — |
| `units/strikes/soul_strike.tscn` | `editor_description` | updateRendShoot state.d:25867-25890 | — |
| `units/strikes/styx_strike.tscn` | `editor_description` | StyxShoot state.d:11852-11855, 24154-24172 | — |
| `units/strikes/target_strike.gd` | `TargetStrike` | sacengine updateStyxShoot state.d:24154-24172. | — |
| `units/strikes/target_strike.gd` | `beam` | sacengine updateStyxBolt state.d:24183-24195. | — |
| `units/strikes/warmonger_gun.tscn` | `editor_description` | WarmongerGun state.d:4893-4906, 24121-24135; warmongerShootSingle 11833-11850; the original only draws warmongerHit | — |
| `units/targeting/engagement.gd` | `Engagement` | sacengine updateTarget (state.d:12924), isValidAttackTarget (state.d:12442), isValidEnemyAttackTarget, startCowering (state.d:13760), teleport (state.d:10260-10269). | — |
| `units/targeting/engagement.gd` | `held_changed handler` | state.d:11631-11640 (petrify ends Rockform) | — |
| `units/targeting/engagement.gd` | `closest_foe()` | patrol, patrolAround, advance | — |
| `units/targeting/rage_policy.gd` | `RagePolicy` | sacengine updateTarget with isBlindlyRaging (state.d:12946-12948), closestCreatureInRangeExcept. | — |
| `units/targeting/target_futility.gd` | `TargetFutility` | — | not in the original |
| `units/targeting/target_picker.gd` | `TargetPicker` | sacengine updateTarget state.d:12924-12980, targetScore 12926-12933, visibleFilter 12936, scoreCutoff 12961-12963, maxTargetHeight 12879, 28774.; maxTargetHeight | the `within` anchor filter is not in the original; the original weighs passive bodies as any foe |
| `units/targeting/target_picker.gd` | `near_slope` | sacengine state.d:12927. | — |
| `units/targeting/target_picker.gd` | `far_factor` | sacengine state.d:12927. | — |
| `units/targeting/target_picker.gd` | `creature_weight` | sacengine state.d:12931. | — |
| `units/targeting/target_picker.gd` | `last_attacker_weight` | sacengine state.d:12932. | — |
| `units/targeting/target_picker.gd` | `current_weight` | sacengine state.d:12933. | — |
| `units/targeting/target_picker.gd` | `max_query_m` | sacengine state.d:12964. | — |
| `units/targeting/target_picker.gd` | `score()` | sacengine targetScore state.d:12925-12935. | — |
| `units/targeting/target_picker.gd` | `score_cutoff()` | sacengine scoreCutoff state.d:12961-12963. | — |
| `units/targeting/target_picker.gd` | `_max_target_height()` | sacengine maxTargetHeight state.d:12879. | — |
| `units/targeting/target_picker.gd` | `note_attacker()` | sacengine state.d:8905-8906. | — |
| `units/targeting/target_policy.gd` | `TargetPolicy` | sacengine's special cases of updateTarget (state.d:12940-12958). | — |
| `units/targeting/target_refresh.gd` | `TargetRefresh` | sacengine patrol state.d:13029, 13674.; patrol → updateTarget | — |
| `units/targeting/target_rules.gd` | `is_valid_foe_of()` | sacengine isVisibleToAI state.d:93.; sacengine isValidAttackTarget state.d:138.; sacengine isValidAttackTarget / canDamage state.d:12426-12432, 9091. | — |
| `units/targeting/target_rules.gd` | `is_passive()` | sacobject.d:84.; isPacifist | — |
| `units/targeting/wounded_ally_policy.gd` | `WoundedAllyPolicy` | sacengine updateTarget state.d:12949-12958, lowestHealthCreatureInRange 28828-28842, attack 12849-12855.; lowestHealthCreatureInRange | — |
| `units/targeting/wounded_ally_policy.gd` | `groups` | movingObjects | — |
| `units/targeting/wounded_ally_policy.gd` | `is_patient()` | canHeal | — |
| `units/tipping_fall.gd` | `TippingFall` | — | the original has no such fall |
| `units/unit_air.gd` | `cap_pace()` | sacengine speedInAir (state.d:14742-14751). | — |
| `units/unit_air.gd` | `flies_to()` | sacengine moveTowards state.d:12335-12339. | — |
| `units/unit_body.gd` | `UnitBody` | sacengine CreatureMode (state.d), patrol (state.d:13029). | — |
| `units/unit_body.gd` | `is_dead()` | sacengine isObstacle (state.d:112-126), canRegenerateMana (state.d:168): not while dead or still being summoned. | — |
| `units/unit_body.gd` | `soul_anchor()` | sacengine soulPosition. | — |
| `units/unit_health_bar.gd` | `UnitHealthBar` | sacengine draws your own creatures' bars only while they are selected (renderer.d:3890). | — |
| `units/unit_mana_support.gd` | `flame_rate()` | sacengine animateManahoar, addManahoar (state.d).; animateManahoar takes the rate addManahoar returns | — |
| `units/unit_orders.gd` | `unit_orders` | sacengine creatureAI.order, updateCreatureAI state.d:13684, patrolAround 13003, advance 13725.; updateCreatureAI; moveTo; patrolAround | — |
| `units/unit_orders.gd` | `guard_range` | sacobject.d:103 guardDistance. | — |
| `units/unit_orders.gd` | `retreat_distance` | sacengine retreatDistance state.d:13608. | — |
| `units/unit_orders.gd` | `arrive_distance` | sacengine moveTo state.d:12386.; moveTo | — |
| `units/unit_orders.gd` | `defer_repeat_think` | shiny.d orderIfChanged. | — |
| `units/unit_orders.gd` | `offset` | sacengine getTargetPosition state.d:391.; getTargetPosition | — |
| `units/unit_orders.gd` | `warped()` | sacengine teleport state.d:10260-10261. | — |
| `units/unit_orders.gd` | `_hold()` | sacengine patrolAround state.d:13007.; patrolAround, then moveTo / moveWithinRange | — |
| `units/unit_orders.gd` | `_acquire()` | sacengine patrolAround state.d:13007, advance 13039.; updateTarget as patrolAround and advance call it | — |
| `units/unit_orders.gd` | `_guardable()` | sacengine isValidGuardTarget state.d:145-151, guard 13016, retreat 13687. | — |
| `units/villager/grudge_memory.gd` | `GrudgeMemory` | sacengine grudgeMask state.d:8933-8936, absorbHerdGrudges 13634-13645. | — |
| `units/villager/grudge_memory.gd` | `herd_range` | sacengine state.d:13635.; absorbHerdGrudges | — |
| `units/villager/grudge_memory.gd` | `herd_interval_s` | — | the original absorbs every tick |
| `units/villager/grudge_memory.gd` | `mask` | — | the original uses the side |
| `units/villager/villager_brain.gd` | `VillagerBrain` | sacengine updateCreatureAI (state.d:13732-13760). | — |
| `units/villager/villager_brain.gd` | `think_interval_s` | — | the original decides on the turn of its AI queue |
| `units/villager/villager_brain.gd` | `flee_leg_m` | — | the original runs at a point mirrored through the enemy every tick |
| `units/villager/villager_brain.gd` | `work_when_calm` | — | «working the fields» is in the original's villager FSM with no rule decompiled |
| `units/villager/villager_senses.gd` | `VillagerSenses` | sacengine closestPeasantShelterInRange (state.d:28850), updateCreatureAI (state.d:13732-13760); the 50 m distances are sacengine's, which marks the rule «TODO: figure out the original rule»; the manual says the villagers flee near their village and cower outside it. | — |
| `units/villager/villager_senses.gd` | `shelter_distance` | shelterDistance | — |
| `units/villager/villager_senses.gd` | `scare_distance` | scareDistance | — |
| `units/villager/villager_senses.gd` | `closest_scare()` | closestEnemyInRange with the grudges | — |
| `units/vision/vision.gd` | `Vision` | sacengine markVisibleNTTs (state.d:12901), isVisibleToSide (state.d:29689). | — |
| `units/vision/vision_rules.gd` | `VisionRules` | sacengine markVisibleNTTs (state.d:12901) measures the flat distance to the center of each body. | — |
| `units/vision/vision_sides.gd` | `VisionSides` | sacengine isVisibleToSide / markAsVisible (state.d:29658-29693). | — |
| `units/weapons/melee_reach.gd` | `MeleeReach` | sacengine defaultMeleeHitbox (sacobject.d:446-476) and `attack` (state.d:12814, 12857-12862). | — |
| `units/weapons/melee_rules.gd` | `MeleeRules` | sacengine dealMeleeDamage (state.d:9231-9244) and the melee resistance of dealDamage (state.d:8951). | — |
| `units/weapons/melee_rules.gd` | `attack_factor()` | sacengine attackDamageFactor state.d:8882-8892. | — |
| `units/weapons/melee_swing.gd` | `MeleeSwing` | sacengine startMeleeAttacking (state.d:8725); an animation without attack events hits on its last frame (sacobject.d:420). | — |
| `units/weapons/melee_weapon.gd` | `MeleeWeapon` | sacengine `attack` (state.d:12814) and dealMeleeDamage (state.d:9231-9263). Server (or solo) only. | — |
| `units/weapons/melee_weapon.gd` | `start()` | sacengine startMeleeAttacking state.d:8725. | — |
| `units/weapons/melee_weapon.gd` | `advance()` | sacengine state.d:1381-1388.; slowdownFactor | — |
| `units/weapons/melee_weapon.gd` | `_land()` | sacengine state.d:8962-8969. | — |
| `units/weapons/ranged_aim.gd` | `RangedAim` | sacengine `attack` (state.d:12849-12855), `aim` (state.d:12521-12571), shootRange (state.d:12468). | — |
| `units/weapons/ranged_fire.gd` | `RangedFire` | sacengine getShotDirectionWithGravity (state.d:11506, 11548-11800), shootOnTick (state.d:12631-12758). | — |
| `units/weapons/ranged_fire.gd` | `FALLING_ACCELERATION` | sacspell.d:120. | — |
| `units/weapons/ranged_fire.gd` | `mana_cost()` | sacspell.d:194. | — |
| `units/weapons/ranged_fire.gd` | `tick()` | sacengine state.d:12774-12776. | — |
| `units/weapons/ranged_fire.gd` | `fire()` | sacengine boulderdashShoot state.d:11806-11808. | — |
| `units/weapons/ranged_fire.gd` | `BALLISTIC` | getShotDirectionWithGravity | — |
| `units/weapons/ranged_weapon.gd` | `RangedWeapon` | sacengine `attack`, `shoot`, `aim`, `shootOnTick` (state.d:12511-12855). Server (or solo) only. | — |
| `units/weapons/ranged_weapon.gd` | `advance()` | sacengine state.d:1405-1408.; hasShootTick | — |
| `units/weapons/ranged_weapon.gd` | `melee_distance` | rangedMeleeAttackDistance | — |
| `units/weapons/ranged_weapon.gd` | `clear_shot_drop` | hasClearShot | — |
| `wizards/ghost_form.gd` | `GhostForm` | sacengine state.d: dying 14000-14014, deadToGhost 14081, ghostToIdle 13959 and 14091, idleGhost/movingGhost, speed 1090, damage and target 8916 and 138, cast and souls 9520 and 243, mana heal 8827 and 14409, energy 14084 and 14094; renderer.d:1412; shadeless.d:114; renderShadowCastingEntities3D, renderer.d:5658-5661; sacengine ghostAlpha; sacengine ghostEnergy; sacengine updateFPS / updateAnimFactor; sacengine disappear(updateFPS); state.d:14010; albedo · 1, deferred.d:403; state.d:14009-14010; sacengine isValidAttackTarget / canDamage; sacengine isObstacle (state.d:120-126); sacengine isValidGuardTarget (state.d:145-151); sacengine isGhost; sacengine canCast; sacengine canRegenerateMana; state.d:168-175; sacengine canCollectSouls (state.d:243-249); sacengine spellbookVisible (state.d:28104); sacengine state.d:13959-13962 | — |
| `wizards/ghost_form.gd` | `_after_dying()` | sacengine; state.d:14004-14014; state.d:14009-14010 | — |
| `wizards/ghost_form.gd` | `_death_role()` | sacengine pickRandomAnimation(deathCandidatesOnGround) | — |
| `wizards/ghost_form.gd` | `_has_altar()` | sacengine hasAltar (state.d:13293) | — |
| `wizards/ghost_form.gd` | `_process()` | sacengine shadelessBoneMaterialBackend | — |
| `wizards/ghost_form.gd` | `_show_stage()` | deadToGhost, ghostToIdle | — |
| `wizards/ghost_form.gd` | `energy_scale` | — | the original renderer's (dagon) shadeless energy; π/14 is ambient_light_energy with ambient 1 |
| `wizards/wizard_body.gd` | `level_health_bonus` | makeWizard, state.d:2307-2311 | — |
| `wizards/wizard_body.gd` | `regen_pause_s` | sacengine; state.d:1429 | — |
| `wizards/wizard_body.gd` | `GESTURE_EVERY` | sacengine rolls 1 in 5 | — |
| `wizards/wizard_body.gd` | `is_obstacle()` | state.d:117, 125 | — |
| `wizards/wizard_body.gd` | `can_cast()` | sacengine canCast | — |
| `wizards/wizard_body.gd` | `warp_to()` | state.d:10262 | the original keeps the height over the ground |
| `wizards/wizard_body.gd` | `_regenerate()` | sacengine updateCreatureStats (state.d:14400-14403); isRegenerating, state.d:1429 | — |
| `wizards/wizard_body.gd` | `_return_to_altar()` | sacengine; state.d:14802-14815 | — |
| `wizards/wizard_body.gd` | `model` | — | the original calls the model id the «body» |
| `wizards/wizard_body.tscn` | `editor_description` | sacengine animateHealingAuraCasting | — |
| `wizards/wizard_drive.gd` | `WizardDrive` | state.d:93-145, 1140-1142. | — |
| `wizards/wizard_type.gd` | `vision_m` | — | a wizard has no sight range in the original data |
