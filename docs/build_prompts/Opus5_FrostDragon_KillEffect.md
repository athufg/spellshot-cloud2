# SPELLSHOT — Build Prompt #[N]: Frost Dragon Kill Effect, "Dragon's Pass" (Mythic)

Continuation of the Opus 5 / Claude Code build sequence (previous: the Frost Dragon Blizzard and Flash Freeze stages; filename unknown).
This is visual/VFX work: real reference before styling, checkpoint before final. Make it amazing.

<role>
You are building the kill effect for the Cryo "Frost Dragon" skin in SPELLSHOT, a Roblox PvP elemental-duel FPS, for the solo developer. Frost Dragon is the Mythic skin, the top of Cryo's cosmetic ladder: Mythic = everything Epic has, plus a kill effect, plus an avatar change. This task is the kill effect only. The avatar change is deferred and out of scope. You are done when the kill effect "Dragon's Pass" exists, the user approved the checkpoint, and it is wired as the Frost Dragon's kill effect the same way the game wires any kill effect.
</role>

<token_budget>
Be efficient with tokens. One agent, no subagents. Use targeted searches and function-level reads, never whole-file or whole-repo reads. Reuse the approved dragon assets and the Blizzard ghost treatment; do not rebuild them. View at most three images in total. Keep progress notes to a line and the report short.
</token_budget>

<context>
- **Check first (text only, 8 lines at most):** is there an existing kill-effect or death-effect system? Find with targeted searches how a kill is detected and shown today: the server event, which clients get it (killer, victim, bystanders), what the victim's character does on death (ragdoll, fade, vanish), whether any other skin has a kill effect, and where a skin-specific one would hook in. If **no kill-effect system exists, or hooking one in needs more than a small module and one hook**, stop and describe the smallest option, then wait for my choice. Otherwise say so in one line and continue.
- **The dragon:** the approved Frost Dragon model, in the white outline-ghost look already used for the Blizzard dragons (a lean western dragon of glowing ice crystal; faceted scales, crystal horns and spine ridge, white-hot cyan eyes). Reuse that asset and treatment exactly: same shape, same ghost style. Wing animation: reuse the Blizzard wing rig. Do not redesign the dragon.
- **Scale plates:** the cage ult has dragon-scale plates (faceted crystal plates). Reuse that plate mesh for the shatter shards, so the effect belongs to the same creature.
- **Palette:** pale luminous ice dominant, cyan glow, white-hot edges, deep blue only as shading. Cryo blues and whites only: no gold or amber (the Ultimate UI colour), no pink or magenta (Sparks).
- **Engine rules:** parts Massless, CanCollide, CanQuery and CanTouch false, cosmetic only. Every emitter through `emitter()`. Reduce Flashing, Reduce Enemy VFX, Graphics Quality and Colourblind-Safe settings apply. Pool everything. Mobile budget: assumed Mythic cap about 2x Default (flag it). `CryoFX.lua` is at Luau's 200 top-level-locals limit: all new code goes in a separate module. Use `RegisterProximityFade` for parts near the camera.
- The code wins on how something works today, and the manual (v0.24) wins on what it should do. Say so in your report if they disagree.
</context>

<design>
**Dragon's Pass.** On a kill, a ghostly ice dragon streaks through the victim's position, the victim freezes as it passes, and then the frozen body shatters upward into dragon-scale crystal. Total about 1.5 s. Beat by beat (times are proposals; tune and report):

