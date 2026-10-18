--[[
	ToxinWrap  (ModuleScript)  ->  ReplicatedStorage/ToxinWrap (next to ToxinFX)

	A Toxin colour wrap (Nightshade, 2026-10-17): a recolour of the Default Toxin shapes, nothing else. ToxinFX names every
	colour by ToxinTuning.Color (the source) and builds with ToxinTuning.Display (the measured inputs per material). While
	one broadcast from a wrapped caster is drawn, the wrap's own Color and Display entries stand in those two tables;
	they are put back the moment the handler returns. ToxinFX's shipped-hex guard still checks every colour it draws.
	The caster: d.Character (Lifesteal: d.To); the bubble / cloud events that carry only an Id take the wrap their
	first event had. The Techniques (Antitoxin Vent, Acid Rain) and the self-damage tell are never wrapped.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local W = {}
local SKIP = { ToxinVent = true, ToxinVentEnd = true, ToxinAcidRain = true, ToxinAcidTick = true, ToxinSelfTick = true }
local byId = {}                                  -- ["B" / "C" .. Id] = the wrap id that object was drawn in

local Cat, T
local function libs()
	if Cat == nil then
		local ok, m = pcall(function() return require(ReplicatedStorage.Spellshot.SkinCatalog) end)
		Cat = ok and m or false
		local ok2, t = pcall(function() return require(ReplicatedStorage:FindFirstChild("ToxinTuning", true)) end)
		T = ok2 and t or false
	end
	return Cat, T
end

--- the wrap palette `d` (a broadcast of `kind`) is drawn in, or nil (Default)
local function paletteFor(kind, d)
	if SKIP[kind] or type(d) ~= "table" then return nil end
	local cat = libs()
	if not cat then return nil end
	local ch = d.Character or (kind == "ToxinLifesteal" and d.To) or nil
	local id
	if typeof(ch) == "Instance" then
		local pl = Players:GetPlayerFromCharacter(ch)
		id = pl and cat.ElementWrap(pl, "Toxin") or (RunService:IsStudio() and ch:GetAttribute("WrapStudio")) or nil
	end
	local key = d.Id and ((string.find(kind, "Bubble", 1, true) and "B") or (string.find(kind, "Cloud", 1, true) and "C")) or nil
	if key then
		key ..= tostring(d.Id)
		if id then byId[key] = id else id = byId[key] end
	end
	local s = type(id) == "string" and id ~= "Default" and cat.Skins[id]
	return s and s.Wrap == "Toxin" and s.Palette or nil
end

--- draw broadcast `d` of `kind` with handler `f`, in the caster's wrap
function W.Run(kind, f, d)
	local P = paletteFor(kind, d)
	local _, t = libs()
	if not (P and t) then return f(d) end
	local saved = { { t, "Hard", t.Hard }, { t, "Bands", t.Bands }, { t, "Finish", t.Finish }, { t, "Mine", t.Mine } }
	t.Hard, t.Bands, t.Finish = P.Hard, P.Bands, P.Finish
	local ch = d.Character or (kind == "ToxinLifesteal" and d.To) or nil
	t.Mine = ch ~= nil and ch == Players.LocalPlayer.Character      -- (Reduce Enemy VFX thins only somebody else's extras)
	for name, c in pairs(P.Color or {}) do saved[#saved + 1] = { t.Color, name, t.Color[name] } t.Color[name] = c end
	for ctx, tbl in pairs(P.Display or {}) do
		local D = t.Display and t.Display[ctx]
		if D then for name, c in pairs(tbl) do saved[#saved + 1] = { D, name, D[name] } D[name] = c end end
	end
	local ok, err = pcall(f, d)
	for i = #saved, 1, -1 do local e = saved[i] e[1][e[2]] = e[3] end
	if not ok then error(err, 0) end
end

return W
