--[[
	ToxinWrap  (ModuleScript)  ->  ReplicatedStorage/ToxinWrap (next to ToxinFX)

	A Toxin colour wrap (Nightshade, 2026-10-17): a recolour of the Default Toxin shapes, nothing else. ToxinFX names every
	colour by ToxinTuning.Color (the source) and builds with ToxinTuning.Display (the measured inputs per material). While
	one broadcast from a wrapped caster is drawn, the wrap's own Color and Display entries stand in those two tables;
	they are put back the moment the handler returns. ToxinFX's shipped-hex guard still checks every colour it draws.
	The caster: d.Character (Lifesteal: d.To); the bubble / cloud events that carry only an Id take the wrap their
	first event had. The Techniques (Antitoxin Vent, Acid Rain) are wrapped too (2026-10-20); the self-damage tell is not, nor is
	a Toxin effect cast by a player whose Element is not Toxin (a borrowed Technique keeps Default, as every kit's does).
	Every broadcast (wrapped or not) also sets ToxinTuning.Mine while it is drawn: true when the caster is this client's
	own body or a teammate's, false for anyone else -- what Reduce Enemy VFX thins (ToxinFX extraScale / density).
	A piece ToxinFX draws LATER (from an updater) re-enters its broadcast's wrap through Capture / With (2026-10-19).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local W = {}
-- (2026-10-20, owner) the Techniques (Antitoxin Vent, Acid Rain) wear the caster's wrap too; only the self-damage tell stays Default
local SKIP = { ToxinSelfTick = true }
local byId = {}                                  -- ["B" / "C" .. Id] = the wrap id that object was drawn in
local mineById = {}                              -- ["B" / "C" .. Id] = its first event's Mine (ToxinTuning.Mine below)
-- (2026-10-19, audit P5B-18) the kinds that end an Id's object: its byId entry goes once its handler has drawn it
local ENDS = { ToxinBubblePop = "B", ToxinBubbleExpire = "B", ToxinBubbleConvert = "B", ToxinCloudEnd = "C" }

local Cat, T, Config, Vfx
local function libs()
	if Cat == nil then
		local ok, m = pcall(function() return require(ReplicatedStorage.Spellshot.SkinCatalog) end)
		Cat = ok and m or false
		-- (2026-10-19, audit P5B-20) ToxinFX's own sibling, not a recursive name search (a second "ToxinTuning" anywhere
		-- earlier in ReplicatedStorage would have been swapped instead, and every wrap drawn Default)
		local ok2, t = pcall(function()
			return require(script.Parent:FindFirstChild("ToxinTuning") or ReplicatedStorage:FindFirstChild("ToxinTuning", true))
		end)
		T = ok2 and t or false
		local ok3, c = pcall(function() return require(ReplicatedStorage.Spellshot.SpellshotConfig) end)
		Config = ok3 and c or false
		-- (2026-10-19, audit P5F-06) VFXLibrary, for its shared IsEnemy (notEnemy below)
		local ok4, v = pcall(function()
			local ice = ReplicatedStorage:FindFirstChild("IceMagic")
			return require(script.Parent:FindFirstChild("VFXLibrary") or (ice and ice:FindFirstChild("VFXLibrary")))
		end)
		Vfx = (ok4 and type(v) == "table") and v or false
	end
	return Cat, T
end

--- (2026-10-19, audit P5B-04) whether `ch`'s effects are spared by Reduce Enemy VFX here: this client's own body, or a
--- teammate's (same DuelMatch, Config.MayHurt false)
local function notEnemy(ch)
	local me = Players.LocalPlayer
	if typeof(ch) ~= "Instance" or not me then return nil end
	-- (2026-10-19, audit P5F-06) one rule for every module: VFXLibrary.IsEnemy (also spares an AllyDummy); below, the
	-- fallback for a VFXLibrary without it
	if Vfx and type(Vfx.IsEnemy) == "function" then return not Vfx.IsEnemy(ch) end
	if ch == me.Character then return true end
	local pl = Players:GetPlayerFromCharacter(ch)
	local match = pl and pl:GetAttribute("DuelMatch")
	if not (match ~= nil and match == me:GetAttribute("DuelMatch") and Config and Config.MayHurt) then return false end
	local ok, may = pcall(Config.MayHurt, pl, me)
	return ok and may == false
end

--- "B" / "C" .. Id: the bubble or cloud a broadcast of `kind` names, or nil
local function keyOf(kind, d)
	local key = d.Id and ((string.find(kind, "Bubble", 1, true) and "B") or (string.find(kind, "Cloud", 1, true) and "C")) or nil
	return key and (key .. tostring(d.Id)) or nil
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
		if pl then
			-- (2026-10-19, audit P4-15) a borrowed Toxin Technique (the caster's Element is not Toxin) draws Default
			id = ((pl:GetAttribute("Element") or "Toxin") == "Toxin") and cat.ElementWrap(pl, "Toxin") or nil
		else
			-- (2026-10-27) a showcase model's wrap (the Loadout Altar), live too
			id = ch:GetAttribute("ShowcaseWrap") or (RunService:IsStudio() and ch:GetAttribute("WrapStudio")) or nil
		end
		-- (2026-10-20) WITCH'S BREW: a wearer with no wrap has the skin's own purple palette on the Default pieces (petals,
		-- drops, strands, the eruption's wave and flash); in Studio a StudioSkin = "WitchsBrew" body stands in
		if id == nil or id == "Default" then
			-- (the kit's own On rule: in Studio a StudioSkin body -- a dummy or the tester's own character -- stands in)
			local brew = RunService:IsStudio() and ch:GetAttribute("StudioSkin") == "WitchsBrew"
			-- (2026-10-26) the showcase convention: a model no player owns with ShowcaseSkin = "WitchsBrew", live too
			if not pl and not brew then brew = ch:GetAttribute("ShowcaseSkin") == "WitchsBrew" end
			if pl and not brew then
				brew = (pl:GetAttribute("Element") or "Toxin") == "Toxin" and type(cat.ElementSkin) == "function"
					and cat.ElementSkin(pl, "Toxin") == "WitchsBrew"
			end
			if brew then id = "#WitchsBrew" end
		end
	end
	local key = keyOf(kind, d)
	if key then
		if id then byId[key] = id else id = byId[key] end
	end
	if id == "#WitchsBrew" then                                    -- (the skin's palette lives in its kit)
		local m = script.Parent:FindFirstChild("WitchsBrewKit")
		local ok, kit = pcall(function() return m and require(m) end)
		return ok and type(kit) == "table" and kit.WrapPalette or nil
	end
	local s = type(id) == "string" and id ~= "Default" and cat.Skins[id]
	return s and s.Wrap == "Toxin" and s.Palette or nil
end

--- `f(...)` drawn in scope `sc` ({ P = the wrap palette or nil, Mine }): the palette's Color / Display entries and
--- Bands stand in ToxinTuning, and Mine is set, for the length of the call; all put back after, even on an error
local current = nil
local function apply(sc, f, ...)
	local _, t = libs()
	if not t then return f(...) end
	local P = sc.P
	local saved = { { t, "Mine", t.Mine } }
	t.Mine = sc.Mine
	if P then
		saved[#saved + 1] = { t, "Hard", t.Hard }
		saved[#saved + 1] = { t, "Bands", t.Bands }
		saved[#saved + 1] = { t, "Finish", t.Finish }
		t.Hard, t.Bands, t.Finish = P.Hard, P.Bands, P.Finish
		for name, c in pairs(P.Color or {}) do saved[#saved + 1] = { t.Color, name, t.Color[name] } t.Color[name] = c end
		for ctx, tbl in pairs(P.Display or {}) do
			local D = t.Display and t.Display[ctx]
			if D then for name, c in pairs(tbl) do saved[#saved + 1] = { D, name, D[name] } D[name] = c end end
		end
		-- (2026-10-20) Antitoxin Vent's mask in the wrap's own family when its palette names no mask colours:
		-- body = GasShadow, dark = GasCore, pale = Gas, lens = LiquidDeep (the Color and the Solid display input)
		local PC, PD, DS = P.Color or {}, P.Display or {}, t.Display and t.Display.Solid
		for mk, src in pairs({ MaskBody = "GasShadow", MaskDark = "GasCore", MaskPale = "Gas", Lens = "LiquidDeep" }) do
			if PC[mk] == nil and PC[src] then saved[#saved + 1] = { t.Color, mk, t.Color[mk] } t.Color[mk] = PC[src] end
			local v = not (PD.Solid and PD.Solid[mk]) and ((PD.Lobe and PD.Lobe[src]) or (PD.Solid and PD.Solid[src])) or nil
			if DS and v then saved[#saved + 1] = { DS, mk, DS[mk] } DS[mk] = v end
		end
	end
	local was = current
	current = sc
	local res = table.pack(pcall(f, ...))
	current = was
	for i = #saved, 1, -1 do local e = saved[i] e[1][e[2]] = e[3] end
	if not res[1] then error(res[2], 0) end
	return table.unpack(res, 2, res.n)
end

--- draw broadcast `d` of `kind` with handler `f`, in the caster's wrap
function W.Run(kind, f, d)
	libs()
	local P = paletteFor(kind, d)
	local ch = type(d) == "table" and (d.Character or (kind == "ToxinLifesteal" and d.To)) or nil
	local mine = notEnemy(ch)
	local key = type(d) == "table" and keyOf(kind, d) or nil         -- (an Id-only event: its object's first Mine)
	if key then
		if mine ~= nil then mineById[key] = mine else mine = mineById[key] end
	end
	local ok, err = pcall(apply, { P = P, Mine = mine }, f, d)
	if key and ENDS[kind] then
		byId[ENDS[kind] .. tostring(d.Id)] = nil
		mineById[ENDS[kind] .. tostring(d.Id)] = nil
	end
	if not ok then error(err, 0) end
end

--- (2026-10-19, audit P5B-11) the scope of the broadcast being drawn right now (nil outside W.Run): ToxinFX captures it
--- for a piece it draws later, and W.With re-enters it then, so a deferred burst or splat keeps its cast's colours
function W.Capture()
	return current
end
function W.With(sc, f, ...)
	if type(sc) ~= "table" then return f(...) end
	return apply(sc, f, ...)
end

return W
