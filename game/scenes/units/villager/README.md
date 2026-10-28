# units/villager
What: a villager is a unit that never fights: with a shelter near it works, a scare makes it flee, a hit makes it run from who hit it, and with no shelter it cowers.
Not: how a unit walks or hits (`units/`), who attacks villagers (the AI), the sides (`SideRelations`).
Talks to: `VillagerSenses` answers (closest shelter, closest scare, panic) and says `panicked`; `VillagerBrain` (an `FsmMachine`) thinks every `think_interval_s` and moves between its four state nodes; `GrudgeMemory` keeps the sides that hurt the herd.
Edit: `villager.tscn` -> `Brain` (`think_interval_s`, `flee_leg_m`, `panic_leg_m`, `work_role`) · `Senses` (`shelter_distance`, `scare_distance`, `panic_s`) · drop a `VillagerState` node under `Brain` for a new state.
