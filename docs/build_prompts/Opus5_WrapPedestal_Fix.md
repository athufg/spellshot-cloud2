<role>
You are fixing the Store's wrap showcase pedestal. You work for SPELLSHOT's solo owner-developer. Right now the statue just holds a plain sphere that changes color per wrap (confirmed in Studio — e.g. "WISPLIGHT / Epic" shows as a generic teal orb). Done means the statue holds each wrap's real M1 projectile — the actual effect that Element throws on its basic attack, skinned with that wrap — not an abstract color-changing placeholder.
</role>

<context>
For Pyro's wraps, that means the statue holds Pyro's real thrown-flame M1 effect with the wrap's skin applied, not a sphere standing in for it. This has to be correct per Element: when the rotation cycles to a different Element's wrap, swap to that Element's own real M1 effect, not reuse Pyro's shape for everything.
</context>

<instructions>
1. For every wrap currently in the pedestal's rotation, replace the placeholder sphere with that wrap's actual Element M1 projectile model/VFX — the same asset used in real combat, with the wrap's recolor/skin applied.
2. Confirm each Element's own M1 effect is used for its own wraps; don't default to one Element's shape across others.
3. Keep the existing rotation/cycling, the name+rarity nameplate, and the plinth/glow treatment as-is — only the held prop changes.
4. Leave gameplay values untouched; this is the pedestal display only.
</instructions>

<output_format>
- One line before you start.
- Before/after shots (sphere vs. real M1 effect) for at least two different Elements' wraps.
- One short line confirming each wrap in the rotation now shows its own correct M1 effect.
</output_format>

<edge_cases>
- If extending this beyond M1 to other abilities seems worth doing, flag it as a separate follow-up rather than expanding scope here.
- If an Element's M1 effect doesn't hold a clean static pose in the statue's hand, use the closest static frame of the real effect rather than falling back to the sphere.
</edge_cases>

<tone_preference>
Keep the report short and factual.
</tone_preference>
