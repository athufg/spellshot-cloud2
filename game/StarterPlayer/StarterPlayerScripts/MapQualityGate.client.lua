-- MapQualityGate (2026-10-22): the map side of Graphics Quality (skill references/colour_and_tiers.md).
--   QualityDetail tag (folders: grass, ferns, small bushes, small clutter, e.g. Map_JungleRuins Visual/Detail and
--   Vegetation/Detail): drawn on HIGH and ULTRA only. On LOW and MEDIUM the folder is parented out of this client's
--   workspace (client-local, nothing replicates) and put back when the tier goes up again.
--   MapEffect tag (map ParticleEmitters: waterfall spray, creek mist): full rate on HIGH/ULTRA, half on MEDIUM, off on LOW.
-- Shadows are not here: SettingsRuntime + HubClient already AND the tier with the zone profile (audit P5F-13).
local CS = game:GetService("CollectionService")
local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))

local RATE = { 0, 0.5, 1, 1 }          -- LOW, MEDIUM, HIGH, ULTRA
local tier = 3
local held = {}                       -- detail folder -> its parent while it is held out
local baseRate = {}                   -- emitter -> its authored Rate

local function gateFolder(f)
	if tier >= 3 then return end
	if f.Parent then
		held[f] = f.Parent
		f.Parent = nil
	end
end

local function gateEmitter(e)
	if not e:IsA("ParticleEmitter") then return end
	baseRate[e] = baseRate[e] or e.Rate
	local m = RATE[tier] or 1
	e.Rate = baseRate[e] * m
	e.Enabled = m > 0
end

local function apply(v)
	tier = v or 3
	if tier >= 3 then
		for f, parent in pairs(held) do
			if parent and parent.Parent then f.Parent = parent end
			held[f] = nil
		end
	else
		for _, f in ipairs(CS:GetTagged("QualityDetail")) do gateFolder(f) end
	end
	for _, e in ipairs(CS:GetTagged("MapEffect")) do gateEmitter(e) end
end

CS:GetInstanceAddedSignal("QualityDetail"):Connect(function(f) task.defer(gateFolder, f) end)
CS:GetInstanceAddedSignal("MapEffect"):Connect(gateEmitter)        -- emitters stream in with their parts
Settings.Bind("GraphicsQuality", apply)
