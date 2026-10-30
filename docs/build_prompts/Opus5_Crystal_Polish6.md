<role>
Five passes of adding particles to the hub crystal all failed the same way — you kept adding jagged white shard shapes and thin black scratchy lines clustered at the top, which reads as a pile of broken glass, not energy. You work for SPELLSHOT's solo owner-developer. Scrap that particle approach entirely and build a new effect: inner glow + soft corona. Done means the crystal visibly glows from within and has a soft halo of light around it, with no angular shard/debris particles anywhere in the new effect.
</role>

<context>
**Root cause of the last five misses:** every pass added more of the same angular low-poly shard geometry — the same style already used for the orbiting rock chunks — instead of something soft and glowing. That's why it kept looking like debris no matter how much or how little was added. The fix isn't more or less of that effect, it's a completely different technique that never uses sharp angular shapes.

**The new effect, in two parts:**
1. **Inner glow:** the crystal itself should visibly glow from within — a soft pulsing light visible through its black/white facets, like there's a light source inside it slowly breathing (brightening and dimming on a slow cycle). This is a material/lighting change on the crystal, not a particle effect.
2. **Soft corona:** a faint halo/nimbus of light surrounding the crystal — soft-edged, round, glowing, like a gentle aura or light bloom around its silhouette. No discrete shard or line shapes of any kind. If any particles are used at all for the corona, they must be soft round gradient sprites (the classic soft "glow dot" look), small and numerous rather than large and jagged, and never angular geometry.

Keep the ring of orbiting rock chunks exactly as it is — that part already works and isn't part of this change.
</context>

<instructions>
1. Remove the current shard/line particle effect entirely before building the new one — don't layer the new effect on top of the old.
2. Build the inner glow as a pulsing emissive/translucent material effect on the crystal itself.
3. Build the soft corona as a soft-edged glow/bloom around the crystal's silhouette — round and diffuse, not sharp-edged or angular, and not shaped like the existing rock chunks.
4. Aim for genuinely polished quality here: smooth gradients, no visible hard edges or low-res blur, a believable soft light bloom — this should look like a finished effect, not a placeholder.
5. Leave the ring, rock chunks, and crystal's base black/white material untouched.
</instructions>

<output_format>
- One line before you start.
- Before/after shot of the crystal.
- One short confirmation line.
</output_format>

<tone_preference>
Short and factual. Be efficient — minimize exploration, keep the report brief.
</tone_preference>
