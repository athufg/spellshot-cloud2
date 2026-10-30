# SPELLSHOT — Sound Effects Needs Audit (2026-10-26)

Source: `SPELLSHOT_Design_Manual.md` v0.23 (the CoWork copy, 2026-10-13), read in full. Studio check: 10 tool calls. The only live audio is Roblox's default character sounds plus 4 Cryo sounds in `ReplicatedStorage.IceMagic.Sounds`, and `SettingsRuntime` already routes sounds into volume groups. "No" means I found no Sound instance and no SoundId in any live script; `ServerStorage` was not scanned.

| Category | Sound Need | Trigger Pattern (×N if collapsed) | Priority | Studio Status |
|---|---|---|---|---|
| UI & Menus | Button press / hover | Any menu button (Hub screens, Loadout, Shop, Settings) | High | No |
| UI & Menus | Tab / screen switch | Screen open/close and tab change (Quick Play, Shop, Loadout, Settings) | High | No |
| UI & Menus | Notification pop-up | One shared pop-up for system notices (Contract done, unlock, event start, trade request) | High | No |
| UI & Menus | Purchase denied / error | Too few Sparks, a failed or cancelled purchase | High | No |
| UI & Menus | Sparks gain tick | Sparks added (match end, daily login, Contracts) | High | No |
| UI & Menus | Loadout equip | Element or Technique picked at the altar (×9 Elements, up to 3 Technique slots) | High | No |
| UI & Menus | Loadout change rejected | A change tried during a live match (loadout lock) | Nice-to-have | No |
| Elements & Abilities | M1 cast / fire | ×9 (8 launch + Aqua), Element-specific. Note: Aqua is post-launch and the Manual says it isn't built yet | Critical | Partial (Cryo only) |
| Elements & Abilities | M1 in flight / beam loop | ×9: travelling shots, and Light Lance's held beam | High | No |
| Elements & Abilities | M1 charge-up / release | ×3: Boulder Shot hold, Shadow Dart 2.3 s charge, Light Lance damage ramp | High | No |
| Elements & Abilities | M1 impact | ×9, Element-specific (splash, pierce, chain, etc.) | Critical | Partial (Cryo only) |
| Elements & Abilities | Primary cast | ×9, including the self-buffs (Immolate, Overcharge, Blessing) | Critical | Partial (Cryo only) |
| Elements & Abilities | Primary impact / payoff | ×9 where it lands: Flash Freeze root then shatter, Bulwark knockdown, Cross-Slash slashes, Undertow snap, bubble-to-cloud conversion, Shadow Step reform | Critical | Partial (Cryo only) |
| Elements & Abilities | Primary charge-up | ×1: Cross-Slash Dash, hold to charge | High | No |
| Elements & Abilities | Passive trigger | ×9, each a different event: kill refund, speed burst, stationary bonus, shield stack, Updraft, Unseen bonus, Overflow Light conversion, lifesteal, trail slip | Nice-to-have | No |
| Elements & Abilities | Ultimate charged / ready | ×1 shared: charge reaches full from damage dealt or taken | Critical | No |
| Elements & Abilities | Ultimate windup / telegraph | ×8 with a windup: Ring of Fire trace and snap, Eclipse 1.0 s, Halo spiral, Cyclone forming 1.2 s, Patient Zero speeding-up countdown, Mirror Cage, Seismic Slam, Leviathan's Maw. Thunderclap is instant. Note: the Manual's table still says Cryo Beam but v0.11 replaced it with Mirror Cage, and Terra's Ultimate is Seismic Slam in the table but "Fault Line" in the Reactions text | Critical | Partial (Cryo only) |
| Elements & Abilities | Ultimate payoff / impact | ×9, including Leviathan's shark-bite finish | Critical | Partial (Cryo only) |
| Elements & Abilities | Ultimate sustained loop | ×4 Ultimates with a duration: Eclipse's 7 s domain, Halo active, Cyclone 4 s, Leviathan's tank | High | No |
| Elements & Abilities | Technique activation | About ×14 instant casts (shared pool plus Element-own): Tremor Vault, Position Trade, Bulwark Wall, Decoy Double, Mark, Acid Rain, Antitoxin Vent, Twin Tide, Sidearm, Deep Freeze, Blizzard, etc. Note: the pool table still lists Frost Slide and Chill Aura, which v0.11 retired | High | No |
| Elements & Abilities | Technique sustained loop | ×6 held or area Techniques: Blizzard, Chill Aura, Benediction channel, Gust Jump float/glide, Antitoxin Vent active, Acid Rain | Nice-to-have | No |
| Elements & Abilities | Technique conditional payoff | ×5: Deflect Gust reflect (and the miss), Deep Freeze triggered, Decoy Double broken, Bulwark Wall block/break, Sidearm charged knock-up | High | No |
| Elements & Abilities | Mark stacks / expiry / headshot | Stack ripens ×3, mark expires, headshot bonus with the HUNTED! pop. Note: this is the game's only headshot detection | High | No |
| Elements & Abilities | Technique end / expire | About ×6 Techniques with a duration ending | Nice-to-have | No |
| Elements & Abilities | Cast refused | Not enough Mana, or on cooldown (any Primary or Technique) | High | No |
| Elements & Abilities | Ability ready again | Primary or Technique comes off cooldown (×4 slots) | Nice-to-have | No |
| Status Effects | Status applied / stacked | ×7 on the status HUD system: Burn, Chill, Poison, Charged, Cracked, Wet, Blessed | High | No |
| Status Effects | Damage-over-time tick | ×2: Burn, Poison | High | No |
| Status Effects | Max-stack climax | ×3: Chill reaches 3 and roots, Charged auto-discharges a chain, Wet causes steering loss | Critical | No |
| Status Effects | Status refresh / expire | ×7: refresh on reapply, expire (about 5 s stacking, about 8 s primed) | Nice-to-have | No |
| Elemental Reactions | Reaction ends the status (burst) | ×4: Melt, Combustion, Shatter, Overload | Critical | No |
| Elemental Reactions | Reaction turns into a new status | ×1: Frozen (Wet + Chill become a stronger Root) | High | No |
| Elemental Reactions | Reaction strengthens the status | ×5: Wildfire, Windchill, Storm Surge, Dust Storm, Windswept. The last 3 are working names | High | No |
| Elemental Reactions | Reaction in the world only | ×1: Toxic Squall (the cloud grows) | Nice-to-have | No |
| Combat Feedback | Hit marker (dealt) | Any damaging hit you land, every source | Critical | No |
| Combat Feedback | Damage taken | Any hit you receive | Critical | No |
| Combat Feedback | Shield absorb / break | ×3: Blessing, Terra's Passive shield, Bulwark Charge damage reduction | High | No |
| Combat Feedback | Heal received | ×4: Benediction, Overflow Light, Halo, Toxin lifesteal (the only healing, since health never regenerates) | High | No |
| Combat Feedback | Low-health warning | Own health low | High | No |
| Combat Feedback | Knockback / knockdown received | ×4: Bulwark Charge, Seismic Slam, Overload stagger, Sidearm launch | High | No |
| Combat Feedback | Kill confirmation (killer) | Server-confirmed kill | Critical | No |
| Combat Feedback | Elimination / death (victim) | Health reaches 0, including falls (Skyline's fatal drop) | Critical | Partial (Roblox default death sound, handled by `DeathFX`) |
| Combat Feedback | Ragdoll body impact | The thrown body hits the ground | Nice-to-have | No |
| Combat Feedback | Kill effect, basic | 2 beats: the KO! burst on the kill, then the ink puff when the body clears (about 3 s) | Critical | No |
| Combat Feedback | Kill effect, special | 2 beats ×N: every Mythic Element Skin and every Character skin bundle | High | No |
| Combat Feedback | Respawn | New body after a respawn (Rift Royale respawns continuously; Duel rounds start on a fresh body) | High | No |
| Movement | Footsteps | Automatic sprint and crouch-walk, per surface | High | Partial (Roblox default, plastic footstep only) |
| Movement | Jump / double jump | Everyone's double jump | High | Partial (Roblox default jump) |
| Movement | Land | Landing after a jump or fall | High | Partial (Roblox default landing) |
| Movement | Crouch | Crouch down / stand up | Nice-to-have | No |
| Movement | Slide start / loop / end | Slide up to 1.1 s; it ends on release, a wall or leaving the ground | High | Partial (`SFX_Slide` exists) |
| Movement | Slide-jump | Jump out of a slide | Nice-to-have | No |
| Movement | Ability movement whoosh | ×7: Overcharge, Cross-Slash, Shadow Step, Bulwark Charge, Tremor Vault, Position Trade, Gust Jump air jumps/glide. Note: may share sounds with the ability rows | High | No |
| Economy & Progression | Cache open, rarity reveal | ×2 Caches (Elemental, Accessory) × 4 tiers (Uncommon, Rare, Epic, Mythic). A Mythic pull needs to be a distinctly bigger moment | Critical | No |
| Economy & Progression | Purchase success (Sparks or Robux) | ×N item types: Wraps, Element Skins, Character skins, Technique reskins/Looks, unlocks, Keys, Sparks, Rift Pass | Critical | No |
| Economy & Progression | Element / Technique unlocked | ×9 Elements and 12+ Techniques, via level, Mastery 3, Sparks or Robux | High | No |
| Economy & Progression | Account level up | Casual XP, cap about 30 | High | No |
| Economy & Progression | Mastery rank up | ×9 Elements; milestones at 3 (Technique unlock), 5/10/15 (trims) and 20 (emblem) | High | No |
| Economy & Progression | Name card milestone | ×9 Elements × 3 milestones | Nice-to-have | No |
| Economy & Progression | Rift Pass tier up | Free and premium tracks | High | No |
| Economy & Progression | Ranked promotion / demotion | 6 tiers (Ember to Ascendant) with sub-ranks, plus season-end rewards. Note: Ranked opens later, per the roadmap | High | No |
| Economy & Progression | Contract progress / complete | Daily (2–3) and the weekly line | High | No |
| Economy & Progression | Daily login streak claim | Daily | Nice-to-have | No |
| Economy & Progression | Mana Shards earned / Attunement upgrade bought | Earned per round; spent in the pre-round phase | High | No |
| Match Flow | Queue join / leave / match found | Quick Play (Duel, 2v2, Squad Clash, Convergence) | High | No |
| Match Flow | Map vote open / cast / result | Every match; a tie is a coin flip | High | No |
| Match Flow | Attunement Phase open / close | Before each round | High | No |
| Match Flow | Round countdown / start | Every round (first to 5; Squad Clash first to 6) | Critical | No |
| Match Flow | Round end, won / lost | Every round | Critical | No |
| Match Flow | Victory / defeat | Match end | Critical | No |
| Match Flow | Squad Clash Ley Line Core | Channel start, progress, contested, complete (wins the round) | Critical | No |
| Match Flow | Return to Hub | After every match | Nice-to-have | No |
| Match Flow | Convergence event start | Weekly 60–90 min window with boosted Caches | Nice-to-have | No |
| Social & Trading | Duel Pad challenge | Stepping on a pad next to a player starts an instant 1v1 | High | No |
| Social & Trading | Party invite / party formed | Party queue | Nice-to-have | No |
| Social & Trading | Trade request / offer change / complete | Trading flow (items tradeable after the 3-day hold) | High | No |
| Social & Trading | Highlight Reel captured | Automatic clip at match end | Nice-to-have | No |
| Social & Trading | Attunement License complete | The safe-trading tutorial before a first trade | Nice-to-have | No |
| Onboarding | Tutorial step cue | ×4 lessons in the bot matches: M1, Primary, Technique, Ultimate | Nice-to-have | No |
| Ambience/Background | Per-map ambience | ×7: the Manual's 5 maps (Training Ground, Neon City, Bastion, Skyline, Elemental Quarry), the Hub, and the Training Grounds island. Note: the maps are documented, the ambience isn't | Nice-to-have | No |
| Ambience/Background | Music (menu / match) | Note: not documented anywhere in the Manual | Nice-to-have | No |
| Ambience/Background | Spectating | Note: only a Season 4 roadmap item, not designed | Nice-to-have | Not checked |