1. **0.00 to 0.25 s, the approach.** A frost ripple spreads under the victim and a gust cue (a few crescent streaks) shows the direction. The dragon appears at one side of the victim, about 14 studs away and at chest height, wings fully spread, already moving. It is about twice the victim's height long. It forms out of frost mist in the first few frames, so it does not pop in.
2. **0.25 to 0.50 s, the pass.** The dragon crosses the victim's position fast and low, in a clean glide with one slow, heavy wing downstroke as it crosses (reuse the Blizzard wing rig; body stays level). Its path is **sideways across the killer's view** (perpendicular to the line from the killer to the victim), never toward or through the killer's camera. A wake of frost mist, snow and crescent wind streaks trails behind it.
3. **At the crossing (about 0.35 s), the freeze.** Frost climbs the victim from the feet to the head in about 0.15 s and seals them in a shell of scale-faceted crystal, like dragon-scale armour made of ice, glowing from inside. The shell is a client-side visual that replaces the victim's character appearance (use LocalTransparencyModifier or the project's existing death-visual method; no gameplay change).
4. **0.50 to 0.65 s, the exit.** The dragon exits the other side and dissolves into drifting frost mist. As it leaves, white-hot cracks run across the shell along the scale lines.
5. **0.65 to 1.30 s, the shatter.** The shell bursts upward: dragon-scale shards (the cage scale plate mesh) rise 3 to 5 studs with a slow spin, glinting, and fade out into frost mist and a few snow glints by about 1.4 s. A soft bright ring of light at the burst (no full-screen flash).
6. **1.30 to 1.50 s, the settle.** A faint frost ring on the ground fades out. Nothing persists after about 1.5 s.

Make it look amazing: a crisp readable silhouette on the pass, a satisfying snap at the freeze, and a beautiful, clean shatter. It must look clearly cooler than anything an Epic skin has, and it should be the most spectacular use of the whole dragon.

**Visibility and safety:**
- The dragon's path never crosses the killer's camera. Fade the dragon parts near any camera (`RegisterProximityFade`).
- No full-screen flash. No camera shake. Brightness changes are smooth (no strobing).
- Nothing blocks any player's view for more than a moment, and nothing persists after about 1.5 s.
- Who sees it: exactly the clients that see the Default death today (from the check above). Do not send a heavier effect to far-away clients.

**Settings:**
- Reduce Flashing: no flash ring, smooth brightness, no pulsing.
- Reduce Enemy VFX: when the killer is an enemy, show a reduced version (shell and shards, dimmer and smaller dragon or no dragon: flag your choice).
- Graphics Quality: scale the shard count, mist and snow density down. Report the counts at each level.
- Colourblind-Safe: keep it readable, with no reliance on colour alone.
- Mobile: report the total parts and particles at peak and the pooling plan against the cap above.
</design>

<instructions>
1. **Check (text only):** the kill-effect system check from `<context>`.
2. **Build** the effect as a separate module with one hook into the existing kill flow. Reuse the approved dragon model and ghost treatment, the Blizzard wing rig, and the cage scale-plate mesh. Add no new geometry unless something is missing, and say what.
3. **Checkpoint (three images at most):**
   (a) one eight-frame strip from the killer's view at normal 1v1 distance across the whole 1.5 s;
   (b) one close-up of the freeze-and-shatter frames;
   (c) one side view of the pass showing the dragon's path against the camera line.
   Then say in four lines: total duration, peak parts and particles against the cap, behaviour with Reduce Flashing, Reduce Enemy VFX and the lowest Graphics Quality, and whether the dragon ever comes within camera-fade distance. Say yes or no: the dragon reads clearly, the freeze is satisfying, the shatter is clean, nothing blocks anyone's view, it is clearly cooler than the Default death. Stop for approval. Do not wire it up yet.
4. After approval, wire it as the Frost Dragon's kill effect the same way the game wires any kill effect. Add nothing else.
</instructions>

<rules>
Cosmetic only: no gameplay value, timing or hitbox changes. All emitters through `emitter()`. No avatar change, no Deep Freeze, no HUD, health-bar or icon changes, no new callout words. Make routine judgment calls yourself and list them. Flag anything ambiguous instead of deciding it, and add nothing that was not asked for.
</rules>

<output_format>
Step 1: the short text note. Step 3: the checkpoint images plus the four-line note. Final report in a few lines: the module and hook locations, how the victim's appearance is replaced, the counts against the cap, what was wired, and anything flagged.
</output_format>
