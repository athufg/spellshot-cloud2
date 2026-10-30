--[[
	AquaWrap  (ModuleScript)  ->  ReplicatedStorage/IceMagic/AquaWrap

	Aqua's colour WRAPS (2026-10-19: the plumbing, built with Riptide Jade, Uncommon). A wrap recolours the DEFAULT
	Aqua shapes only: no geometry, timing, hitbox or gameplay value changes. A wrap is one entry in SkinCatalog.Skins:
	{ Wrap = "Aqua", Rarity, Label, Palette = { Water, Foam, Color, ... } }. Nothing here is selectable until its id is
	in SkinCatalog.ElementWraps.Aqua (the owner approves each wrap first).

	WHERE AQUA'S COLOURS LIVE. Nearly all of them are BAKED in the kit meshes' vertex colours (AquaFX draws every solid
	piece as a white SmoothPlastic MeshPart over them: the navy trough, the body blue, the lit blue, the pale foam, the
	dark wet ground). The Tideline-family lines are white meshes drawn in a code colour (AquaTuning.Color). So a wrap is:
	  MESHES   every kit mesh a wrap draws gets a recoloured COPY -- an EditableMesh (FixedSize), its vertex colours run
	           through the wrap's ramps by their Default lightness (Water; Foam by how pale a vertex is; Debris for the
	           meshes a palette names) -- one per mesh and wrap, built on this client OFF the draw path (a queue, one
	           mesh a frame) once the wrap is first seen. AquaFX's template() hands the copy out while that wrap draws;
	           until it is ready the piece wears a multiply tint that carries the body colour. No upload, and the shared
	           kit is never touched. The shark, its fin, its jaw and the rocks keep Default's colours unless a palette
	           names them (Mesh = { AK_LM_Rock = "Debris" }).
	  COLOURS  while a wrapped caster's effect runs -- its entry call, every frame of its steppers, its delayed calls and
	           its handle's methods (AquaFX binds them) -- AquaTuning.Color holds the wrap's Color entries, put back the
	           moment it returns.
	  RARE     Gloss = { Reflectance, MinY }: Reflectance on the wet pieces whose Default lightness is at least MinY (a
	           dark piece stays 0: a mirror reads sky-blue). Drift = { Share, ... }: extra sediment and bubble pieces,
	           Share of every Default splash piece the effect throws (counted as it throws them, never a fixed count),
	           scaled by Graphics Quality and halved for somebody else's effect under Reduce Enemy VFX (Density). The
	           remainder carries from cast to cast PER CASTER AND EFFECT (R2A, 2026-10-19: it carried per broadcast, so a
	           Sidearm shot -- ~9 pieces -- never earned one), so the long-run share is exact. Drift.Trail (optional) gives
	           each extra piece a short trail.
	For(caster): the wrap that caster's Aqua draws in -- nil unless their Element is Aqua. Studio only: a WrapStudio
	attribute on a test dummy or character.
	Install(AquaClient, AquaFX): the one hook, AquaClient's last line. Every handler, every keypress cast, the foam at a
	rider's feet and the local body's own shots then draw in their caster's wrap; with no wrap they are called as before.
	GUARD: a palette with any colour (or any step between two ramp stops) within 12/255 on all three channels of Aqua's
	shipped Base / Light / Dark is refused with one warning and draws Default.
	BAKED SETS (AB, 2026-10-19): the runtime copies filled every client's EditableMesh budget at about two wraps, so each
	wrap's recoloured meshes are now BAKED offline (this module's ramp, ported to Python, on the exact kit meshes; Blender;
	Import 3D) into ReplicatedStorage.AquaWrapMeshes.<WrapId>.<kit mesh name>: full templates (the kit piece's clone, the
	baked mesh applied, AquaWrapId / AquaWrapGloss stamped). Template() hands the baked piece out; the runtime copy is
	only the fallback for a piece that has no baked mesh -- and, for a flow wrap (Palette.Flow, Mythic), the copies of
	its Flow.Big bodies that AquaWrapLux repaints every frame, kept ONLY where the device affords them: Graphics Quality
	with a flow budget, one runtime set per client, at most RUNTIME_CAP vertices (least recently used evicted). A copy
	that is refused or fails shows the baked piece, never the stand-in tint. A wrap's baked set is preloaded when a
	player's ElementWrap_Aqua names it and when its caster is first seen. Default never reaches any of this.
	Studio only: workspace AquaWrapNoBaked (draw as before the bake), AquaWrapRefuseCopies (every copy refused),
	AquaWrapStudioDetail (0 LOW .. 2 HIGH: stands in for Graphics Quality in the runtime-set decision).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")

