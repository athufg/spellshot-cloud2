--!strict
-- QualityGate.client.luau  (LocalScript, StarterPlayerScripts)
-- Elemental Quarry's phone budget switch (v3d, 2026-10-22; owner: "I'm hoping this does not lag. On either of the
-- devices"). While the player's graphics quality is LOW it hides the map's DETAIL LAYER (grass, ground scatter, small
-- site clutter, flowers, the hill-top and outer-slope trees: the MeshParts manifest.json marks "detail": true) and turns
-- off the map's particle effects (manifest "effects"); when quality rises it shows them again.
--   LOW = SPELLSHOT's Graphics Quality option on LOW or MEDIUM, as MapQualityGate's detail (2026-10-23; it was Roblox's own
--   slider, SavedQualityLevel 1-4, or Automatic on a small touch screen: copy in ServerStorage.BugfixSuperseded_2026_10_23).
-- It works from CollectionService tags only (v3e, review): assemble_eq_v3.luau tags every detail MeshPart "EQ_Detail"
-- and every effect ParticleEmitter "EQ_Effect" (created disabled; 2026-10-23: their MinQuality, on Roblox's 1-10 slider, is not read).
-- Tags are saved with the place and replicate, so it does not matter where the map's model sits in the Workspace.
-- Cheap and event-driven: it reacts to the Graphics Quality option and tagged parts streaming in. No per-frame
-- work, nothing replicated (LocalTransparencyModifier and Enabled are set on this client only). The lava flow Beams are
-- core and are never touched.

local CollectionService = game:GetService("CollectionService")
local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))

local DETAIL_TAG = "EQ_Detail"
local EFFECT_TAG = "EQ_Effect"
local LOW_BELOW = 3 -- 2026-10-23: Graphics Quality tiers below HIGH (LOW 1, MEDIUM 2) are low, as MapQualityGate's detail

local low: boolean? = nil

local function computeLow(): boolean
	return (Settings.Get("GraphicsQuality") or 3) < LOW_BELOW
end

local function applyDetail(inst: Instance)
	if inst:IsA("BasePart") then
		inst.LocalTransparencyModifier = if low then 1 else 0
	end
end

local function setEmitter(inst: Instance, on: boolean)
	if inst:IsA("ParticleEmitter") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
		(inst :: any).Enabled = on
	end
end

local function applyEffect(inst: Instance)
	local on = not low
	setEmitter(inst, on)
	for _, d in inst:GetDescendants() do -- an Attachment or part may hold the emitters
		setEmitter(d, on)
	end
end

local function refresh()
	local nowLow = computeLow()
	if nowLow == low then
		return
	end
	low = nowLow
	for _, inst in CollectionService:GetTagged(DETAIL_TAG) do
		applyDetail(inst)
	end
	for _, inst in CollectionService:GetTagged(EFFECT_TAG) do
		applyEffect(inst)
	end
end

refresh()
CollectionService:GetInstanceAddedSignal(DETAIL_TAG):Connect(function(inst)
	applyDetail(inst)
end)
CollectionService:GetInstanceAddedSignal(EFFECT_TAG):Connect(function(inst)
	applyEffect(inst)
end)
Settings.Bind("GraphicsQuality", function() refresh() end) -- 2026-10-23: the game's option (was Roblox's slider + screen size)

