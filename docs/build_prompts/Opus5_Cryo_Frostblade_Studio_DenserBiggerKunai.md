# SPELLSHOT — Build Prompt #[N]: Cryo "Frostblade" (Studio tuning) — denser, bigger kunai in Flash Freeze, larger trap kunai in Flash Freeze and Deep Freeze

Continuation of the Opus 5 / Claude Code build sequence (previous: `Opus5_Cryo_FrostbladeSkin_BlenderShowcase.md`; keep [N] as a placeholder).
**Quality bar: make it genuinely amazing, and keep it a tuning pass, not a rebuild.** And be very token efficient (see the last section).

<role>
You are the Roblox Studio builder for SPELLSHOT, a Roblox PvP elemental-duel game, working for its solo developer, Sigma Boy. The Cryo "Frostblade" skin is already imported into Roblox Studio and works. Task: make its Flash Freeze and Deep Freeze kunai look bigger and fuller, in the developer's words: "make the kunais more dense and bigger, more kunais in size and density for Flash Freeze, and larger kunais for trapping in Flash Freeze and Deep Freeze". Done means: the changes are in, they pass in a Studio Play test, and the developer has one in-game screenshot of each.
</role>

<context>
**The three changes.**
1. **Flash Freeze zone field:** more kunai (denser) and each one bigger.
2. **Flash Freeze trap:** the big kunai that pass through the rooted target's body become larger. The small lodged kunai stay small.
3. **Deep Freeze trap:** its trap kunai become larger.

**Where the code lives (find it first; the code wins over this summary).** `roblox\CryoFX.lua` is full (it reached Luau's limit of 200 top-level local variables), so the Frostblade code sits inside one table or a separate module that `CryoFX` calls into. Grep for it, then read only that range and the Frostblade tuning values (counts such as the big-pierce and lodged-small counts, scales, sizes and spreads). **Change those constants first**; touch logic only if a constant cannot do it. Do not add top-level locals to `CryoFX.lua`. If a bigger kunai needs a bigger mesh scale, scale it in code before importing anything new, and say so if a new asset is genuinely needed.

**What stays exactly as it is.** The Flash Freeze and Deep Freeze footprint, zone-edge readability, timings, damage beats, the Frost Line ring, the shatter payoff's timing and fragment count, and every other Cryo piece (the M1 kunai, Mirror Cage, Cold Momentum, Blizzard). The Default Cryo look stays untouched unless Frostblade is equipped. The separate Frost Lotus skin is in progress in its own module: do not touch it. This is cosmetic only: no damage, hitbox, range, timing, fire-rate or cooldown change.

**Roblox reality for many blades.** All kunai are decorative parts: `CanCollide`, `CanQuery` and `CanTouch` false and massless, so they never block the server's raycasts or hit registration (confirm that is already how they are built). They respect Graphics Quality and Reduce Enemy VFX, and Squad Clash can have many zones and frozen targets at once.
</context>

<instructions>
1. **Find and report first, in a few lines:** where the Frostblade Flash Freeze and Deep Freeze code and constants are, and the current values (field blade count and size, big and small pierce counts and sizes, Deep Freeze trap kunai count and size), plus the current part count per Flash Freeze zone and per frozen target.

2. **Flash Freeze field: denser and bigger.** PROPOSAL: about 1.5 to 2 times the blade count and about 1.3 to 1.5 times each blade's size. Spread them evenly around the whole zone, including the front, so the zone edge still reads from every angle at a glance. No blade may be taller than the Default's tallest Flash Freeze spike (read it from `CryoTuning.lua`; the current Frostblade tallest is lower, so there is room, but do not exceed it). Blades must not hide an enemy standing in the zone.

3. **Trap kunai: larger.** PROPOSAL: the big pierce kunai in Flash Freeze about 1.5 to 2 times larger, and the Deep Freeze trap kunai about the same step up. Keep the "through the body" look (tip and ring-pommel both visible outside the body). The target's head and torso must stay clearly visible: state the visible fraction before and after, in the game camera and a ground camera. Deep Freeze keeps its target visible as in Default. First person: the larger kunai through the victim's own body must still not block their camera; confirm the existing hiding still covers them, and extend it if it does not.

4. **Tunable, then pick by eye.** Expose the new numbers as clearly named constants (for example field count, field scale, trap scale, Deep Freeze scale). Try the proposals in a Studio Play test, adjust until it looks best within the limits above, and say the final values in one line.

5. **Performance.** State parts per zone and per frozen target before and after. The denser field adds parts, so keep the scale-down: on low Graphics Quality or with Reduce Enemy VFX, use about half the field blades. Flag in one line if the after count is more than double the before count, and cap the total so many simultaneous zones stay safe.

6. **Verify in Studio Play.** Switch Frostblade on the way the project already allows for testing (say how in one line). Take one screenshot of Flash Freeze with a rooted dummy at game distance, and one of the Deep Freeze trap. Fix anything that fails the limits above before reporting.
</instructions>

<scope>
Do not change anything else: no new skins or abilities, no animation, no Loadout or catalog change, no HUD, no kill effect, no Blender rebuild, and no change to Default Cryo. Flag anything ambiguous in one line instead of deciding it, and add nothing unrequested.
</scope>

<efficiency>
The developer asked for very token efficient work. One agent, no subagents. Grep first and read only the ranges you need, and do not re-read a file after editing it. Small targeted edits of constants, not rewrites. At most two images in total (the two verification screenshots). One line before your first tool call and no narration between steps. Finish with a short report: the old and new values, the parts before and after, the visible fractions, how to switch Frostblade on for testing, and anything you flagged.
</efficiency>
