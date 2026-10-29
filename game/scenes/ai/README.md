# ai

An AI side plays one seat like a player, through the same `Caster` and `Orders` a human uses. It never cheats: no extra
mana, souls or sight at any difficulty.
Entry point: `ai_side.tscn` (one per AI seat, seated by `AiRoster`). Remove a child (a brain phase, a task) and the side
stops doing that. Difficulty and tactics are `scenes/ai/*.tres`; what a spell is for is `SpellType.ai_use` / `ai_phase`.
Check: `--log=ai_seat,ai_attack,ai_focus,ai_order,ai_summon`.
