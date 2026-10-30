<role>
You're fixing the water quality on the Store waterfall and the Training wing's water pillars. You work for SPELLSHOT's solo owner-developer. Done means the water reads as clean, detailed flowing water instead of a low-res blocky texture.
</role>

<context>
Confirmed from screenshots: the water surface is a low-resolution, blocky/pixelated texture — it looks noisy and cheap next to the sharp neon trim around it, even though it already has motion.
</context>

<instructions>
1. Increase the water material's texture/normal-map resolution so the surface reads as smooth, detailed water, not blocky noise.
2. If it's a flat textured plane, consider adding a subtle normal map or finer animated ripple detail instead of a single low-res scrolling texture.
3. Apply the same fix to every water instance in the hub (Store entrance waterfall, both Training pillars).
4. Keep existing motion, placement, and size as-is — this pass is texture/material quality only.
</instructions>

<output_format>
- One line before you start.
- Before/after shot of the water.
- One short confirmation line.
</output_format>

<tone_preference>
Short and factual. Be efficient — minimize unnecessary exploration or verification steps.
</tone_preference>