local iceFolder = script.Parent
local A = require(iceFolder:WaitForChild("AquaTuning"))
local COL = A.Color
local DEF = table.clone(COL)                        -- Default's colours, as AquaTuning ships them

local W = { Active = nil, Ctx = nil }
W.Stats = { Built = 0, Same = 0, Failed = 0, Verts = 0, BuildSeconds = 0, Pieces = {} }

local KEEP = { AK_LM_Shark = true, AK_LM_Fin = true, AK_LM_Jaw = true, AK_LM_Rock = true }   -- not the blue family
-- (round 3, 2026-10-19) the per-device EditableMesh budget filled at ~122k vertices: the white line meshes (no blue
-- vertex: their colour is the code's) are never copied, and the Twin Tide flipbook frames (37 x ~10k vertices) and
-- the three kit pieces nothing draws any more wear the multiply tint instead of a copy
local LINE = { AK_LM_Rim = true, AK_LM_Ring = true, AK_RT_Lip = true, AK_SA_Muzzle = true, AK_SA_ResLine = true,
	AK_SA_SlugLip = true, AK_TT_JetLine = true, AK_TT_Lip = true, AK_TT_Seam = true, AK_UT_ArmLine = true,
	AK_UT_HeadLine = true, AK_WG_PuddleEdge = true, AK_WG_StreakEdge = true, AK_TT_SimLine = true }
local TINT = { AK_TT_Sim = true }
local UNUSED = { AK_TT_Wall = true, AK_TT_Crash = true, AK_TT_Seam = true }   -- (exact names: the v2 pieces)
local GUARD = 12 / 255

local Cat, Settings, Ident
local function catalog()
	if Cat == nil then
		local ok, m = pcall(function() return require(ReplicatedStorage.Spellshot.SkinCatalog) end)
		Cat = ok and m or false
	end
	return Cat or nil
end
local function settings()
	if Settings == nil then
		local ok, m = pcall(function() return require(ReplicatedStorage.Spellshot.SpellshotSettings) end)
		Settings = ok and m or false
	end
	return Settings or nil
end
local function identity()
	if Ident == nil then
		local ok, e = pcall(function() return require(ReplicatedStorage.Spellshot.SpellshotConfig).Elements.Aqua end)
		Ident = (ok and e) and { e.Base, e.Light, e.Dark } or false
	end
	return Ident or {}
end

local function group(name) return (string.gsub(name, "_%d+$", "")) end

----------------------------------------------------------------------------------------------------
-- palettes
----------------------------------------------------------------------------------------------------
local function near(c)
	for _, s in ipairs(identity()) do
		if math.abs(c.R - s.R) <= GUARD and math.abs(c.G - s.G) <= GUARD and math.abs(c.B - s.B) <= GUARD then return true end
	end
	return false
end

--- every colour of palette P, and 20 steps between neighbouring ramp stops, clear of Aqua's shipped hexes
local function guardOK(P)
	local bad = nil
	local function check(c, where) if typeof(c) == "Color3" and near(c) then bad = bad or where end end
	for k, c in pairs(P.Color or {}) do check(c, "Color." .. k) end
	for k, c in pairs(P.Tone or {}) do check(c, "Tone." .. k) end
	check(P.SimTint, "SimTint")
	for _, rk in ipairs({ "Water", "Foam", "Debris" }) do
		local r = P["_" .. string.lower(rk)]
		if type(r) == "table" then
			for i, s in ipairs(r) do
				check(s[2], rk .. "[" .. i .. "]")
				local n = r[i + 1]
				if n then for t = 1, 19 do check(s[2]:Lerp(n[2], t / 20), rk .. " step " .. i) end end
			end
		end
	end
	local D = P._drift
	if type(D) == "table" then
		for _, k in ipairs({ "Sediment", "Bubble" }) do
			local pair = D[k]
			if type(pair) == "table" then for i, c in ipairs(pair) do check(c, "Drift." .. k .. i) end end
		end
	end
	return bad == nil, bad
end

local function stop(r, y)
	if y <= r[1][1] then return r[1][2] end
	for i = 2, #r do
		local a, b = r[i - 1], r[i]
		if y <= b[1] then return a[2]:Lerp(b[2], (y - a[1]) / (b[1] - a[1])) end
	end
	return r[#r][2]
end

local function luma(c) return (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) * 255 end

--- vertex colour `c` in palette P. mode "water": the blue family (hue 162..259 deg, not grey) runs the Water ramp by
--- its lightness, blended into the Foam ramp as it goes pale (saturation FoamSat[1] -> FoamSat[2]); whites, greys and
--- any other hue stay. mode "Debris" (a mesh the palette names): every vertex runs the Debris ramp by its lightness.
local function remap(c, P, mode)
	if mode == "Debris" then return P._debris and stop(P._debris, luma(c)) or c end
	local h, s = c:ToHSV()
	if s < 0.08 or h < 0.45 or h > 0.72 then return c end
	local y = luma(c)
	local out = stop(P._water, y)
	local F = P._foam
	if F then
		local fs = P.FoamSat or { 0.5, 0.3 }
		local w = math.clamp((fs[1] - s) / (fs[1] - fs[2]), 0, 1)
		w = w * w * (3 - 2 * w)
		if w > 0 then out = out:Lerp(stop(F, y), w) end
	end
	return out
end
W.Remap = remap

local palettes = {}
local queueBuild
local function palette(id)
	if type(id) ~= "string" or id == "Default" then return nil end
	local P = palettes[id]
	if P ~= nil then return P or nil end
	local cat = catalog()
	local s = cat and cat.Skins and cat.Skins[id]
	P = s and s.Wrap == "Aqua" and type(s.Palette) == "table" and type(s.Palette.Water) == "table" and s.Palette or nil
	if not P then palettes[id] = false return nil end
	-- ramps and Drift name their colours from Tone (so every hex sits once, by name, in the catalog entry)
	local tone = P.Tone or {}
	local function col(v) return (type(v) == "string" and tone[v]) or (typeof(v) == "Color3" and v) or nil end
	local function ramp(r)
		if type(r) ~= "table" then return nil end
		local out = {}
		for _, st in ipairs(r) do
			local c = col(st[2])
			if not c then warn("[AquaWrap] " .. id .. ": no Tone." .. tostring(st[2])) palettes[id] = false return nil end
			out[#out + 1] = { st[1], c }
		end
		return out
	end
	P._water, P._foam, P._debris = ramp(P.Water), ramp(P.Foam), ramp(P.Debris)
	if not P._water or palettes[id] == false then palettes[id] = false return nil end
	if type(P.Drift) == "table" then
		local D = table.clone(P.Drift)
		for _, k in ipairs({ "Sediment", "Bubble" }) do
			local list = {}
			for _, v in ipairs(P.Drift[k] or {}) do list[#list + 1] = col(v) end
			D[k] = list
		end
		P._drift = D
	end
	local ok, where = guardOK(P)
	if not ok then
		warn("[AquaWrap] " .. id .. ": " .. tostring(where) .. " is within 12/255 of an Aqua identity colour - drawn as Default")
		palettes[id] = false
		return nil
	end
	P.Id = id
	-- the stand-in until a mesh's copy is built: a multiply that takes Default's body blue to the wrap's body
	local body, want = Color3.fromRGB(38, 144, 228), remap(Color3.fromRGB(38, 144, 228), P, "water")
	P._tint = Color3.new(math.min(1, want.R / body.R), math.min(1, want.G / body.G), math.min(1, want.B / body.B))
	palettes[id] = P
	if RunService:IsClient() then task.defer(W.Warm, P) end
	return P
end
W.Palette = palette

--- the wrap `caster`'s Aqua draws in (a palette), or nil for Default
function W.For(caster)
	if typeof(caster) ~= "Instance" then return nil end
	if RunService:IsStudio() and caster:GetAttribute("WrapStudio") then return palette(caster:GetAttribute("WrapStudio")) end
	local plr = Players:GetPlayerFromCharacter(caster)
	if not plr then return nil end
	if (plr:GetAttribute("Element") or "Aqua") ~= "Aqua" then return nil end     -- a borrowed Aqua move: Default
	local cat = catalog()
	return (cat and cat.ElementWrap) and palette(cat.ElementWrap(plr, "Aqua")) or nil
end

----------------------------------------------------------------------------------------------------
-- the context: a wrap's colours in AquaTuning.Color while its effect runs
----------------------------------------------------------------------------------------------------
local function apply(P)
	local C = P and P.Color
	for k, def in pairs(DEF) do COL[k] = (C and C[k]) or def end
end

--- fn(...) inside context `ctx` ({ P = palette or nil, Caster, Kind }); nested calls in the same context run straight
local function call(ctx, fn, ...)
	local prev = W.Ctx
	if prev == ctx then return fn(...) end
	local prevP = prev and prev.P
	local P = ctx and ctx.P
	if P ~= prevP then apply(P) end
	W.Ctx, W.Active = ctx, P
	local res = table.pack(pcall(fn, ...))
	W.Ctx, W.Active = prev, prevP
	if P ~= prevP then apply(prevP) end
	if not res[1] then error(res[2], 0) end
	return table.unpack(res, 2, res.n)
end
W.Call = call

--- `fn`, bound to the wrap it was made in (the same function when there is none)
function W.Bind(fn)
	local ctx = W.Ctx
	if not (ctx and ctx.P) or type(fn) ~= "function" then return fn end
	return function(...) return call(ctx, fn, ...) end
end

--- every method of an effect's handle, bound to the wrap it was made in
function W.BindHandle(h)
	local ctx = W.Ctx
	if type(h) ~= "table" or not (ctx and ctx.P) then return h end
	for k, v in pairs(h) do
		if type(v) == "function" then h[k] = function(...) return call(ctx, v, ...) end end
	end
	return h
end

----------------------------------------------------------------------------------------------------
-- the recoloured kit copies
----------------------------------------------------------------------------------------------------
local built = {}          -- [wrap id][template name] = wrapped template | false (same as Default, or failed)
local pending = {}        -- [wrap id][template name] = true while queued
local queue, working = {}, false
local STUDIO = RunService:IsStudio()
W.Stats.Baked, W.Stats.Evicted, W.Stats.Refused = 0, 0, 0

-- the baked sets (AB): ReplicatedStorage.AquaWrapMeshes.<WrapId>.<kit mesh name>
local BAKED = "AquaWrapMeshes"
local function bakedSet(id)
	if STUDIO and workspace:GetAttribute("AquaWrapNoBaked") then return nil end
	local root = ReplicatedStorage:FindFirstChild(BAKED)
	return root and root:FindFirstChild(id) or nil
end
local function bakedOf(P, name)
	local set = bakedSet(P.Id)
	local b = set and set:FindFirstChild(name)
	return (b and b:IsA("MeshPart")) and b or nil
end
local preloaded = {}
--- a wrap's baked meshes fetched before anything draws them (once per wrap and client)
local function preload(id)
	if preloaded[id] or not RunService:IsClient() then return end
	local set = bakedSet(id)
	if not set then return end
	preloaded[id] = true
	task.spawn(function()
		local list = set:GetChildren()
		pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
	end)
end
W.Preload = preload

-- the runtime flow set (AB): a flow wrap's Flow.Big copies, where the device affords them
local RUNTIME_CAP = { 32000, 16000, 0 }   -- vertices of runtime copies by Graphics Quality (HIGH, MEDIUM, LOW)
local GRACE = 20                           -- a copy handed out this recently is never evicted (an effect may show it)
local RETRY = 30                           -- a refused or failed flow copy is tried again after this long
local RT = { Owner = nil, Verts = 0 }      -- the one wrap holding runtime copies on this client; their vertices
local live = {}                            -- [wrap id][name] = { EM, W, N, Used } for the runtime flow copies
local retryAt = {}                         -- [wrap id .. name] = os.clock() when a refused copy may be tried again
local function detail()                    -- Graphics Quality: 2 HIGH, 1 MEDIUM, 0 LOW (AquaWrapLux's split)
	if STUDIO then                         -- (Studio: workspace AquaWrapStudioDetail stands in for the setting here)
		local o = workspace:GetAttribute("AquaWrapStudioDetail")
		if type(o) == "number" then return math.clamp(math.floor(o), 0, 2) end
	end
	local S = settings()
	local d = (S and S.EffectDensity) or 1
	return d >= 0.9 and 2 or (d >= 0.6 and 1 or 0)
end
--- true when wrap P repaints mesh `name` per vertex on this device and may hold its runtime copy
local function flowWants(P, name)
	local F = P.Flow
	if type(F) ~= "table" or type(F.Big) ~= "table" then return false end
	local g, big = group(name), false
	for _, b in ipairs(F.Big) do if b == g then big = true break end end
	if not big then return false end
	if ((type(F.Budget) == "table" and F.Budget[3 - detail()]) or 0) <= 0 then return false end
	if (RUNTIME_CAP[3 - detail()] or 0) <= 0 then return false end
	return RT.Owner == nil or RT.Owner == P.Id
end
local function studioStats()
	if not STUDIO then return end
	local st = W.Stats
	pcall(function() script:SetAttribute("StudioStats", string.format("built %d same %d failed %d verts %d build %.2fs queue %d at %.1f baked %d rt %s %dv evicted %d refused %d",
		st.Built, st.Same, st.Failed, st.Verts, st.BuildSeconds, #queue, os.clock(), st.Baked, tostring(RT.Owner or "-"), RT.Verts, st.Evicted, st.Refused)) end)
end
--- room for `n` more runtime vertices: the least recently used copies (none handed out within GRACE) go
local function makeRoom(n, keep)
	local cap = RUNTIME_CAP[3 - detail()] or 0
	while RT.Verts + n > cap do
		local oldest, oid, oname = nil, nil, nil
		for id, byName in pairs(live) do
			for name, c in pairs(byName) do
				if c ~= keep and os.clock() - c.Used > GRACE and (not oldest or c.Used < oldest.Used) then oldest, oid, oname = c, id, name end
			end
		end
		if not oldest then return false end
		live[oid][oname] = nil
		if built[oid] then built[oid][oname] = nil end
		RT.Verts -= oldest.N
		W.Stats.Evicted += 1
		pcall(function() oldest.W:Destroy() end)
		pcall(function() oldest.EM:Destroy() end)
	end
	return true
end

local function modeOf(P, name)
	local g = group(name)
	local m = P.Mesh and P.Mesh[g]
	if m then return m end
	if KEEP[g] then return "Keep" end
	if LINE[g] then return "Line" end
	if TINT[g] or UNUSED[name] then return "Tint" end
	return "water"
end

local function build(P, t)
	local mode = modeOf(P, t.Name)
	if mode == "Keep" or mode == "Line" or mode == "Tint" then return false end
	local t0 = os.clock()
	if STUDIO and workspace:GetAttribute("AquaWrapRefuseCopies") then W.Stats.Failed += 1 return false end   -- (Studio: the refused path)
	local ok, em = pcall(function() return AssetService:CreateEditableMeshAsync(Content.fromUri(t.MeshId), { FixedSize = true }) end)
	if not (ok and em) then W.Stats.Failed += 1 return false end
	local changed, n, sumY = false, 0, 0
	local ok2 = pcall(function()
		for _, id in ipairs(em:GetColors()) do
			local c = em:GetColor(id)
			local r = remap(c, P, mode)
			n += 1
			sumY += luma(c)
			if r ~= c then
				changed = true
				em:SetColor(id, r)
			end
		end
	end)
	if not ok2 then em:Destroy() W.Stats.Failed += 1 return false end
	if not changed then em:Destroy() W.Stats.Same += 1 return false end
	local ok3, holder = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(em)) end)
	if not (ok3 and holder) then em:Destroy() W.Stats.Failed += 1 return false end
	local w = t:Clone()
	local size = w.Size
	local ok4 = pcall(w.ApplyMesh, w, holder)
	holder:Destroy()
	if not ok4 then w:Destroy() em:Destroy() W.Stats.Failed += 1 return false end
	if w.Size ~= size then w.Size = size end
	w:SetAttribute("AquaWrapId", P.Id)
	local G = P.Gloss
	if G and mode == "water" and n > 0 and sumY / n >= (G.MinY or 0) then w:SetAttribute("AquaWrapGloss", G.Reflectance) end
	if flowWants(P, t.Name) and bakedOf(P, t.Name) then      -- (AB) a runtime flow copy: counted against the cap
		local c = { EM = em, W = w, N = n, Used = os.clock() }
		if not makeRoom(n, c) then
			w:Destroy() em:Destroy()
			W.Stats.Refused += 1
			return false
		end
		RT.Owner = P.Id
		RT.Verts += n
		live[P.Id] = live[P.Id] or {}
		live[P.Id][t.Name] = c
	end
	W.Stats.Built += 1
	W.Stats.Verts += n
	W.Stats.BuildSeconds += os.clock() - t0
	return w
end

local function worker()
	if working then return end
	working = true
	task.spawn(function()
		while #queue > 0 do
			local job = table.remove(queue, 1)
			local P, t = job[1], job[2]
			local byP = built[P.Id]
			if byP[t.Name] == nil then
				byP[t.Name] = build(P, t)
				if byP[t.Name] == false and bakedOf(P, t.Name) then retryAt[P.Id .. t.Name] = os.clock() + RETRY end
			end
			pending[P.Id][t.Name] = nil
			studioStats()                                    -- (Studio only: the checkpoint's cost numbers)
			task.wait()
		end
		working = false
	end)
end

queueBuild = function(P, t, front)
	built[P.Id] = built[P.Id] or {}
	pending[P.Id] = pending[P.Id] or {}
	if built[P.Id][t.Name] ~= nil or pending[P.Id][t.Name] then return end
	pending[P.Id][t.Name] = true
	if front then table.insert(queue, 1, { P, t }) else table.insert(queue, { P, t }) end
	worker()
end

--- the active wrap's copy of kit template `t`, or nil (none needed, or not built yet: it is queued at the front)
local handed = {}
function W.Template(t)
	local P = W.Active
	if not P then return nil end
	local byP = built[P.Id]
	local w = byP and byP[t.Name]
	local b = bakedOf(P, t.Name)
	if b then                                            -- (AB) the baked piece; a flow body's runtime copy where afforded
		if flowWants(P, t.Name) then
			local c = live[P.Id] and live[P.Id][t.Name]
			if w and c then c.Used = os.clock() return w end
			local k = P.Id .. t.Name
			if w == false and retryAt[k] and os.clock() >= retryAt[k] then retryAt[k] = nil byP[t.Name] = nil w = nil end
			if w == nil then queueBuild(P, t, true) end
		end
		if not handed[b] then handed[b] = true W.Stats.Baked += 1 studioStats() end
		return b
	end
	if w then return w end
	if w == nil then queueBuild(P, t, true) end
	return nil
end

--- every kit mesh queued for wrap P, the Twin Tide flipbook frames last (once per wrap and client)
local warmed = {}
function W.Warm(P)
	if not P or warmed[P.Id] then return end
	warmed[P.Id] = true
	local meshes = ReplicatedStorage:FindFirstChild("IceMagicMeshes")
	local kit = meshes and meshes:FindFirstChild("AquaKit")
	if not kit then return end
	preload(P.Id)
	for _, t in ipairs(kit:GetChildren()) do
		local mode = t:IsA("MeshPart") and modeOf(P, t.Name)
		if (mode == "water" or mode == "Debris") and (not bakedOf(P, t.Name) or flowWants(P, t.Name)) then queueBuild(P, t) end
	end
end

--- a fresh kit piece `p` (kind "solid" / "glass" / a line) in the active wrap: the multiply stand-in while its copy is
--- not ready, and the wrap's gloss on the wet pieces
function W.Dress(p, kind)
	local P = W.Active
	if not P or not (kind == "solid" or kind == "glass") then return end
	if p:GetAttribute("AquaWrapId") ~= P.Id then
		local mode = modeOf(P, p.Name)
		if mode == "water" then p.Color = P._tint elseif mode == "Tint" then p.Color = P.SimTint or P._tint end
		return
	end
	local r = p:GetAttribute("AquaWrapGloss")
	if r then p.Reflectance = r end
end

--- (AB) a player's Aqua wrap, read off their attributes: its baked set preloaded at once, and warmed (the flow's runtime
--- copies, where afforded) while they play Aqua -- so nothing pops in when their first effect draws
if RunService:IsClient() then
	task.defer(function()
		local cat = catalog()
		local attr = (cat and cat.ElementWrapAttr and cat.ElementWrapAttr("Aqua")) or "ElementWrap_Aqua"
		local function seen(plr)
			local id = plr:GetAttribute(attr)
			if type(id) ~= "string" or id == "Default" then return end
			preload(id)
			if (plr:GetAttribute("Element") or "Aqua") == "Aqua" then palette(id) end
		end
		local function watch(plr)
			plr:GetAttributeChangedSignal(attr):Connect(function() seen(plr) end)
			plr:GetAttributeChangedSignal("Element"):Connect(function() seen(plr) end)
			seen(plr)
		end
		Players.PlayerAdded:Connect(watch)
		for _, plr in ipairs(Players:GetPlayers()) do watch(plr) end
	end)
end

----------------------------------------------------------------------------------------------------
-- Rare: extra pieces (Drift), counted against the Default pieces the same effect throws
----------------------------------------------------------------------------------------------------
--- Graphics Quality (0.4 .. 1), halved for somebody else's effect under Reduce Enemy VFX (CryoFX's density)
function W.Density(caster)
	local S = settings()
	local d = math.clamp((S and S.EffectDensity) or 1, 0.4, 1)
	local me = Players.LocalPlayer and Players.LocalPlayer.Character
	if S and S.ThinEnemyVFX and caster ~= nil and caster ~= me then d *= 0.5 end
	return d
end

local acc = setmetatable({}, { __mode = "k" })   -- [caster] = { [effect kind] = the Drift remainder }
local function stat(ctx)
	local key = tostring(ctx.P and ctx.P.Id or "?") .. ":" .. tostring(ctx.Kind or "?")
	local s = W.Stats.Pieces[key]
	if not s then s = { Default = 0, Extra = 0 } W.Stats.Pieces[key] = s end
	return s
end
local pubT, pubLater = 0, false
local function publishPieces()                       -- (Studio only: the checkpoint's particle counts, by wrap and effect)
	if not RunService:IsStudio() then return end
	if os.clock() < pubT then                        -- (throttled: the last count still goes out, 0.6 s later)
		if not pubLater then pubLater = true task.delay(0.6, function() pubLater = false pubT = 0 publishPieces() end) end
		return
	end
	pubT = os.clock() + 0.5
	pcall(function() script:SetAttribute("StudioPieces", game:GetService("HttpService"):JSONEncode(W.Stats.Pieces)) end)
end

--- one Default splash piece thrown in the active wrap; true when an extra Drift piece is due with it
function W.Piece()
	local ctx = W.Ctx
	local P = ctx and ctx.P
	if not P then return false end
	stat(ctx).Default += 1
	publishPieces()
	local D = P._drift
	if not D then return false end
	local who = typeof(ctx.Caster) == "Instance" and ctx.Caster or W
	local byKind = acc[who]
	if not byKind then byKind = {} acc[who] = byKind end
	local kk = tostring(P.Id) .. ":" .. tostring(ctx.Kind or "?")
	local a = (byKind[kk] or 0) + (D.Share or 0) * W.Density(ctx.Caster)
	if a >= 1 - 1e-6 then
		byKind[kk] = a - 1
		return true
	end
	byKind[kk] = a
	return false
end

function W.Extra()
	local ctx = W.Ctx
	if ctx and ctx.P then stat(ctx).Extra += 1 publishPieces() end
end

----------------------------------------------------------------------------------------------------
-- the hook (AquaClient's last line)
----------------------------------------------------------------------------------------------------
function W.Install(client, fx)
	if type(client) ~= "table" or W._installed then return end
	W._installed = true
	local me = Players.LocalPlayer
	for kind, fn in pairs(client.Handlers or {}) do
		client.Handlers[kind] = function(d, ...)
			local c = type(d) == "table" and d.Character or nil
			return call({ P = W.For(c), Caster = c, Kind = kind }, fn, d, ...)
		end
	end
	for id, fn in pairs(client.LocalCast or {}) do
		client.LocalCast[id] = function(character, ...)
			local c = typeof(character) == "Instance" and character or (me and me.Character)
			return call({ P = W.For(c), Caster = c, Kind = id }, fn, character, ...)
		end
	end
	if type(fx) ~= "table" then return end
	-- the local body's own shots, drawn outside any broadcast (Riptide's wave on the shot frame, Sidearm's rapid fire)
	for _, name in ipairs({ "Riptide", "FireSlug" }) do
		local f = fx[name]
		if type(f) == "function" then
			fx[name] = function(...)
				if W.Ctx then return f(...) end
				local c = me and me.Character
				return call({ P = W.For(c), Caster = c, Kind = name }, f, ...)
			end
		end
	end
	-- the foam at the feet of whoever rides or slips on wet ground: that body's own wrap
	local rs = fx.RidingSplash
	if type(rs) == "function" then
		fx.RidingSplash = function(c, ...)
			return call({ P = W.For(c), Caster = c, Kind = "Riding" }, rs, c, ...)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- EPIC / MYTHIC (A2, 2026-10-19): AquaWrapLux carries the Glow / Pulse / Motes (Epic) and Flow / Curtains / Spray
-- (Mythic) levers. Only a palette with one of those fields reaches it, so Default and every Uncommon / Rare wrap draw
-- exactly as before.
----------------------------------------------------------------------------------------------------
do
	local okLux, Lux = pcall(function()
		local m = iceFolder:WaitForChild("AquaWrapLux", 5)
		return m and require(m)
	end)
	if okLux and type(Lux) == "table" then
		W.Lux = Lux
		Lux.Init(W, { modeOf = modeOf, group = group })
		local function lux(P) return P and (P.Glow or P.Pulse or P.Motes or P.Flow or P.Curtains or P.Spray) end
		local dress, piece, warm = W.Dress, W.Piece, W.Warm
		W.Dress = function(p, kind)
			dress(p, kind)
			local P = W.Active
			if lux(P) then pcall(Lux.Dress, p, kind, P) end
		end
		W.Piece = function(at)
			local due = piece()
			local ctx = W.Ctx
			local P = ctx and ctx.P
			if lux(P) then pcall(Lux.Piece, at, P, ctx, due) end
			return due
		end
		W.Warm = function(P)
			warm(P)
			if lux(P) then pcall(Lux.Warm, P, function(Q, name) return built[Q.Id] and built[Q.Id][name] end) end
		end
	end
end

return W
