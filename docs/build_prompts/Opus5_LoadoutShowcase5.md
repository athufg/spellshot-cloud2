<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. The Loadout Showcase (dedicated chamber, pedestal centerpiece, element rail, two-dummy move preview) exists and mostly works, but has confirmed bugs and still looks and feels basic in several places. This pass fixes every bug, adds the missing Skins system, and pushes the whole feature to a genuinely flagship bar — the kind of thing a player screenshots and shows friends. Done means every bug below is gone, Skins work end to end alongside Wraps, and the chamber, pedestal, and UI all read as deliberately designed rather than functional placeholders — verified across every element that actually exists in the game, not just the ones caught on camera so far.
</role>

<context>
**What's already working — don't rebuild these, extend them:** the dedicated showcase chamber itself (already replaced the old reused-hub-hallway version), the two-dummy combat preview (a caster dummy triggers the real in-game ability logic and a target dummy takes the real hit reaction — not faked animations), and per-element chamber lighting, which already shifts color convincingly per element (Cryo reads cyan, Pyro red/orange, Voltaic yellow, Umbra purple, Aqua blue, Zephyr teal).

**Element roster correction:** earlier guidance assumed 6 elements. Review footage confirms at least nine actually exist — Pyro, Cryo, Terra, Radiant, Voltaic, Zephyr, Aqua, Umbra, Toxin — and there may be more. Pull the live list from wherever the game's element data actually lives (don't hardcode a list anywhere in this feature), so every element gets full treatment automatically and nothing needs updating by hand later, including elements added after this build.

**SPELLSHOT has two separate cosmetic systems**, and this showcase currently only surfaces one of them. Wraps are recolors/material changes applied to an Element's existing kit — that's what's shown today. Skins are full model reworks of an Element's entire kit at a rarity tier (Uncommon/Rare/Epic/Mythic) — a separate, bigger system that currently has no presence in this showcase at all.
</context>

<instructions>

**Part 1 — Bugs. Fix all of these; they're blocking the feature from reading as finished:**

1. Camera drag-to-orbit on the centerpiece doesn't respond to input at all right now — the display is static. Wire it up properly: click-drag rotates the displayed item, and releasing should ease the spin down rather than stopping dead, so it feels like you're handling something physical rather than dragging a flat slider.

2. Pyro's M1 projectile renders as a plain black unlit sphere sitting on the pedestal — no fire material, no particles, nothing. Every other element's M1 currently displays correctly, so find what's specifically different about how Pyro's instance is being set up for this display (wrong material reference, missing particle emitter enable, wrong VFX template pulled) and fix the root cause rather than hand-placing a one-off patch.

3. Cryo's M1 projectile is mispositioned, floating off in the top-left corner of the screen instead of centered above the pedestal like every other element.

4. There's a visible flicker/black seam around the circular floor ring, and it lines up with Studio console warnings about EditableMesh hitting its memory budget. Whatever's generating that warning (most likely the floor ring geometry, possibly a transition effect) is being built as a runtime EditableMesh when it doesn't need to be dynamic — rebuild it as static geometry instead, which should kill both the warning and the flicker.

5. Radiant: during Preview Moves, the ability's VFX plays correctly but the caster dummy isn't holding the staff accessory that move is supposed to show. The preview is triggering the ability logic but not attaching the held item that goes with it — fix the preview trigger to equip whatever accessory that move normally requires.

6. Sweep every element in the dynamic roster (not just the handful already confirmed) and verify the two-dummy preview actually fires both the cast and the hit-reaction correctly for each one. Treat any element where it doesn't as the same class of bug as items 2, 3, and 5, even if it wasn't caught on camera yet.

**Part 2 — Skins. This system doesn't exist in the showcase yet; build it:**

7. Add a "Skins" tab alongside the existing "Wraps" tab in the side panel, using the same tab-switch interaction pattern already established there. Selecting a Skin shows that Skin's fully reworked M1 on the centerpiece (not the base kit's M1 reskinned — the Skin's actual model/VFX) and its reworked move VFX in the two-dummy preview, exactly parallel to how Wraps already drive the centerpiece and preview. If an element has no Skin yet, show its Skins tab as empty/locked using whatever locked-content styling SPELLSHOT already uses elsewhere, rather than inventing a new empty-state design.

**Part 3 — Polish. The feature works now; make it look like it belongs in a flagship game:**

8. **Pedestal.** It's currently a plain black disc no matter what's displayed. Give it material and glow that react to the selected element — its identity color should visibly inform the pedestal, not just the item floating above it, so the whole display reads as one composed piece instead of a generic stand with a prop on top.

9. **UI side panel — the single most basic-looking part of this feature right now.** It's flat colored bars with plain text. Rebuild it with real visual craft: a distinct icon per element/wrap/skin row instead of a flat color block, a selected/hover state with actual presence (glow, scale, or border treatment — not just a thin outline that's easy to miss), and a panel frame/border treatment that matches the polish level already established in SPELLSHOT's other UI (the interact-prompt UI and the wrap pedestal's own UI are good references for the bar to hit). This panel should look like it was designed for this feature specifically, not assembled from default list items.

10. **Whole-feature pass.** Once the bugs are fixed and Skins exist, look at the chamber, lighting, pedestal, and UI together as one composed scene rather than as separate pieces, and push whichever parts still feel underbuilt relative to the others. The goal is a showcase that feels considered in every direction the camera can see, not just correct in the parts that were explicitly called out.

</instructions>

<output_format>
Before starting, say in one line what you're about to work through, after confirming you've found the root cause of each named bug (not just a surface symptom).

When done, deliver a clip or screenshot sequence covering: Pyro's and Cryo's M1 displaying correctly, manual orbit responding smoothly with easing, the floor ring with no flicker, Radiant's staff appearing during its move preview, the new Skins tab switching correctly for at least two elements, and the upgraded pedestal/UI treatment. Follow with a short list of what was fixed, what was newly built, and what was polished, plus any judgment calls you made on the visual direction and why.
</output_format>

<edge_cases>
If sweeping the full element roster (item 6) surfaces a bug not listed above, fix it using the same standard as the named bugs rather than leaving it for a future pass. If an element's Skin doesn't exist, its Skins tab entry should read as intentionally locked, not broken or empty by omission. If the pedestal or UI work in Part 3 reveals that the underlying M1/pedestal rig needs a structural change to support per-element material reactivity, make that change rather than faking it with a one-off per element.
</edge_cases>

<tone_preference>
This is worth real care — don't settle for the first version that technically satisfies an instruction. Where something is left to your judgment (an element's VFX language, the UI's exact visual treatment), choose what would look best in SPELLSHOT's existing comic/pop-art style and say what you chose and why, rather than defaulting silently to the simplest option.
</tone_preference>
