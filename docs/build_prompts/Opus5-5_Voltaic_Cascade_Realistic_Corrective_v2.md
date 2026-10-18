<role>
You are the Blender/VFX builder for SPELLSHOT, a Roblox PvP elemental-duel game. This is a corrective pass on
Cascade, the Ultimate ability of the Voltaic (lightning) Element. The previous build
(`Opus5-5_Voltaic_Cascade_Realistic_Build.md`) is already in the game and was playtested in Roblox Studio. The
developer reviewed that playtest and has three specific, concrete fixes. You're working for the game's solo
developer, who will review your rendered output after you finish rather than answering questions mid-build, so
the deliverable needs to stand on its own. Done means: the three fixes below are built into the existing Cascade
effect, and a Blender render of the complete five-beat sequence is ready to hand back — not a Roblox Studio
capture.
</role>

<context>
`Opus5-5_Voltaic_Cascade_Realistic_Build.md` is still the authority for everything about Cascade this document
doesn't mention: the five-beat structure and timing, the reference images (`cascade_final_vision_sheet_v2.png`
and `cascade_animation_energy_reference.png`), the color rules (cloud near-black violet with a lighter violet
core glow; all lightning, sparks, and bursts in Voltaic's actual yellow, `#F5C70F` / `#FFF573`), the performance
budget, and the scope boundary (Cascade only — don't touch Chain Bolt, Railspike, Overcharge, or Ground Surge).
Read that document in full before starting. This pass doesn't change any of that — it fixes three specific
execution problems the developer found in the actual playtest result.

The playtest screenshot is saved as `cascade_realistic_v1_studio_test.png` in the project's SPELLSHOT folder —
look at it before starting so you're fixing the actual problem, not a guess at it. Two things are visibly wrong
in it: the cloud reads as thin, see-through smoke with the sky visible through and around it, rather than a
dense storm mass, and the lightning bolts, while correctly yellow, look dim and thin rather than striking.
</context>

<instructions>
Three fixes, all to the existing Cascade build — don't rebuild the whole sequence from scratch:

**1. Make the cloud read as solid, not transparent smoke.** Right now the charged-hold cloud looks like wispy
see-through smoke — you can see the sky through gaps in it. It needs to read as a dense, opaque-feeling storm
mass, the way real thunderheads do (you don't see through a thunderhead, even though it's technically made of
water vapor). Concretely:
   - Significantly lower the alpha/transparency on the outer smoke `ParticleEmitter`s — they should be much
     closer to opaque, not the soft translucent wisps currently in place. Real storm clouds read as solid at a
     distance even though they're built from soft-edged material up close.
   - Increase particle density and overlap so there are no visible gaps in the silhouette — more overlapping
     puffs, packed tighter, so sky doesn't show through the body of the cloud at any point during the charged
     hold.
   - Consider adding a solid (or near-solid, high-alpha) mesh or particle core underneath the soft particle
     surface detail, so the cloud has genuine mass at its center and the translucent particles are just surface
     texture on top of something solid, not the entire volume. This is a legitimate technique tradeoff — state
     which approach you took and why.
   - The lighter-violet internal glow should still show through, but only at the gaps/seams between lobes as
     already specified, not uniformly through the whole body — right now the whole cloud reads as uniformly
     see-through, which reads as smoke instead of storm. Fix the general transparency first; the internal glow
     is a highlight, not the cloud's baseline opacity.

**2. Make the lightning brighter and better-looking.** The bolts are the right color but read as dim and thin in
the playtest. Concretely:
   - Increase the brightness/intensity of both beams — the bright `#FFF573` core beam and the wider `#F5C70F`
     glow beam behind it. If the `Neon` material or beam `Brightness`/`LightEmission` properties are set
     conservatively, push them up meaningfully; this is meant to be the flashiest moment of the sequence.
   - Thicken the bolt core so it reads clearly at gameplay camera distance, not just up close — compare against
     Chain Bolt and Railspike's established bolt weight as a reference point, same as the original build
     instructions asked.
   - Strengthen the dynamic `PointLight` at each strike's landing point — brighter intensity and a larger range
     so the flash genuinely lights up nearby geometry and reads as impactful, not a faint glow.
   - Check that the `Bloom`/`ColorCorrection` pulse at release is actually contributing visible punch to the
     bolts rather than being too subtle to register — this is the one moment in the sequence allowed to hit hard.

**3. Show the result in Blender, not Roblox Studio.** The review artifact needs to be a Blender render of the
full five-beat sequence, not an in-Studio gameplay capture (the kind of screenshot in
`cascade_realistic_v1_studio_test.png`). Build/preview the corrected effect in Blender and render it there —
same as the original realistic-build prompt's output format asked for. If the effect currently only exists as
live Roblox particles/beams/lights with no Blender-side representation to render, recreate the corrected version
in Blender specifically for this render, matching the in-game parameters you land on.

Report the specific values you change (transparency/alpha numbers, particle density, beam brightness, light
intensity) against what they were before, so the developer can see exactly what moved.
</instructions>

<tools>
Use your Blender MCP tooling to rebuild the corrected charged-hold cloud and release-beat lightning, and to
render the full sequence. Reference `cascade_realistic_v1_studio_test.png` directly when judging whether the
transparency and brightness fixes have actually resolved the problem — compare your in-progress result against
it rather than assuming a parameter change was enough.
</tools>

<output_format>
The primary deliverable is a Blender-rendered clip covering all five beats in order, at actual gameplay camera
distance and scale. Lead your final report with that render, then list: the transparency/density values you
changed for the cloud and why, the brightness/intensity values you changed for the lightning and lights, and
confirmation that the render is from Blender, not a Roblox Studio capture. Keep the written report proportional
to what's needed to convey this — the render is the deliverable.
</output_format>

<edge_cases>
If lowering cloud transparency enough to read as solid costs noticeably more on the performance budget from the
original build prompt, make the call yourself and report the tradeoff rather than asking mid-build. If the
existing Cascade build has no Blender-side source to re-render from, say so and rebuild the corrected version in
Blender rather than guessing at a workaround.
</edge_cases>

<scope>
In scope: the cloud's transparency/density/opacity, the lightning's brightness/beam and light intensity, and
producing a Blender render of the corrected sequence. Not in scope: any change to the five-beat timing, the
color values, the mechanic, or any other Voltaic piece — this is a targeted fix to the two visual problems named
above, not a redesign.
</scope>

<tone_preference>
Keep your final written report reasonably concise. Say one line before your first tool call naming what you're
about to do.
</tone_preference>
