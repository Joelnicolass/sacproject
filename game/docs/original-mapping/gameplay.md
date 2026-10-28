# Original mapping: gameplay

Where the gameplay, AI, orders, match, core, network, camera and component scripts meet the original game.
The code describes what it does in plain words; the citations into the original sources (`sacengine`, `shiny.d`,
the executable through REA) live here. Paths are under `game/scenes/`. `RFC`/cut history is in git, not here.

| Game file | Symbol | Original reference | Note |
|---|---|---|---|
| `ai/ai_clock.gd` | `AiClock` | shiny.d:459-488 run, 468 periods, 469 force masks, 504-514 scheduler, 517-546 forceFlags | When each of the six jobs of an AI side runs |
| `ai/ai_side.gd` | `AiSide` | shiny.d:459-500 run; shiny.d:1129-1172 updateStatus, 1305-1346 updateReplan; shiny.d:575-584 botSpawned | One AI side |
| `ai/brains/ai_area_rating.gd` | `AiAreaRating` | shiny.d:2843-2847 f489860, 2742-2754 aoeSpellBase | How much an area spell is worth where it bursts, and how much of an own body its burst… |
| `ai/brains/ai_cast_queue.gd` | `AiCastQueue` | shiny.d:2638-2662 `enqueueCast`, 0x48ced0 + 0x48ce40; shiny.d:3333 | The queue of casts of a wizard |
| `ai/brains/ai_cast_queue.gd` | `AiCastQueue.make()` | shiny.d:2640 | obj0 == 0 falls back to the target. |
| `ai/brains/ai_line_of_fire.gd` | `AiLineOfFire` | executeBestCast's line of fire and sight, shiny.d:3246-3270. | Whether the AI's wizard has a clear shot at a body. |
| `ai/brains/ai_line_of_fire.gd` | `AiLineOfFire` | wrathCollisionTarget | What blocks the shot |
| `ai/brains/ai_spell_eval.gd` | `AiSpellEval` | shiny.d:2799-2923 rateSpellAcc, 2925-2951 findBestSpell, 2930-2934 | How the AI's wizard rates a spell on a target and picks the best of his book, from the… |
| `ai/brains/ai_spell_eval.gd` | `AiSpellEval.find_best()` | findBestSpell |  |
| `ai/brains/ai_spell_eval.gd` | `AiSpellEval.find_best()` | findBestSpell | The best spell against a target |
| `ai/brains/ai_spell_uses.gd` | `AiSpellUses` | shiny.d:2830-2842 f489780 (one foe), 2873-2884 f489af0 (Heal), 2893-2916 f489c40 (Speedup). | For each use a spell has for the AI (SpellType.ai_use, AiSpellEval.Rating), the… |
| `ai/brains/ai_spell_uses.gd` | `AiSpellUses.single()` | shiny.d:2830-2842 f489780 | A spell on one enemy body (a wizard, a creature or a structure) |
| `ai/brains/ai_spell_uses.gd` | `AiSpellUses.heal()` | hasActiveHeal |  |
| `ai/brains/ai_wizard_brain.gd` | `AiWizardBrain` | shiny.d:3303-3387 wizBrain, 3306-3326 the ghost, 3330-3337 souls, 3354-3382 the capture block, 3026-3050 pickGuardCreature, 3285-3301 castCachedInRange, 2610-2636 wizSpellRebuild. | The brain of the AI's wizard. |
| `ai/brains/ai_wizard_brain.gd` | `AiWizardBrain._pick_guard_creature()` | shiny.d:3026-3050 (0x485700), 3032 isGuardianEnt; sacengine tests the mode after picking | Of the own creatures (not the wizard) the one that weighs most (1 within… |
| `ai/brains/ai_wizard_brain.gd` | `AiWizardBrain._build_on_fount()` | shiny.d:3285-3301 (0x48dce0) | The Manalith spell, forced, when the wizard is within range * sqrt(build_range_slack)… |
| `ai/brains/ai_wizard_brain.gd` | `AiWizardBrain.think()` | wizBrain | named after the original function |
| `ai/brains/ai_wizard_brain.gd` | `AiWizardBrain.think()` | checkOnly |  |
| `ai/brains/ai_wizard_brain.gd` | `AiWizardBrain.rebuild_spells()` | wizSpellRebuild |  |
| `ai/brains/ai_wizard_brain.gd` | `AiWizardBrain` | closestEnemyAltar; canCastSpellOn onlyManafounts | Desecrate target and free founts |
| `ai/brains/ai_wizard_casting.gd` | `AiWizardCasting` | shiny.d:3201-3280 executeBestCast, 3174-3199 lightCanCast; shiny.d:3290 (0x48d080); shiny.d:3216-3224; shiny.d:3254-3270 line of fire, 3262. | How the AI's wizard casts what his phases queued |
| `ai/brains/ai_wizard_casting.gd` | `AiWizardCasting.enqueue_forced_execute()` | enqueueForcedExecute |  |
| `ai/brains/ai_wizard_casting.gd` | `AiWizardCasting.execute_best_cast()` | executeBestCast |  |
| `ai/brains/creature_brain.gd` | `CreatureBrain` | shiny.d:2557-2570 `t4oBrain`, 2546-2555 `autoCapture`. | The brain of a creature of the AI. |
| `ai/brains/creature_brain.gd` | `CreatureBrain.BUILDING_HOLD_M` | shiny.d:2518-2545 | A body that goes to refill holds this close to the source |
| `ai/brains/creature_brain.gd` | `CreatureBrain.think()` | shiny.d:2557-2570 | t4oBrain. |
| `ai/brains/creature_brain.gd` | `CreatureBrain.auto_capture()` | shiny.d:2546-2555, 0x487600 | autoCapture |
| `ai/brains/creature_brain.gd` | `CreatureBrain._min_mana()` | shiny.d:2498-2512 | nodeSlot22 |
| `ai/brains/creature_brain.gd` | `CreatureBrain.find_best_capture_target()` | shiny.d:2518-2545, 0x485a40 | findBestCaptureTarget |
| `ai/brains/creature_brain.gd` | `CreatureBrain` | autoCapture |  |
| `ai/brains/creature_brain.gd` | `CreatureBrain.auto_capture()` | autoCapture |  |
| `ai/brains/creature_brain.gd` | `CreatureBrain._min_mana()` | nodeSlot22 |  |
| `ai/brains/creature_brain.gd` | `CreatureBrain.find_best_capture_target()` | findBestCaptureTarget |  |
| `ai/brains/creature_brain.gd` | `CreatureBrain` | orderInteract; minManaCost; capture reach (1 - value6c) * 160 | Capture and refill |
| `ai/brains/manahoar_brain.gd` | `ManahoarBrain` | shiny.d:2572-2608 `mahoBrain`, 0x487ae0. | The brain of a Manahoar |
| `ai/brains/manahoar_brain.gd` | `ManahoarBrain.CUTOFF_M` | shiny.d:2581-2582 | Retail cutoff and scale |
| `ai/brains/phases/ai_phase.gd` | `AiPhase` | shiny.d:3333-3340. | A phase of the wizard's replan |
| `ai/brains/phases/ai_phase.gd` | `AiPhase.run()` | weightTriple |  |
| `ai/brains/phases/attack_phase.gd` | `AttackPhase` | wizAttack, shiny.d:3052-3071, 0x48d640 CheckAttack. | What the wizard attacks |
| `ai/brains/phases/convert_phase.gd` | `ConvertPhase` | wizRetreat, shiny.d:3088-3114, 0x48db60; their souls are red for both players, state.d:1621; shiny.d:3112 | The wizard converts the red souls he cannot take by touching them, the NPC of the… |
| `ai/brains/phases/convert_phase.gd` | `ConvertPhase` | the target obj 0 the original passes | Convert queues the soul as target and obj |
| `ai/brains/phases/summon_phase.gd` | `SummonPhase` | wizSacrifice, shiny.d:3115-3172, 0x48d8b0; shiny.d:3123-3137; shiny.d:3139-3171 | What the wizard summons. |
| `ai/brains/phases/summon_phase.gd` | `SummonPhase` | maxMana x Manaliths; rateWithBase | The summon pool and score |
| `ai/brains/phases/support_phase.gd` | `SupportPhase` | wizSupport, shiny.d:3073-3087, 0x48d7c0. | What the wizard helps |
| `ai/command/ai_command_port.gd` | `AiCommandPort` | shiny.d:3247-3254 startCasting. | The only way out of the AI into the game (RULES.md «IA») |
| `ai/command/ai_command_port.gd` | `AiCommandPort.start_casting()` | startCasting |  |
| `ai/command/ai_command_port.gd` | `AiCommandPort.AiOrder` | autoCapture | The refill order |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut` | shiny.d:2350-2391 issueOrder, 2393-2478 orderIfChanged and the radius orders. | The orders the AI gives its bodies. |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut.SAME_POS_SQ` | shiny.d:2398 | Two positions are «the same order» within this squared distance. |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut.order_interact()` | shiny.d:2452-2478, 0x487550 | orderInteract |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut._reason()` | sacengine re-issues it too | Why `t` gets this order now, for the diagnostic table, or "" when it is the order it… |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut._reason()` | shiny.d:2400-2409 | completed orders are retained |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut._has_live_order()` | the live order sacengine compares with, shiny.d:2398 | A unit with an order in progress, or a wizard walking. |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut._issue()` | sacengine order | The game refuses «advance» and «attack» to a pacifist (Orders._own_units) |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut._walk_wizard()` | AiTactics.wizard_stop_m; shiny.d:2376 `ntt+0x2e4 + 10.0` | The wizard walks |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut.order_if_changed()` | orderIfChanged |  |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut.order_target_radius()` | orderTargetRadius |  |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut.order_pos_radius()` | orderPosRadius |  |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut.order_interact()` | orderInteract |  |
| `ai/command/ai_orders_out.gd` | `AiOrdersOut._issue()` | issueOrder |  |
| `ai/data/ai_crowd_tactics.gd` | `AiCrowdTactics` | shiny.d:1702-1710 canAccept, 3419 and 3433 recordUpdate, 2376 retreat (state.d:13608 retreatDistance), 2552 autoCapture, 2565 orderInteract, 3026-3050 pickGuardCreature. | How the AI moves its creatures |
| `ai/data/ai_difficulty.gd` | `AiDifficulty` | shiny.d:380, 662. | How well the AI plays. |
| `ai/data/ai_difficulty.gd` | `AiDifficulty.aggression` | AiPlay.aggression; fixed 1.0 in the original, shiny.d:380 | How bold the side plays. |
| `ai/data/ai_senses.gd` | `AiSenses` | shiny.d:1044, 1053, 1065-1072, 1080, 1089, 1095 (16, 8, 32 and 8 ages of 6 ticks). | How often the AI looks again at what it already knows, in seconds at Normal pace |
| `ai/data/ai_tactics.gd` | `AiTactics` | shiny.d:3058 wizAttack, 3070-3072 target weights, 2928-2934 findBestSpell, 3115-3172 wizSacrifice, 3098 and 3113 wizRetreat, 3285-3301 castCachedInRange, 3366 Desecrate range, 3330-3337 souls, 3306-3326 ghost, 2376 wizard stop, 3328 and 3356 replan and re-issue. | How an AI wizard plays one difficulty, phase by phase, in seconds and meters |
| `ai/groups/ai_group.gd` | `AiGroup` | shiny.d:105-124 `AIGroup`, slot-4 groups. | A group of nearby bodies of one relation (AiTrack.Relation) |
| `ai/groups/ai_groups.gd` | `AiGroups` | shiny.d:1479-1580 slot-4 groups, 1563-1621 `groupRefresh4`, 1702-1760 `canAccept`/`formGroups4`; shiny.d:1711-1735, 1740-1778 | Groups of nearby bodies per relation (AiTrack.Relation). |
| `ai/groups/ai_groups.gd` | `AiGroups.rebuild()` | shiny.d:1305-1330 | recycleGroups + formGroups4 of every relation; the bodies come sorted by… |
| `ai/groups/ai_groups.gd` | `AiGroups.refresh()` | shiny.d:1300-1303 | updateGroups |
| `ai/groups/ai_groups.gd` | `AiGroups.refresh_group()` | shiny.d:1563-1621 | groupRefresh4. |
| `ai/groups/ai_groups.gd` | `AiGroups.refresh_group()` | shiny.d:1604-1620 | the aggregates of the slot-4 tail |
| `ai/groups/ai_groups.gd` | `AiGroups.souls_pair()` | shiny.d:1465-1474 | node vtbl[21] |
| `ai/groups/ai_groups.gd` | `AiGroups.refresh()` | updateGroups |  |
| `ai/groups/ai_groups.gd` | `AiGroups.refresh_group()` | groupRefresh4 | named after the original function |
| `ai/groups/ai_groups.gd` | `AiGroups` | recycleGroups + formGroups4 | Groups made again every replan |
| `ai/math/ai_field.gd` | `AiField.safediv()` | shiny.d:199-206 | safediv |
| `ai/math/ai_field.gd` | `AiField.lerp_w()` | shiny.d:2011 `lerp`, 0x48abe0 | lerp(a, w, b) = a + (b - a) * w. |
| `ai/math/ai_field.gd` | `AiField.ramp()` | shiny.d:2012-2040 probOr, 2042-2062 densityGroups, 2064-2082 influenceGroups | The linear falloff every scan uses |
| `ai/math/ai_field.gd` | `AiField.prob_or()` | shiny.d:2012-2022 | probOr |
| `ai/math/ai_field.gd` | `AiField.group_radius()` | shiny.d:1702-1710 canAccept | A group of `count` takes a body within group_radius_m * min(1 + group_growth * count,… |
| `ai/math/ai_field.gd` | `AiField.weight_triple()` | shiny.d:2953-2966, 0x48cc70 | weightTriple |
| `ai/math/ai_field.gd` | `AiField.attack_weight()` | shiny.d:3052-3071 (0x48d640) | The weight a foe has for the wizard's attack |
| `ai/math/ai_field.gd` | `AiField.attack_reach()` | retail coefficient 280, shiny.d:3055; 180 is the beta | `thr` of wizAttack |
| `ai/math/ai_field.gd` | `AiField.spell_cost_scaled()` | findBestSpell, shiny.d:2938-2943 | The score of a spell once the cost is paid out of the pool |
| `ai/math/ai_field.gd` | `AiField.summon_score()` | shiny.d:3155-3162 | wizSacrifice BLOCK2 |
| `ai/math/ai_field.gd` | `AiField.prob_or()` | probOr |  |
| `ai/math/ai_field.gd` | `AiField.weight_triple()` | weightTriple |  |
| `ai/math/ai_field.gd` | `AiField` | stanceRecs[3] u[6]; wizAttack thr; wizSacrifice BLOCK2 summon score | Weights, attack reach and summon score |
| `ai/math/ai_rand.gd` | `AiRand` | the `rand` of MSVC, shiny.d:31-38 `ShinyRand`; shiny.d:3123 | The random numbers of an AI side |
| `ai/math/ai_rand.gd` | `AiRand.state` | shiny.d:32 | `ShinyRand.state=1` in the engine. |
| `ai/math/ai_rand.gd` | `AiRand.next()` | shiny.d:34-37 | Next value of the sequence. |
| `ai/math/ai_rand.gd` | `AiRand.unit()` | shiny.d:3123 | `rand * 3.0518509447574615e-05f` |
| `ai/math/ai_rand.gd` | `AiRand` | wizSacrifice | The only user of the sequence |
| `ai/math/ai_rater.gd` | `AiRater` | shiny.d:109-130 (accumulator), 199-263 (rater1 formulas), 207-229 (combine, divide, rate, rateWithBase), 230-241 (`typeStats`). | How much a creature, a wizard or a group is worth to the AI, in five numbers |
| `ai/math/ai_rater.gd` | `AiRater.MILLI` | shiny.d:197-199: 0x4bb7a0, 1/980 (0x4bcde0), 0.04 (0x4bcdd8). | The scales of the rater |
| `ai/math/ai_rater.gd` | `AiRater.WIZARD_STATS` | thaum's wizd loader, shiny.d:235. | Every wizard is rated with these stats, whatever his file says. |
| `ai/math/ai_rater.gd` | `AiRater.ftol()` | MSVCRT _ftol, shiny.d:20-26. | Round to nearest, ties to even. |
| `ai/math/ai_rater.gd` | `AiRater.fill_stats()` | shiny.d:251-262 `fillStats`. | Ratings 0, 2, 3 and 4 from the stats. |
| `ai/math/ai_rater.gd` | `AiRater.ability_acc()` | shiny.d:243-249 `abilityAcc` (`amount2` is ai_worth, `unk10` the melee accuracy). | What one ability adds to rating 1 |
| `ai/math/ai_rater.gd` | `AiRater.fill_by_tag()` | shiny.d:265-281 `fillByTag`. | The worth of a creature a wizard may summon |
| `ai/math/ai_rater.gd` | `AiRater.fill_from_object()` | shiny.d:283-306 `fillFromObject`. | The worth of a body on the field, with its mana now |
| `ai/math/ai_rater.gd` | `AiRater.combine()` | shiny.d:207-209 `combine` (0x4891e0). | Mixes two ratings |
| `ai/math/ai_rater.gd` | `AiRater.divide()` | shiny.d:210-213 `divide`. | Divides elements 0..3 only; w = 0 does nothing. |
| `ai/math/ai_rater.gd` | `AiRater.rate()` | shiny.d:214-220 `rate` (0x488a60). | One number for a rating |
| `ai/math/ai_rater.gd` | `AiRater.rate_with_base()` | shiny.d:221-229 `rateWithBase` (0x4889e0). | What `a` is worth against `b`. |
| `ai/perception/ai_belief.gd` | `AiBelief` | shiny.d:1024-1038 updateBase, 1710-1711 and 2715-2722 healthPair (the original reads everything live). | What the AI believes of a body it knows |
| `ai/perception/ai_belief.gd` | `AiBelief.sees()` | shiny.d:583 | The side `side` sees `t` now |
| `ai/perception/ai_belief.gd` | `AiBelief.follow()` | shiny.d:1024-1038 updateBase (it follows own bodies and the ones flagged «seen», 1025) | Own and seen bodies follow the real position, `dt` ticks after the last run, while the… |
| `ai/perception/ai_body.gd` | `AiBody` | shiny.d:1458-1464 node vtbl[5] (mana pair), 2715-2722 healthPair. | The one place where the AI reads a body of the game |
| `ai/perception/ai_perception.gd` | `AiPerception` | shiny.d:1129-1200 scanGlobal (0x10, 1158), 575-584, 563-566, 1289-1300, 1373-1400, 975, 536; shiny.d:1243-1262 updateStats; 754-775 shouldTrack; 1651-1672 sortFam1; 3079-3085 desecrationOngoing, 3096 and 2264 wizardSacrificing, 3100 closestShrine, 3358 closestEnemyAltar. | The bodies one AI side knows and what each is to it (own, ally, neutral, enemy) |
| `ai/perception/ai_perception.gd` | `AiPerception.maho_ready()` | manahoarAbilityEnabled. | A Manahoar works while it is not dead, not being summoned and not held. |
| `ai/perception/ai_sight_intake.gd` | `AiSightIntake` | shiny.d:616-635 botSeen. | How what the side's Visions see reaches the AI. |
| `ai/perception/ai_souls.gd` | `AiSouls` | shiny.d:1358-1369 and 583 (souls ungated), 3005-3024 findBestNear (retail 0x485490). | The souls the AI may go for |
| `ai/perception/ai_track.gd` | `AiTrack` | shiny.d:78-132 `AINode`, 46 `NodeKind`, 748-753 relation and category, 884-1100 the status bits these booleans replace. | What the AI knows of one body |
| `ai/perception/ai_track.gd` | `AiTrack.Relation` | shiny.d:750-753 categoryFromFlags (0 own, 1 ally, 2 neutral, 3 enemy). | The side of the body as this AI sees it. |
| `ai/perception/ai_track.gd` | `AiTrack.seen` | shiny.d:1025 | Its side has seen it at some point |
| `ai/perception/ai_track.gd` | `AiTrack.acc` | the sort key, shiny.d:1432-1437 | AiRater accumulator (5 floats) and its cached `rate`. |
| `ai/perception/ai_track.gd` | `AiTrack.threat` | shiny.d:1061-1085 | Threat of a wizard. |
| `ai/perception/ai_track.gd` | `AiTrack.ord_state` | shiny.d:2393-2420 orderIfChanged | Last order given by the brain, its target track and position. |
| `ai/perception/ai_track.gd` | `AiTrack.summons` | wizSpellRebuild, shiny.d:2610 | Wizard only |
| `ai/perception/ai_track.gd` | `AiTrack.is_tower()` | capture_task.gd:64 at 51b17307. | A structure the side's army can take down |
| `ai/perception/ai_track.gd` | `AiTrack.is_guardian_bound()` | shiny.d:2995 isGuardianEnt | A creature bound to a building by the Guardian spell. |
| `ai/perception/ai_track.gd` | `AiTrack.sort_key()` | shiny.d:1432-1437 node vtbl[7] | The key groups and ratings sort by. |
| `ai/perception/ai_track.gd` | `AiTrack.value_6c()` | shiny.d:1439-1447 nodeValue6c | A wizard's threat, a structure's rate. |
| `ai/perception/ai_track_facts.gd` | `AiTrackFacts` | shiny.d:46 NodeKind, 884-1100 setupT4oBody/setupMaho/setupBldg, 926-931 the BLDG words of ; shiny.d:891-894; shiny.d:392-405 tagAcc; shiny.d:739-745 relation | What a body is for the AI, worked out once when the side takes it in |
| `ai/perception/ai_track_facts.gd` | `AiTrackFacts.setup()` | shiny.d:892-900 setupT4oBody, setupMaho. | The mana below which a creature with abilities goes to a source to recharge (the… |
| `ai/stance/ai_stance.gd` | `AiStance` | shiny.d:1220-1288 `updateStance`, 1061-1085 the threat of the wizard, 2064-2082 `influenceGroups`; shiny.d:1284-1287, «thaum quirk» | The numbers that sum up the field. |
| `ai/stance/ai_stance.gd` | `AiStance.update()` | shiny.d:1220-1288 | updateStance. |
| `ai/stance/ai_stance.gd` | `AiStance.update()` | shiny.d:1268-1280 | strengthRatio. |
| `ai/stance/ai_stance.gd` | `AiStance._bits()` | shiny.d:171 `si` | `cast(int)` of the raw word of a float |
| `ai/stance/ai_stance.gd` | `AiStance.enemy_ratio()` | shiny.d:2955 | Souls ratio own/(own+enemy) the weights use |
| `ai/stance/ai_stance.gd` | `AiStance.manalith_count()` | retail `GetManaSource`: own+ally, shiny.d:2926 / 3128 | Manaliths of the side plus its allies'. |
| `ai/stance/ai_stance.gd` | `AiStance.influence()` | shiny.d:2064-2082 | influenceGroups |
| `ai/stance/ai_stance.gd` | `AiStance.update_threat()` | shiny.d:1061-1085 | updateWiz |
| `ai/stance/ai_stance.gd` | `AiStance.update()` | updateStance | named after the original function |
| `ai/stance/ai_stance.gd` | `AiStance.update()` | strengthRatio | named after the original function |
| `ai/stance/ai_stance.gd` | `AiStance.influence()` | influenceGroups |  |
| `ai/stance/ai_stance.gd` | `AiStance.update_threat()` | updateWiz |  |
| `ai/stance/ai_stance.gd` | `AiStance` | stanceRecs[3] | Souls ratio the weights use |
| `ai/tasks/ai_record.gd` | `AiRecord` | shiny.d:134-157 `AIRecord`. | A claim of a task |
| `ai/tasks/ai_task.gd` | `AiTask` | shiny.d:98-104 `AITask`, 2096-2238 replan, 2240-2346 claim. | Contract of a task of the board. |
| `ai/tasks/ai_task.gd` | `AiTask.Kind` | shiny.d:98 TaskKind | FOCUS is not in the original. |
| `ai/tasks/ai_task.gd` | `AiTask.records` | the «claimed» list, shiny.d:1888-1900 | The records of the task, best score first. |
| `ai/tasks/ai_task.gd` | `AiTask.insert_sorted()` | shiny.d:1879-1886 | sortedInsert |
| `ai/tasks/ai_task.gd` | `AiTask.normalize()` | shiny.d:1888-1892 | normalizeScores. |
| `ai/tasks/ai_task.gd` | `AiTask.Kind` | taskCmd |  |
| `ai/tasks/ai_task.gd` | `AiTask.insert_sorted()` | sortedInsert |  |
| `ai/tasks/ai_task.gd` | `AiTask.normalize()` | normalizeScores | named after the original function |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard` | shiny.d:2096-2346 replan and claim, 2350-2440 the order bridge, 3380-3427 `recordUpdate`. | The board of tasks |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.replan_tasks()` | shiny.d:2096-2116 | replanTasks |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.claim_pass()` | shiny.d:2240-2260 | claimPass. |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.claimable()` | shiny.d:1475-1478 | ntt vtbl[19] |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.update_tasks()` | shiny.d:1402-1411 | updateTasks. |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.new_record()` | shiny.d:1938-1951 | recordSetup. |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.claim_member()` | shiny.d:1964-1977 | claim |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.distances_to_altars()` | probOr, shiny.d:2012-2022 | Distances from `from` to the altars of `relation`. |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.density()` | shiny.d:2042-2062 | densityGroups without the soul groups (slot 5) |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.density()` | shiny.d:2062 | Deviation |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard._refresh_record()` | shiny.d:1915-1952 | recordRefresh |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard._record_update()` | shiny.d:3408-3447 | recordUpdate. |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard._proximity_trigger()` | shiny.d:3389-3406 | proximityTrigger |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard._node_brain()` | shiny.d:2483-2491 | node vtbl[3] |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard._node_slot19()` | shiny.d:2471-2481 | node vtbl[19] |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.maho_brain` | mahoBrain |  |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.replan_tasks()` | replanTasks |  |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.claim_pass()` | claimPass | named after the original function |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.update_tasks()` | updateTasks | named after the original function |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard.new_record()` | recordSetup |  |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard._refresh_record()` | recordRefresh |  |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard._record_update()` | recordUpdate | named after the original function |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard._proximity_trigger()` | proximityTrigger |  |
| `ai/tasks/ai_task_board.gd` | `AiTaskBoard` | densityGroups | Density without the soul groups |
| `ai/tasks/capture_task.gd` | `CaptureTask` | shiny.d:2118-2194 `replanCapture`, 2262-2286 `claimCapture`, retail 0x48dc04..0x48e21b; flags 0x10, status 8; shiny.d:2152-2157; guardian excluded here too, shiny.d:2272 | What the side wants to take. |
| `ai/tasks/capture_task.gd` | `CaptureTask.replan()` | shiny.d:2188-2194 | Decay the claimed scores by position (0.5^i) and normalize by the decayed sum. |
| `ai/tasks/capture_task.gd` | `CaptureTask.claim()` | shiny.d:2262-2286 | claimCapture. |
| `ai/tasks/capture_task.gd` | `CaptureTask.node_value_score()` | shiny.d:2083-2095 | nodeValueScore |
| `ai/tasks/capture_task.gd` | `CaptureTask.territorial_score()` | shiny.d:2023-2041, retail 0x488d70 | territorialScore |
| `ai/tasks/capture_task.gd` | `CaptureTask` | territorialScore |  |
| `ai/tasks/capture_task.gd` | `CaptureTask.claim()` | claimCapture | named after the original function |
| `ai/tasks/capture_task.gd` | `CaptureTask.node_value_score()` | nodeValueScore |  |
| `ai/tasks/capture_task.gd` | `CaptureTask.territorial_score()` | territorialScore |  |
| `ai/tasks/capture_task.gd` | `CaptureTask` | castCachedInRange; nodeValueScore; territorialScore; rateWithBase | The capture records and their claim |
| `ai/tasks/guard_task.gd` | `GuardTask` | shiny.d:2195-2229 `replanGuard`, 2288-2336 `claimGuard`; t4oBrain with the guard task, shiny.d:2557-2570; shiny.d:2292-2300 | What the side guards |
| `ai/tasks/guard_task.gd` | `GuardTask.replan()` | the status bits 4/8 of the original, shiny.d:2200-2202 | The wizard |
| `ai/tasks/guard_task.gd` | `GuardTask.replan()` | shiny.d:2211 | thaum quirk |
| `ai/tasks/guard_task.gd` | `GuardTask._claim_value()` | shiny.d | The weight of `t` for `record` in claimGuard |
| `ai/tasks/guard_task.gd` | `GuardTask` | probOr |  |
| `ai/tasks/guard_task.gd` | `GuardTask` | probOr |  |
| `ai/tasks/guard_task.gd` | `GuardTask` | claimGuard; rateWithBase; the overwritten accumulator `total` | The guard claim |
| `ai/tasks/guard_task.gd` | `GuardTask.replan()` | retail 0x48a94b | An altar under desecration scores 1.0 |
| `ai/tasks/idle_task.gd` | `IdleTask` | shiny.d:2231-2237 `replanIdle`, 2300-2310 `claimIdle`; recordUpdate, shiny.d:3408-3427 | The creatures nobody claimed |
| `camera/world_camera.gd` | `WorldCamera` | sacengine dagonBackend.d positionCamera / cameraControl. Units 1:1 sac → m. | Third-person camera that follows a body |
| `camera/world_camera.gd` | `WorldCamera.look_down_max_deg` | sacengine only wraps the pitch at ±180° (dagonBackend.d:425). | Absolute limits of view_pitch_deg. |
| `camera/world_camera.gd` | `WorldCamera.free_pitch_deg` | sacengine camera.pitch over pitchOffset. | Free-look pitch on top of the follow angle. |
| `components/health.gd` | `Health.MELEE` | sacengine DamageMod (state.d:8868), dealDamage state.d:8951-8957. | The kinds of damage, each the resistance the body uses against it. |
| `components/health.gd` | `Health.afflictions` | sacengine state.d:8965. | The states the body is in (petrified ×0.2) scale every hit, on both paths. |
| `components/health.gd` | `Health.oil` | sacengine dealRawDamage, state.d:9028-9031. | the body's oil (Oiled). |
| `components/health.gd` | `Health.growth` | sacengine devourSoul, state.d:13154-13158. | what the body has devoured (Devour) |
| `components/health.gd` | `Health.damage_typed()` | sacengine dealDamage state.d:8948-8972, 8961, 8962-8969 (DamageMod.peirceShield); dealRawDamage state.d:9001-9050; sideDamageMultiplier state.d:9005, 28892-28899; poison state.d:9415-9419. | The damage a hit does to this body |
| `components/health.gd` | `Health.resistance()` | sacengine stores them ×1e-3, sacobject.d:156-160; poison bonus state.d:8950-8957; Slime state.d:8950. | The body's resistance for `kind` |
| `components/health.gd` | `Health._side_factor()` | sacengine state.d:8961, 9005, 9415-9419, 28892-28899. | the one place that decides how much of a hit from `from_slot` this body takes for its… |
| `components/health.gd` | `Health._passive_factor()` | sacengine dealRawDamage, state.d:9010-9028, 9017-9022. | The passive scales every kind of hit by the health before it. |
| `components/health.gd` | `Health.regenerate()` | sacengine updateCreatureStats, state.d:14403; regenerationBlocked, stats.d:73. | Heals max(0, regeneration · poisonRegeneration) · …. |
| `components/health.gd` | `Health._can_be_damaged()` | sacengine canDamage, state.d:8916-8923. | A wizard's ghost takes no damage while it heals; neither does a body in a ward that… |
| `components/health.gd` | `Health.damage_typed()` | canDamage |  |
| `components/health.gd` | `Health` | passiveOnDamage; dealDamage; devourSoul; poisonRegeneration | Passive, damage factor, Devour, poison |
| `components/locomotion/locomotion.gd` | `Locomotion` | sacengine stats.d:104 (ground creatures turn at π rad/s), state.d:14800-14821 (gibDepth). | How a walking body moves in one physics step |
| `components/mana_pool.gd` | `ManaPool.given` | sacengine giveMana, state.d:8828-8832. | add was called |
| `components/mana_pool.gd` | `ManaPool.poisoning` | sacengine giveMana, state.d:8829. | The body's poison (Poisoning). |
| `components/mana_pool.gd` | `ManaPool.drain()` | sacengine drainMana, state.d:8822-8825. | Mana − amount, never under 0. |
| `components/soul_purse.gd` | `SoulPurse.spend()` | sacengine updateCreatureCasting. | Summons pay here |
| `match/defeat_rule.gd` | `DefeatRule` | sacengine updateAltarDestruction -> defeat(side) state.d:26062; lose(side) state.d:13404-13407, 8298-8304, run at state.d:25998; getNewVictories state.d:30470-30490. | The server's rule for losing. |
| `match/defeat_rule.gd` | `DefeatRule._decide_winner()` | sacengine getNewVictories, state.d:30483-30492. | One team left among the seated sides that own an altar wins (no enemy side alive in… |
| `match/defeat_rule.gd` | `DefeatRule` | lose(side) = destroyAltars + killAll; altarSides | Defeat and victory |
| `match/match_clock.gd` | `MatchClock.ticks_for()` | sacengine state.d counts frames of 1/60 s. | Whole ticks that cover `seconds` (frames of 1/60 s). |
| `match/match_rules.gd` | `MatchRules.manahoar_rate` | sacengine manahoar mana aura (state.d ManaEntries.addManahoar). | Mana aura of the Manahoar |
| `match/match_rules.gd` | `MatchRules` | sacengine addManahoar. | It ramps with distance to allied manaliths from 50 to 1000. |
| `match/match_rules.gd` | `MatchRules.enable_drop_soul` | sacengine option enableDropSoul (options.d:106). | P drops one soul. |
| `match/match_rules.gd` | `MatchRules.doctor_death_s` | sacengine doctor death, state.d:13999. | How long a doctor's death takes |
| `match/match_rules.gd` | `MatchRules.altar_collapse_s` | sacengine AltarDestruction state.d:5289-5291, defeat state.d:26062. | Disappear 4 s + float 4 s + explode 3 s; the altar is gone at the end and its side is… |
| `match/match_rules.gd` | `MatchRules.wizard_vanish_ritual_s` | sacengine state.d:14010. | A wizard that dies under ritual vanishes in 4 s; one with no altar left in 1 s. |
| `match/match_rules.gd` | `MatchRules.desecrate_altar_range` | sacengine closestEnemyAltar, state.d:28083. | The enemy altar must be this close to the wizard on the plane. |
| `match/match_rules.gd` | `MatchRules.carry_speed_factor` | sacengine state.d:15759-15766. | The carried creature catches up at this multiple of the doctor's pace. |
| `match/match_rules.gd` | `MatchRules.carried_dies_when_dropped` | sacengine state.d:15776-15779. | A creature a doctor carries (or pumps back to life) dies when the doctor dies and… |
| `match/match_rules.gd` | `MatchRules.ritual_setup_s` | sacengine state.d:2713, 15948-15951. | Preparation, then rounds of walk + shoot + wait. |
| `match/match_rules.gd` | `MatchRules.ritual_drain_start_s` | sacengine state.d:15975, 15997-16011. | The drain of the wizard is spread over a window of the shoot phase |
| `match/match_rules.gd` | `MatchRules.desecrate_health_per_round` | sacengine state.d:16010-16011. | Per round, times (1 + souls of the creature). |
| `match/match_rules.gd` | `MatchRules.convert_pump_s_per_soul` | sacengine state.d:15697 `(soulNumber+1)*5*updateFPS`. | The pump lasts (souls of the corpse + 1) times this. |
| `match/match_rules.gd` | `MatchRules.convert_revive_min_health` | sacengine convertRevive, state.d:8679. | The creature stands up with min(max(convert_revive_min_health, convert_revive_fraction… |
| `match/match_rules.gd` | `MatchRules.convert_health_per_round` | sacengine state.d:16027. | Rounds of the Convert ritual |
| `match/match_rules.gd` | `MatchRules.guardian_attack_factor` | numbers follow sacengine (`sacengine/source/state.d`); candidateDistance>50.0f^^2 skips a farther building (state.d:28082), else mustBeNearBuilding (state.d:29561); attackDamageFactor state.d:8884. | (none of these numbers is checked against Sacrifice.exe). |
| `match/match_rules.gd` | `MatchRules.guardian_spell_factor` | sacengine dealRawDamage, state.d:9007-9008. | A guardian takes this much of a spell's damage and of a ranged attack's; melee goes… |
| `match/match_rules.gd` | `MatchRules.guardian_heal_per_s` | `1000.0f/(60*updateFPS)` per update, state.d:14408. | It heals 1000 per minute on top of its own regeneration |
| `match/match_rules.gd` | `MatchRules` | sacengine state.d:15366, 15368, 15393. | Farther than this from the post's attach point the guardian gets a move order back to… |
| `match/match_rules.gd` | `MatchRules.teleport_effect_s` | teleportEffectLifetime = 32 frames, state.d:16074; numbers follow sacengine (`sacengine/source/state.d`). | (none of these numbers is checked against Sacrifice.exe). |
| `match/match_rules.gd` | `MatchRules.teleport_ring_s` | teleportRingLifetime = 48 frames, state.d:16095. | Each ring lives this long. |
| `match/match_rules.gd` | `MatchRules.teleport_ring_rise` | Vector3(0, 0, 0.25) / teleportRingLifetime per frame, state.d:16097. | A ring rises this much over its life. |
| `match/match_rules.gd` | `MatchRules.wizard_level` | sacengine synchronizeLevel (lobby.d:350), getSpells (state.d:29512). | Wizard level of every wizard in the match |
| `match/match_rules.gd` | `MatchRules.wizard_level_stats` | sacengine makeWizard, state.d:2307-2311. | The level also raises the wizard |
| `match/match_rules.gd` | `MatchRules.health_per_level` | sacengine state.d:2308-2311. | Per level, when wizard_level_stats is on. |
| `match/match_rules.gd` | `MatchRules.allied_vision` | sacengine option alliedVision (options.d:95), markAsVisible state.d:29658-29665. | What a side sees is marked for its allies too. |
| `match/match_rules.gd` | `MatchRules.friendly_fire` | sacengine option friendlyFire (options.d:98), dealDamage state.d:8961, sideDamageMultiplier state.d:9005, 9175, 28892-28899, poison state.d:9415-9419. | Off |
| `match/match_rules.gd` | `MatchRules.ally_damage_factor` | sacengine sideDamageMultiplier, state.d:28892-28899. | Multiplier between allies. |
| `match/match_rules.gd` | `MatchRules.friendly_fire` | ignoreFriendly (poison) | Poison ignores the side |
| `match/match_state.gd` | `MatchState.seated_slots` | sacengine altarSides, state.d:31493. | The slots with a wizard seated (human or AI), derived on the authority from the… |
| `match/match_state.gd` | `MatchState.sides()` | sacengine altarSides, state.d:30494-30500, 31493-31514. | The slots that own an altar and have a wizard seated, in order. |
| `net/launch_flags.gd` | `LaunchFlags` | app.d:276-355 (the option flags are named like the option fields; with both forms the `--no-` one wins). | Reads the command line of this process into a LaunchPlan |
| `orders/command/ability_command.gd` | `AbilityCommand` | sacengine selectAbility (dagonBackend.d:152-178), renderedSelection ability (state.d:30231). | The selection's active ability. |
| `orders/command/ability_command.gd` | `AbilityCommand._apply()` | applyOrder, state.d:29256. | Every selected creature whose active ability is `ability` gets the order; the others… |
| `orders/command/ability_command.gd` | `AbilityCommand` | requiresTarget = flags != 0 | An ability that needs a target |
| `orders/command/armed_command.gd` | `ArmedCommand` | sacengine dagonBackend.d:1236-1250. | What waits for the next left click |
| `orders/command/command_feedback.gd` | `CommandFeedback` | sacengine command cone, state.d:29261-29264. | What the player's commands answer with |
| `orders/command/command_feedback.gd` | `CommandFeedback._on_unit_summoned()` | sacengine newCreatureAddToSelection. | The owner's new creature joins the selection. |
| `orders/command/order_command.gd` | `OrderCommand` | sacengine dagonBackend.d:1215-1233, state.d:29256. | Orders to the selection |
| `orders/command/order_command.gd` | `OrderCommand.icon_at()` | dagonBackend.d:1215-1233. | Attack or guard a body; on the ground, advance or guard the spot. |
| `orders/command/spell_command.gd` | `SpellCommand.arm_spell()` | sacengine selectSpell. | An unaffordable or cooling spell is not armed. |
| `orders/formations/arc_formation.gd` | `ArcFormation` | state.d:455-466. | Semicircle and circle |
| `orders/formations/formation_type.gd` | `FormationType` | sacengine Formation / getFormationOffsets, state.d:417. | A formation of a group order. |
| `orders/formations/row_formation.gd` | `RowFormation` | state.d:429-475. | The formations laid in rows |
| `orders/formations/wedge_formation.gd` | `WedgeFormation` | state.d:467-472. | The wedge |
| `orders/match_command.gd` | `MatchCommand` | sacengine dagonBackend.d:947-1300. | The player's commands in the world, as a coordinator of small children… |
| `orders/order_radial.gd` | `OrderRadial` | sacengine xmenuTime. | The one owner of the `order_units` button in the world, and of the keys that open the… |
| `orders/orders.gd` | `orders` | sacengine Command → ObjectState.applyOrder (state.d:29140), Formation / getFormationOffsets (state.d:417), greedy slot matching (state.d:29205), retreat (state.d:29174). | RTS orders, server-authoritative. |
| `orders/orders.gd` | `orders.retarget_range` | attackDistance, state.d:13609. | An attack on a creature retargets each unit to the enemy creature closest to its own… |
| `orders/orders.gd` | `orders._own_units()` | canOrder (state.d:1140), sacengine order. | Pacifists refuse attack and advance. |
| `orders/orders.gd` | `orders._formation()` | state.d:429. | The slots (right, forward) of `formation` for the group. |
| `orders/orders.gd` | `orders._match_rows()` | sacengine numCreaturesInGroup = 12, state.d:29205. | The rows of a formation larger than one line (the port's extension,… |
| `orders/orders.gd` | `orders.spacing_per_size` | getFormationOffsets |  |
| `orders/orders.gd` | `orders._formation()` | getFormationOffsets |  |
| `orders/orders.gd` | `Orders` | numCreaturesInGroup = 12; getFormationOffsets unitDistance | Group size and formation spacing |
| `orders/selection.gd` | `Selection` | sacengine SideData (state.d:30258), canSelect (state.d:1134), numCreaturesInGroup, selectAll (state.d:29867), dagonBackend.d:1173-1198, newCreatureAddToSelection (state.d:29959), renderer.d:3890-3895. | The local player's creature selection and groups. |
| `orders/selection.gd` | `Selection.box` | renderer.d:4030. | Rectangle drawn while dragging (white frame). |
| `orders/selection.gd` | `Selection.ability()` | sacengine renderedSelection ability. | The active ability the selection offers |
| `orders/selection.gd` | `Selection.drop()` | state.d:10408-10410. | A creature that was tied to a building leaves the selection and every group (unselect… |
| `orders/selection.gd` | `Selection._same_type_near()` | selectAll, state.d:29884-29896. | Own creatures within same_type_radius of `unit`, closest first |
| `orders/selection.gd` | `Selection.ground` | terrainLineOfSight |  |
| `orders/selection.gd` | `Selection` | numCreaturesInGroup; options.doubleClickSpeed; renderer targetCacheDelta; removeFromGroups; canSelect | Group size, double click, guardians |
| `spells/actions/afflict_action.gd` | `AfflictAction` | sacengine castFreeze / freeze, castGraspingVines / graspingVines, castRingsOfFire / ringsOfFire, castSlime / slime. | A spell that lays one state on one body (Freeze, Grasping Vines, Rings of Fire, Slime) |
| `spells/actions/animate_dead_action.gd` | `AnimateDeadAction` | sacengine castAnimateDead, animateDead (state.d:10859-10903). | Animate Dead |
| `spells/actions/carrier_action.gd` | `CarrierAction` | sacengine castDragonfire, castBovineIntervention bovineIntervention, castDeath (state.d:10926-10939, 11257-11286, 11341-11354). | A spell that sends a carrier (Dragonfire's dragon, Charm's spirits, Blind Rage's fist,… |
| `spells/actions/convert_action.gd` | `ConvertAction` | sacengine castConvert, state.d:10181-10196 | Convert (ccas) |
| `spells/actions/desecrate_action.gd` | `DesecrateAction` | sacengine castDesecrate, state.d:10198-10213 | Desecrate (ucas) |
| `spells/actions/guardian_action.gd` | `GuardianAction` | mustBeNearBuilding, sacengine state.d:29561, 28082; guardian / findClosestBuilding, state.d:10398-10414 | Guardian (ndrg) |
| `spells/actions/guardian_action.gd` | `GuardianAction.can_guard()` | sacspell.d:168, state.d:10401-10402, isApplicable sacspell.d:63 | A creature of `slot` that can be tied |
| `spells/actions/heal_action.gd` | `HealAction` | sacengine heal | Heal (laeh) |
| `spells/actions/launch_action.gd` | `LaunchAction` | sacengine castChainLightning, castRainbow, castHaloOfEarth (state.d:10832-10857, 11015-11023). | A spell that puts something into the world while the wizard casts and lets go of it… |
| `spells/actions/lightning_action.gd` | `LightningAction` | sacengine castLightning | Lightning (ntil) |
| `spells/actions/lightning_action.gd` | `LightningAction.finish()` | state.d:9017-9022 | DamageMod.lightning, which charges a Storm Giant. |
| `spells/actions/lightning_action.gd` | `LightningAction._origin()` | sacengine updateLightningCasting (state.d:16322-16341) | The bolt starts 0.5 above the top of the wizard's hitbox and 0.75 ahead of its front. |
| `spells/actions/meanstalks_action.tscn` | `cast particle (editor_description)` | sacengine animateMeanstalksCasting | heal particle while casting |
| `spells/actions/pups_action.gd` | `PupsAction` | sacengine speedUp | Speedup (pups) |
| `spells/actions/rock_action.gd` | `RockAction` | sacengine castRock | Rock (kcor) |
| `spells/actions/soul_action.gd` | `SoulAction` | sacengine castSoulMole, castSoulWind (state.d:10814-10826, 10941-10954). | A spell that sends something walking to a soul and back (Soul Mole, Soul Wind). |
| `spells/actions/spell_action.gd` | `SpellAction.stationary` | sacspell.d:201 (a structure always casts standing), state.d:62-63, 14672 (no step while stationaryCasting). | The wizard neither walks nor turns while he casts it (a structure) |
| `spells/actions/structure_action.gd` | `StructureAction` | sacengine spellStatus (state.d:29534-29573), the structure cast (state.d:10072-10083, 15250-15274). | A structure spell (Manalith, Shrine) |
| `spells/actions/teleport_action.gd` | `TeleportAction` | sacengine teleport / getTeleportPosition, state.d:10213-10228, 10313-10327; canTeleport, state.d:10306-10311; updateTeleportCasting, state.d:16056-16072 | Teleport (elet) |
| `spells/actions/teleport_action.gd` | `TeleportAction.is_building_of()` | state.d:30786-30790 | A standing building of `slot` that can be aimed at. |
| `spells/actions/teleport_action.gd` | `TeleportAction` | flags 4112 = targetStructures / onlyAlly | Aims at an own structure |
| `spells/actions/teleport_math.gd` | `TeleportMath.landing()` | sacengine state.d:10215-10228; the original leaves `// TODO: fix` there, state.d:10225 | getTeleportPosition |
| `spells/actions/teleport_math.gd` | `TeleportMath.carried()` | state.d:10313-10327; state.d:10318-10320 | teleport |
| `spells/actions/teleport_math.gd` | `TeleportMath.in_radius()` | state.d:10326 | proximity.eachInRange(startPosition, effectRange) |
| `spells/actions/teleport_math.gd` | `TeleportMath.landing()` | getTeleportPosition |  |
| `spells/actions/teleport_math.gd` | `TeleportMath.in_radius()` | startPosition, effectRange |  |
| `spells/actions/teleport_math.gd` | `TeleportMath` | teleport: newPosition = obj.position - startPosition + targetPosition | The formation keeps its shape |
| `spells/actions/thrown_action.gd` | `ThrownAction` | sacengine updateWrathCasting | A guided ball that leaves the wizard's hands (Wrath, Fireball, Insect Swarm). |
| `spells/actions/tornado_action.tscn` | `cast_scene (editor_description)` | sacengine animateTornadoCasting | The cst0 spiral around the wizard |
| `spells/actions/wall_action.gd` | `WallAction` | sacengine castFirewall, castWailingWall, castVinewall, castWallOfSpikes, castFence (state.d:11118-11211). | A spell that raises a wall on the ground (Firewall, Wall of Spikes, Wailing Wall,… |
| `spells/actions/ward_action.gd` | `WardAction` | sacengine skinOfStone, airShield, etherealForm, fireform, protectiveSwarm, healingAura (state.d:10591-10686, 11076-11088). | A spell that switches on one of the wards of a body (Skin of Stone, Air Shield,… |
| `spells/actions/zone_action.gd` | `ZoneAction` | sacengine castExplosion, castFrozenGround, castDemonicRift, castRainOfFrogs, castCloudkill (state.d:9986-10048, 10960-11339). | A spell that raises a zone on the ground (Explosion, Frozen Ground, Demonic Rift, and… |
| `spells/animate_dead/animate_dead_fx.gd` | `AnimateDeadFx` | sacengine AnimateDead and animateAnimateDead (state.d:10865-10880, 18335-18353). | What everybody sees while Animate Dead brings a creature back |
| `spells/animate_dead/streamer_fx.gd` | `StreamerFx` | sacengine animateDeadEffect and renderAnimateDead (state.d:18328-18334, renderer.d:2341-2358). | One stream of Animate Dead |
| `spells/carrier/carrier_fall.gd` | `CarrierFall` | sacengine updateBovineIntervention (state.d:21788-21819), BovineIntervention.travelTime / maxHeight (state.d:4162-4174). | The fall of Bovine Intervention's cow for its SpellCarrier |
| `spells/carrier/carrier_fall.gd` | `CarrierFall._VOID_DEPTH_M` | sacengine gibDepth | Below this under the void it is gone. |
| `spells/carrier/carrier_hold.gd` | `CarrierHold` | sacengine updateCharm charming, updateBlindRage formingFist, updateIntestinalVaporization vaporizing (state.d:21447-21487, 21570-21615, 21992-22013). | What a SpellCarrier does after arriving |
| `spells/carrier/carrier_hunt.gd` | `CarrierHunt` | sacengine updateDeath, Death (state.d:4262-4298, 22153-22274). | The hunt of Death for its SpellCarrier. |
| `spells/carrier/carrier_landing.gd` | `CarrierLanding` | sacengine cowExplosion, quake (state.d:21749-21786, 25716-25759). | What happens where a falling SpellCarrier goes through the land (`landed`) |
| `spells/carrier/carrier_path.gd` | `CarrierPath` | sacengine cintp2 and updateSoulMolePosition (util.d:554, state.d:17938-18028). | The route of a carrier |
| `spells/carrier/carrier_path.gd` | `CarrierPath.spiral()` | sacengine dragonfireCastingPosition (state.d:18698-18706). | Where a guided carrier is `progress` (0 to 1) of the way through the casting |
| `spells/carrier/carrier_pulse.gd` | `CarrierPulse` | sacengine updateSoulMole, updateSoulWind (state.d:18030-18044, 18999-19018). | What a SpellCarrier does to the bodies it passes near, once its casting time is over |
| `spells/carrier/cast_emitters.gd` | `CastEmitters` | sacengine animateGroundForCow (state.d:21665-21683). | The sprites a spell throws at a place while the wizard casts it (the earth that rises… |
| `spells/carrier/dragon_arrive.gd` | `DragonArrive` | sacengine updateDragonfirePosition, updateDragonfireTarget (state.d:18801-18856). | The work of Dragonfire's dragon |
| `spells/carrier/dragon_arrive.gd` | `DragonArrive` | dealSplashSpellDamageAt with DamageMod.ignite, setAblaze | The splash at the dragon |
| `spells/carrier/growing_ring.gd` | `GrowingRing` | sacengine renderBlindRageExplosion, SacBlindRageExplosion (renderer.d:2832-2851, sacobject.d:3174-3230); the rise is 3 m of state (state.d:21636, maxExplosionHeight/128 per tick) plus 4 m of drawing (renderer.d:2849, maxOffset). | A flat ring that grows from nothing to `radius_m` while its SpellCarrier lingers… |
| `spells/carrier/guided_flight.gd` | `GuidedFlight` | sacengine updateDragonfirePosition, changeDirectionTowards (state.d:18776-18871). | The flight of a guided SpellCarrier (Dragonfire's dragon), with the state it needs and… |
| `spells/carrier/hold_body.gd` | `HoldBody` | sacengine updateIntestinalVaporization vaporizing (state.d:21471-21489). | While a SpellCarrier waits on its target (CarrierHold) this keeps the target stunned… |
| `spells/carrier/hold_body.gd` | `HoldBody.stun_cooldown_s` | sacengine 3 s | The stun's own cooldown for the body, in seconds. |
| `spells/carrier/morph_model.gd` | `MorphModel` | sacengine SacCow.getFrame, SacDeath.getFrame, SacBlindRage.getFrame (sacobject.d:3143-3307): the order of the poses and their pace. | Plays the animations of a model whose frames are blend shapes (the cow, Death, Blind… |
| `spells/carrier/phase_sprite.gd` | `PhaseSprite` | sacengine renderCharmHeart, CharmHeart.growTime / shrinkTime / lifetime (renderer.d:2898-2915, state.d:4218-4226). | A sprite (a quad that faces the camera, atlas_quad_*.gdshader) that shows only in some… |
| `spells/carrier/rock_burst.gd` | `RockBurst` | sacengine cowExplosion EruptDebris (state.d:21752-21761): 16 rocks at 20 ± 7.5 m/s, sideways and up. | Rocks thrown up and out from a point, played on every peer by FxBus.broadcast_scene |
| `spells/carrier/soul_trip.gd` | `SoulTrip` | sacengine updateSoulMole, updateSoulWind (state.d:17938-18044, 18916-19018). | The trip of the Soul Mole's rock and the Soul Wind's funnel for its SpellCarrier |
| `spells/carrier/spell_carrier.gd` | `SpellCarrier` | sacengine SoulMole, SoulWind, Dragonfire, Charm, BlindRage, IntestinalVaporization, BovineIntervention, Death (state.d:17938-22300). | Something a spell sends on a trip (one piece for all of them; `motion` says which). |
| `spells/carrier/swarm_orbit.gd` | `SwarmOrbit` | sacengine updateTargetedCharmSpirit, updateFlyingCharmSpirit, updateIntestinalVaporizationEffect (state.d:21863-21913, 21492-21516). | A few things (its children) that circle what their SpellCarrier is about |
| `spells/cast_time.gd` | `CastTime` | sacengine `castingTime(level)`, sacspell.d:93-102 | Casting time of a book entry for a wizard level |
| `spells/cast_time.gd` | `CastTime.FRAMES_PER_SECOND` | sacengine | Cast frames per second |
| `spells/caster.gd` | `Caster` | sacengine startCasting | Casts the wizard's book. |
| `spells/caster.gd` | `Caster.MANA_EPSILON` | sacengine manaEpsilon | Mana tolerance. |
| `spells/caster.gd` | `Caster.MIN_MANA_COST` | sacengine SacSpell | Every spell costs at least this much |
| `spells/caster.gd` | `Caster.wizard_can_cast()` | sacengine canCast (state.d:9520) | Only an idle or moving wizard, not a dying or ghost one. |
| `spells/caster.gd` | `Caster.arm_status()` | sacengine selectSpell: mana, then cooldown. | Can the spell be armed? &"" = yes, else a Refusal key. |
| `spells/caster.gd` | `Caster.summon_status()` | sacengine spellStatus: souls, mana, then cooldown. | Can the creature be summoned now? &"" = yes, else a Refusal key. |
| `spells/caster.gd` | `Caster._cast_fx_id()` | state.d:16386, 16707. | The id of the hands' particle |
| `spells/caster.gd` | `Caster` | manaCost = max(1, manaCost); startCasting fails for a dying or ghost wizard | Minimum cost and silent refusal |
| `spells/chain/cast_bolts.gd` | `CastBolts` | sacengine updateChainLightningCasting (state.d:18207-18224), chainLightningCastingEffect. | The little bolts that climb around a wizard while he casts Chain Lightning |
| `spells/chain/cast_glow.gd` | `CastGlow` | sacengine animateRainbowCasting (state.d:18047-18063). | The glow that rises around a wizard while he casts Rainbow |
| `spells/chain/chain_heal.gd` | `ChainHeal` | sacengine updateRainbow, animateRainbowHit, heal with an infinite amount (state.d:18112-18156; REA FUN_0042cdb0). | One arc of Rainbow |
| `spells/chain/chain_hop.gd` | `ChainHop` | sacengine updateChainLightning, updateRainbow (state.d:18129-18156, 18270-18293), REA FUN_00420070 / FUN_0042cc70 for the radius. | A chain of jumps (Chain Lightning, Rainbow, the jumps of Dragonfire) |
| `spells/chain/chain_strike.gd` | `ChainStrike` | sacengine lightning with updateTargets false (state.d:18274, 10474-10491). | One bolt of a chain of lightning |
| `spells/drops/drop_blast.gd` | `DropBlast` | sacengine rainFrogExplosion, rainOfFireDropExplosion, bombardmentDropExplosion (state.d:19405-19427, 21142-21154, 21344-21379). | What a drop does where its flight ends |
| `spells/drops/drop_dent.gd` | `DropDent` | sacengine bombardmentDent, dentDisplacement (state.d:4077-4083, 7303-7315). | When its drop ends (a meteorite hits the ground) it leaves the dent of its `manual`… |
| `spells/drops/drop_poison.gd` | `DropPoison` | sacengine plagueDropExplosion (state.d:20980-21015); `freg` of the SPEL (spells.wad `plag`). | What a drop of plague does where its flight ends |
| `spells/drops/frog_cling.gd` | `FrogCling` | sacengine updateRainFrog, rainFrogCollisionTarget (state.d:19399-19403, 19441-19447, 19488-19499). | What a frog does when it touches a creature |
| `spells/drops/frog_hop.gd` | `FrogHop` | sacengine updateRainFrog (state.d:19428-19487). | How a frog of Rain of Frogs moves once it is down |
| `spells/drops/frog_look.gd` | `FrogLook` | sacengine updateRainFrog, renderer.d:2500-2516 (animationFrame 11 falling, 0..15 jumping, 15 sitting). | The frog's picture, on every peer, from its replicated state |
| `spells/drops/zone_drop.gd` | `ZoneDrop` | sacengine updateRainFrog, updatePlagueDrop, updateRainOfFireDrop, updateBombardmentDrop (state.d:19428-19504, 21030-21053, 21172-21196, 21395-21421). | Something a cloud lets go |
| `spells/effects/kill_effect.gd` | `KillEffect` | sacengine updateDeath attack, deathEffects (state.d:22243-22295). | Death's blow |
| `spells/effects/side_change_effect.gd` | `SideChangeEffect` | sacengine charm (state.d:21915-21950): clearOrderQueue, side = wizard's, order retreat to the wizard, 128 bouncingHeart, CharmHeart. | Charm's change |
| `spells/fireball_projectile.gd` | `fireball_projectile` | sacengine castFireball/updateFireball, state.d:10519-10528, 16682-16700 | Pyro Fireball. |
| `spells/fireball_projectile.gd` | `fireball_projectile._explode()` | sacengine animateFireballExplosion, state.d:16631-16665 | Its own explosion |
| `spells/guardian/guard_post.gd` | `GuardPost` | damageGuardians, state.d:9098-9117; the NaN of state.d:9117 | «This building accepts guardians». |
| `spells/guardian/guard_post.gd` | `GuardPost.split_divisor()` | sacengine; state.d:9101 | n guardians each take damage / this. |
| `spells/guardian/guard_post.gd` | `GuardPost.closest()` | findClosestBuilding, state.d:10371-10396 | The open post of `slot` closest to `from` on the plane within `max_distance`, or null. |
| `spells/guardian/guardian_bond.gd` | `GuardianBond` | sacengine, none verified against Sacrifice.exe; attackDamageFactor, state.d:8884; dealRawDamage, state.d:9007-9008; state.d:14408; state.d:1414; state.d:25071; state.d:14069; canTeleport, state.d:10309: group `rooted`; state.d:10408-10410; isValidGuard, state.d:15352-15355; the building gone, state.d:15362; state.d:15366-15376 | The creature tied to a building (Guardian `ndrg`). |
| `spells/guardian/guardian_bond.gd` | `GuardianBond._keep_near()` | state.d:15366-15376 | Farther than the leash from the attach point |
| `spells/guardian/guardian_bond.gd` | `GuardianBond.is_valid_guard()` | isValidGuard |  |
| `spells/guardian/guardian_tether.gd` | `GuardianTether` | updateGuardianShape, state.d:15326-15340; cubic, state.d:15400-15402; renderer.d:1716; state.d:15404-15417; sacobject.d:4466-4472; renderer.d:253-261; charlie.wad, sacobject.d:4466 | The beam between a guardian and its building, drawn on every peer with a window; the… |
| `spells/guardian/guardian_tether.gd` | `GuardianTether.segments` | SacGuardianTether.numSegments, sacobject.d:4462 | Segments of the line. |
| `spells/guardian/guardian_tether.gd` | `GuardianTether.jitter_radius` | Guardian.locRadius, state.d:2780 | Edge of the box the control points wobble in; the ends move a quarter of that. |
| `spells/guardian/guardian_tether.gd` | `GuardianTether.width` | the 1.0 passed to makeLineMeshes, sacobject.d:4472 | Distance from the axis to each of the 3 planes, meters. |
| `spells/guardian/guardian_tether.gd` | `GuardianTether.energy` | SacGuardianTether material energy, renderer.d:257 | Brightness. |
| `spells/guardian/guardian_tether.gd` | `GuardianTether.frame_s` | 2 ticks of the original's 60 per second. | Seconds per atlas cell. |
| `spells/guardian/guardian_tether.gd` | `GuardianTether._draw()` | makeLineMesh offsets, sacobject.d:2192 | 3 planes at 120 degrees, pointed at both ends. |
| `spells/guardian/guardian_tether.gd` | `GuardianTether._control_points()` | state.d:15326-15340 | The 5 control points, mixed between the last shape and the next. |
| `spells/guardian/guardian_tether.gd` | `GuardianTether` | makeLineMeshes(19, 4, 4, 1.5, 1.0, …); Guardian.pulseFrames = updateFPS / 2; makeLineMesh texcoords | Beam mesh, pulse and texcoords |
| `spells/heal_effect.gd` | `HealEffect` | sacengine heal | Heal over time |
| `spells/heal_effect.gd` | `HealEffect.HEAL_SPEED` | sacengine healSpeed | Heal speed. |
| `spells/heal_effect.gd` | `HealEffect.FRAMES_CAP` | sacengine int.max (32 bits); state.d:10455 | satAdd caps the frames of heals that add up there. |
| `spells/heal_effect.gd` | `HealEffect.fx_interval_s` | sacengine spawns particles every frame | Seconds between `heal_fx` bursts on the target. |
| `spells/heal_effect.gd` | `HealEffect.can_heal()` | sacengine canHeal | Alive and not full. |
| `spells/heal_effect.gd` | `HealEffect.heal_full()` | sacengine heal; sacspell.d:211, state.d:10446-10449 | Heal with an infinite amount (Healing Shower tum@, Scarab slba) |
| `spells/heal_effect.gd` | `HealEffect.add()` | satAdd, state.d:10455 | A heal already running gets the new frames on top, saturated. |
| `spells/heal_effect.gd` | `HealEffect.renew()` | sacengine HealingAura's doHeal | The timer goes back to `frames` and the rate to the better of the two; nothing is added. |
| `spells/heal_effect.gd` | `HealEffect.heal_full()` | canHeal |  |
| `spells/heal_effect.gd` | `HealEffect` | healSpeed; satAdd (saturated frames) | Heal over time |
| `spells/rock_projectile.gd` | `RockProjectile` | sacengine state.d:10541-10561, 16707-16855; rockExplosion, state.d:16784 | James' Rock. |
| `spells/rock_projectile.gd` | `RockProjectile.WARMUP_FRAMES` | sacengine rockWarmupTime | Warm-up time = updateFPS / 4. |
| `spells/rock_projectile.gd` | `RockProjectile.BURY_DEPTH` | sacengine rockBuryDepth | Depth the rock starts buried. |
| `spells/rock_projectile.gd` | `RockProjectile.CAST_AHEAD` | sacengine rockCastingPosition | 1.5 m past the front of the caster's hit box. |
| `spells/rock_projectile.gd` | `RockProjectile.SPIN_MIN` | sacengine makeRock | Spins 2π·[0.2, 0.8] rad/s around a random axis. |
| `spells/rock_projectile.gd` | `RockProjectile.hit_box` | sacengine rockSize 2 | The box that touches the bodies it bursts on (±1 m), centered on the rock. |
| `spells/rock_projectile.gd` | `RockProjectile._cast_step()` | sacengine updateRockCasting | Glued ahead of the caster, rising out of the ground. |
| `spells/rock_projectile.gd` | `RockProjectile.cast_position()` | sacengine rockCastingPosition | Ahead of the caster, past the front of its hit box. |
| `spells/rock_projectile.gd` | `RockProjectile._collision_target()` | sacengine rockCollisionTarget / collisionTarget (state.d:16431, 16777) | Every living body in the ±1 m box except the caster; enemies first, then neutrals,… |
| `spells/rock_projectile.gd` | `RockProjectile._burst()` | sacengine rockExplosion | dealSpellDamage(target, …, DamageMod.none) = direct spell damage. |
| `spells/rock_projectile.gd` | `RockProjectile.TRAIL_INTERVAL_S` | animateRock |  |
| `spells/rock_projectile.gd` | `RockProjectile` | rockCastingPosition; warm-up updateFPS / 4; dealSpellDamage(target, …, DamageMod.none) | Rises buried 1 m, then flies |
| `spells/slime_ball.gd` | `SlimeBall` | sacengine SlimeCasting (sacobject.d:2602-2612, renderer.d:2208-2231). | The ball of slime that grows ten metres over a body while the wizard casts Slime and… |
| `spells/speedup_effect.gd` | `SpeedupEffect` | sacengine speedUp | Speed boost |
| `spells/spell_target.gd` | `SpellTarget` | sacengine castFreeze, castGraspingVines, castRingsOfFire, castSlime (state.d:10687-10770). | Who a spell may land on, as data |
| `spells/spell_target.gd` | `SpellTarget.neutral_allowed` | sacengine charmNeutralCreatures | Off |
| `spells/spell_target.gd` | `SpellTarget` | ccProtected | Bodies protected from control |
| `spells/spellbook.gd` | `Spellbook` | getSpells, state.d:29512; sacengine Spellbook.sort | Book of a wizard |
| `spells/spellbook.gd` | `Spellbook.apply_cooldown()` | sacengine applyCooldown | The cast entry waits castingTime(level) + cooldown + extra; every other entry… |
| `spells/spellbook.gd` | `Spellbook` | applyCooldown; castingTime(level) | Cooldowns over the whole book |
| `spells/splash_damage.gd` | `SplashDamage` | dealDamageAt skips only the directTarget, state.d:9077; maximum ≤ 0, sacengine canDamage; sacengine dealSplashSpellDamageAt / dealDamageAt, state.d:9063-9095 | Splash damage |
| `spells/splash_damage.gd` | `SplashDamage.deal()` | dealSplashRangedDamageAt, state.d:9400 | Hurts every body around `center` except `direct` (which the caller already hit with… |
| `spells/splash_damage.gd` | `SplashDamage.bodies_within()` | sacengine dealDamageAt's collisionTargets, state.d:9075-9088 | The one walk of a splash |
| `spells/splash_damage.gd` | `SplashDamage.hurt()` | sacengine dealDamage with an attacker creature, state.d:8933-8947, also on the splash walk | `mods` |
| `spells/splash_damage.gd` | `SplashDamage.box_distance()` | sacengine boxPointDistance | From the point to the body's hit box. |
| `spells/stalks/stalk.gd` | `Stalk` | sacengine updateMeanstalk (state.d:22574-22695). | One stalk of Meanstalks |
| `spells/stalks/stalk_grip.gd` | `StalkGrip` | sacengine updateMeanstalk, modes grabbing, holding and throwing (state.d:22618-22653, 22682-22688). | The body one stalk holds |
| `spells/stalks/stalk_hunt.gd` | `StalkHunt` | sacengine findMeanstalkTarget, meanstalkCheckTarget (state.d:22544-22573). | What a stalk hunts and how fast it moves while it does |
| `spells/stalks/stalk_roster.gd` | `StalkRoster` | sacengine Meanstalks.targets, hasTarget, addTarget (state.d:4435-4441). | The bodies the stalks of one Meanstalks have already caught |
| `spells/stalks/stalk_rules.gd` | `StalkRules` | sacengine meanstalkCurveSetup, meanstalkAccelerate, meanstalkCheckTarget, meanstalkRandomPos (state.d:11419-11440, 22527-22554). | The plain numbers of a Meanstalk with no tree |
| `spells/summoner.gd` | `Summoner` | sacengine spawn / updateCreatureCasting | Creature summons of a wizard. |
| `spells/summoner.gd` | `Summoner.ahead_m` | sacengine spawnPosition | First try ahead_m in front of the wizard, then these (side, ahead) offsets, then a… |
| `spells/summoner.gd` | `Summoner.clear_half_width` | sacengine isValidSpawnPosition | Nothing within this half-width (m) of the spot. |
| `spells/swarm_projectile.gd` | `swarm_projectile` | sacengine castSwarm/updateSwarm, state.d:10576, 17011 | Charnel Insect Swarm. |
| `spells/tornado/tornado_drift.gd` | `TornadoDrift` | sacengine updateTornado, tornadoWanderOffset (state.d:22756-22759, 22826-22873). | Where the tornado is and how big |
| `spells/tornado/tornado_lift.gd` | `TornadoLift` | sacengine tornadoLift (state.d:22760-22801). | What the tornado does to the bodies near it while it is active |
| `spells/tornado/tornado_look.gd` | `TornadoLook` | sacengine renderTornado, animateTornadoDirt (renderer.d:3453-3481, state.d:22802-22823). | What the tornado looks like on every peer |
| `spells/tornado/tornado_rules.gd` | `TornadoRules` | sacengine Tornado.updateCurve and getCentre, tornadoLift (state.d:4465-4505, 22760-22801). | The plain numbers of a Tornado with no tree |
| `spells/tornado/tornado_winds.gd` | `TornadoWinds` | sacengine castTornado wobblePhases and updateTornado (state.d:11477, 22865-22868). | The four winds that bend the funnel |
| `spells/walls/fence_posts.gd` | `FencePosts` | sacengine updateFence, makeFencePost, updateFencePost (state.d:20712-20752, 20755-20806; renderer.d:632-646). | The posts of a Fence |
| `spells/walls/fence_zap.gd` | `FenceZap` | sacengine updateFence, makeFencePost, Fence enums (state.d:3963-3991, 20729-20744, 20819-20893). | The lightning of a Fence |
| `spells/walls/wall_emitter.gd` | `WallEmitter` | sacengine updateFirewall particles, firyParticle (state.d:20036-20085). | Sprites that rise from a wall |
| `spells/walls/wall_ground.gd` | `WallGround` | sacengine Firewall.check, wallTargets (state.d:20024-20034, 19976-19997). | What a wall asks of the world around it |
| `spells/walls/wall_ground.gd` | `WallGround.bodies_inside()` | isInWall |  |
| `spells/walls/wall_look.gd` | `WallLook` | sacengine makeWallMesh, Firewall.scale / height (renderer.d:2639-2671; state.d:3690-3697). | The body of a Firewall or a Wailing Wall |
| `spells/walls/wall_rules.gd` | `WallRules` | sacengine WallPosition, isInWall, castFirewall, Firewall.scale / height (state.d:11118-11131, 19935-19966, 3690-3697). | The maths of a wall on the ground, with no tree |
| `spells/walls/wall_rules.gd` | `WallRules.in_wall()` | isInWall |  |
| `spells/walls/wall_scars.gd` | `WallScars` | sacengine FireWallRun / SpikeWallStart leave a scar (state.d:20045, 20536: "TODO: scar"). | The cracks a wall leaves in the ground as its ends advance |
| `spells/walls/wall_sound.gd` | `WallSound` | sacengine playSoundAtRange (state.d:20002, 20244, 20466). | The sound of a wall, on every peer, from its replicated age |
| `spells/walls/wall_spikes.gd` | `WallSpikes` | sacengine WallOfSpikes, makeWallOfSpikesSpike (state.d:3898-3937, 20504-20538, 20608-20662; renderer.d:2626-2655). | The spikes of a Wall of Spikes |
| `spells/walls/wall_spirit.gd` | `WallSpirit` | sacengine WailingWallSpirit, updateWailingWallSpirit, nextWailingWallTarget (state.d:3739-3758, 20126-20227, 20198-20207). | A spirit of the Wailing Wall |
| `spells/walls/wall_vines.gd` | `WallVines` | sacengine Vinewall, makeVinewallVine (state.d:3813-3873, 20336-20368, 20412-20464; renderer.d:2232-2259). | The vines of a Vinewall |
| `spells/wards/air_shield.tscn` | `casting pull (editor_description)` | sacengine animateFreezeCastingTarget | Sparks converge on the caster |
| `spells/wards/aura_impact.gd` | `AuraImpact` | sacengine ignite (fire on the victim and ign1, every 1/3 s) and the swarm's sting sound (state.d:17254-17261, 17397-17420). | The mark an aura leaves on a body it hurts |
| `spells/wards/body_aura.gd` | `BodyAura` | sacengine updateFireform, updateProtectiveSwarm, updateAirShield + pushAll (state.d:8614-8633, 17263-17295, 17376-17420, 17458-17525). | What a body does to the bodies around it while its Ward is on |
| `spells/wards/body_aura.gd` | `BodyAura._push()` | sacengine pushAll | Away from the owner's centre, full strength inside the owner's own radius, none at the… |
| `spells/wards/ethereal_form.tscn` | `Sparks / SparksCst0 (editor_description)` | sacengine etherealFormSpark (cst0); EtherealFormRun | Which burst plays on entry: NO VERIFICADO |
| `spells/wards/fireform.tscn` | `ignite sound/particles (editor_description)` | sacengine ignite | ign1 and 3 fire particles on the victim |
| `spells/wards/ward.gd` | `Ward` | sacengine lifeShield, skinOfStone, airShield, protectiveSwarm (state.d:8962-8969, 13092-13100). | One shield or temporary form of a body (Life Shield, Skin of Stone, Air Shield,… |
| `spells/wards/wards.gd` | `Wards` | sacengine effects.lifeShield / skinOfStone / ... and `shielded` (stats.d:86-90). | The one owner of «what protects this body right now» |
| `spells/wrath_strike.gd` | `wrath_strike` | sacengine state.d:10493-10506, 16386-16581; wrathExplosion, state.d:16496-16501; dealDamage, state.d:9053-9088 | Persephone's Wrath. |
| `spells/wrath_strike.gd` | `wrath_strike.FLYING_HEIGHT` | sacengine wrathFlyingHeight | Flying height. |
| `spells/wrath_strike.gd` | `wrath_strike.setup()` | sacengine animateWrath | The ball is only particles, its trail. |
| `spells/wrath_strike.gd` | `wrath_strike._physics_process()` | sacengine updateWrath (flying); state.d:16528-16562; sacengine predictCenter | Flight with accelerateTowards. |
| `spells/wrath_strike.gd` | `wrath_strike._explode()` | sacengine wrathExplosion | The direct hit gets the whole amount (DamageMod.splash), then dealSplashSpellDamageAt… |
| `spells/wrath_strike.gd` | `WrathStrike` | accelerateTowards; dealSplashSpellDamageAt | Flight and splash of Wrath |
| `spells/zones/bolt_launcher.gd` | `BoltLauncher` | sacengine updateCloudkill (state.d:22087-22101); REA CloudKillBoltRun 0x420600 (900 and a 5 m splash). | Cloudkill's bolt |
| `spells/zones/bore_drill.gd` | `BoreDrill` | sacengine updateBore, animateBore (state.d:18636-18651, 18593-18616). | The rock that bores |
| `spells/zones/bore_spiral.gd` | `BoreSpiral` | sacengine boreGetPos (state.d:18578-18591). | The path of a Bore |
| `spells/zones/bore_spiral.gd` | `BoreSpiral.ANGLE_PER_M` | sacengine: 0.2 pi of angle for each metre past the start | Turns per metre of radius. |
| `spells/zones/cloud_look.gd` | `CloudLook` | sacengine SacCloud, SacCloud2, renderCloud (sacobject.d:2778-2819, renderer.d:451-475, 1844-1853, 2477-2486). | The storm cloud of a zone, on every peer, from its replicated phase |
| `spells/zones/debris_piece.gd` | `DebrisPiece` | sacengine updateDebris (state.d:15054-15083). | A rock thrown by a blast |
| `spells/zones/drop_launcher.gd` | `DropLauncher` | sacengine updateRainOfFrogs, updateRainOfFire, makeBombardmentDrop (state.d:19387, 21121-21123, 21235-21257). | Makes the drop of a cloud |
| `spells/zones/explosion_burst.gd` | `ExplosionBurst` | sacengine explosionAnimation and animateDebris (state.d:27625-27642). | The look of one blast, played on every peer by FxBus.broadcast_scene at each point of… |
| `spells/zones/frozen_ground.tscn` | `duration (editor_description)` | sacengine forces 15 s | The SPEL says 30 s |
| `spells/zones/ground_zone.gd` | `GroundZone` | sacengine ExplosionCasting, FrozenGround, DemonicRift (state.d:3405-3655) | A place on the ground with a clock |
| `spells/zones/hole_cutter.gd` | `HoleCutter` | sacengine updateBoreHole (state.d:18653-18696), removeLandVertex (state.d:29027-29059). | The part of a Bore that opens the ground. |
| `spells/zones/ice_patch.gd` | `IcePatch` | sacengine GroundPatch and updateFrozenGround (renderer.d:3369-3411, state.d:3632-3646). | The ice of Frozen Ground as a ring of mesh glued to the land |
| `spells/zones/ice_shatter.gd` | `IceShatter` | sacengine updateFrozenGround (state.d:19882-19896). | One step of the breaking of Frozen Ground's ice, played on every peer by… |
| `spells/zones/rift_edge.gd` | `RiftEdge` | sacengine DemonicRift heightScale (state.d:19608-19635, renderer.d:2517-2598). | The mouth of a Demonic Rift |
| `spells/zones/rift_ribbon.gd` | `RiftRibbon` | sacengine DemonicRiftSpirit.locations (state.d:3527-3529, renderer.d:2517-2598). | The trail of a spirit of a Demonic Rift |
| `spells/zones/rift_spawner.gd` | `RiftSpawner` | sacengine spawnDemonicRiftSpirit, demonicRiftTarget (state.d:19530-19564). | The mouth of a Demonic Rift |
| `spells/zones/rift_spirit.gd` | `RiftSpirit` | sacengine updateDemonicRiftSpirit (state.d:19566-19606). | A spirit of a Demonic Rift |
| `spells/zones/snowball_flight.gd` | `SnowballFlight` | sacengine frozenGroundSnowballCastingPosition, updateFrozenGroundSnowball (state.d:11097-11102, 19773-19828). | The snowball of Frozen Ground, from the wizard's hands to the ground |
| `spells/zones/volcano_look.gd` | `VolcanoLook` | sacengine renderer volcanos (renderer.d:3414-3452), SacVolcanoLava.getFrame, SacVolcanoCloud.getFrame (sacobject.d:3422-3459). | What the Volcano looks like on every peer once it erupts |
| `spells/zones/zone_balls.gd` | `ZoneBalls` | sacengine updateExplosionCasting (state.d:19037-19047). | The balls of a zone |
| `spells/zones/zone_blast.gd` | `ZoneBlast` | sacengine explosion (state.d:10978-11013). | What an explosion zone does when it goes off, at each of its points |
| `spells/zones/zone_burst.gd` | `ZoneBurst` | sacengine updateVolcano (state.d:22353-22362, 22369). | What a zone lets out at one moment (or every so often) |
| `spells/zones/zone_dropper.gd` | `ZoneDropper` | sacengine updateRainOfFrogs, updateRainOfFire, updateBombardment, updateCloudkill (state.d:19367-19395, 21099-21131, 21300-21333, 22074-22108). | What a cloud lets go |
| `spells/zones/zone_dust.gd` | `ZoneDust` | sacengine animateErupt (state.d:18394-18411). | Dust that rises from the ground around a zone while it is in some of its phases |
| `spells/zones/zone_erupt.gd` | `ZoneErupt` | sacengine eruptExplosion (state.d:18440-18491). | What the ground does to the bodies on it the moment it bursts open |
| `spells/zones/zone_freeze.gd` | `ZoneFreeze` | sacengine updateFrozenGround (state.d:19831-19860). | What an ice zone does while it grows |
| `spells/zones/zone_heat.gd` | `ZoneHeat` | sacengine volcanoBurn, pushAll (state.d:22379-22403, 8614-8633). | A ring of heat around a zone |
| `spells/zones/zone_mover.gd` | `ZoneMover` | sacengine updateCloudkill (state.d:22079-22084); REA CloudKillRun 0x420a30 (speed 3, acceleration 0.3; how the acceleration enters is NOT VERIFIED). | A zone that chases its target |
| `spells/zones/zone_rules.gd` | `ZoneRules` | sacengine explosion's catapultCallback (state.d:10990-11010), FrozenGround.curRadius/minRadius (state.d:3632-3646), castExplosion (10960-10971). | The plain numbers of the ground zones, with no tree |
| `spells/zones/zone_rules.gd` | `ZoneRules.shot_velocity()` | sacengine getShotDirectionWithGravity (state.d:11506-11511). | The velocity of a shot at `speed` m/s from `start` toward `goal` that leans up to make… |
| `spells/zones/zone_shatter.gd` | `ZoneShatter` | sacengine updateFrozenGround (state.d:19863-19896). | What an ice zone does when it breaks |
| `spells/zones/zone_stun_ring.gd` | `ZoneStunRing` | sacengine updateErupt (state.d:18506-18520). | A wave that runs out from the center of the zone and stuns whoever it crosses between… |
