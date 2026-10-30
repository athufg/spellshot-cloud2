--[[
	AquaWrapLux  (ModuleScript)  ->  ReplicatedStorage/IceMagic/AquaWrapLux

	Aqua's EPIC and MYTHIC wrap levers (2026-10-19: Moonjelly, Epic; Maelstrom, Mythic). AquaWrap calls in here only while
	a wrap with one of these palette fields draws; a palette without them never reaches this module, so Default and every
	Uncommon / Rare wrap draw exactly as before. Geometry, timing, hitboxes and gameplay never change.
	  GLOW      Palette.Glow      the water bodies self-lit: Neon over the wrap's vertex-colour copy, the part held at NeonK
	                              grey (Neon brightens a MeshPart; its vertices carry the colour), Reflectance 0. Ground pieces
	                              and Glow.Skip stay lit SmoothPlastic.
	  PULSE     Palette.Pulse     every glow body breathes together: brightness x (1 + Amp sin(2 pi t / Period)); held at mid
	                              under Reduce Flashing. One RenderStepped loop, alive only while pieces are.
	  MOTES     Palette.Motes     tiny self-lit specks (plankton / glints) beside the splash pieces an effect throws -- its
	                              impacts, casts and edges -- Motes.Share of that effect's Default pieces (AquaWrap.Piece counts
	                              them), x Density (Graphics Quality; halved for somebody else's effect under Reduce Enemy VFX).
	  FLOW      Palette.Flow      MYTHIC: one world-space field of colour that FLOWS (rebuilt R2A 2026-10-19: the first field
	                              drifted ~0.5 studs/s through 14-stud blotches, so on screen it read as a static tint). Now:
	                              streaks laid along one world current (Flow.Dir; Across / Vert / Warp, cached per vertex),
	                              and a SWELL of light and colour running down the current at Flow.Speed studs/s (wavelength
	                              Flow.Wave, its fronts bent by Flow.Bend; BrightAmp / HueAmp), the whole cycle sliding at
	                              Flow.Cycle; the stops form a CYCLE (last = first, OKLab, linear when Flow.Linear), so the
	                              colour never jumps.
	                              The big bodies (Flow.Big) are painted per vertex INTO THE WRAP'S OWN COPY of their mesh
	                              (AquaWrap's; no extra EditableMesh -- the client's EditableMesh budget is the limit), at the
	                              world points of the oldest piece showing that mesh, under a per-frame vertex budget
	                              (Flow.Budget by Graphics Quality; LOW: none); every other water piece takes the field at its
	                              centre as a multiply. The field is carried with a moving piece (no smear at a wave's speed).
	                              Still under Reduce Flashing.
	  CURTAINS  Palette.Curtains  MYTHIC: windblown spray sheets (Beams) off the rims in Curtains.On, leaning downwind and back
	                              from the travel, coloured from the field; still under Reduce Flashing; halved at LOW quality
	                              and for somebody else's effect under Reduce Enemy VFX. Beams, not particles.
	  SPRAY     Palette.Spray     MYTHIC: windblown spray flecks, Spray.Share of each effect's Default pieces, x Density.
	Every colour a lever draws is checked against Aqua's shipped Base / Light / Dark (12/255 on all three channels, every
	flow step included): a palette that fails draws without that lever, with one warning.
	Studio only: workspace attribute AquaLuxProf (cost in ms a frame per lever, counts, flow rates); StudioReduceFlashing
	stands in for the setting; LuxTune (JSON { WrapId = { Flow = {...}, Curtains = {...} } }) + LuxTuneN override palette
	numbers live for calibration.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local L = { _gen = 0, Stats = { Water = 0, Glow = 0, Tinted = 0, Copies = 0, CopyFail = 0, CopyVerts = 0, Worn = 0, Curtains = 0,
	Motes = 0, Spray = 0, ByKind = {}, MaxStep = 0, Max1s = 0, OffPalette = 0, Painted = 0 } }
local W, H                                   -- AquaWrap and its helpers (Init)
local TAU = 2 * math.pi
local noise = math.noise
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local STUDIO = RunService:IsStudio()
local WHITE = Color3.new(1, 1, 1)
local GUARD = 12 / 255

function L.Init(w, helpers) W, H = w, helpers end

----------------------------------------------------------------------------------------------------
-- settings
----------------------------------------------------------------------------------------------------
local Settings, Ident, VFX
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
local function fxFolder()
	if VFX == nil then
		local ok, m = pcall(function() return require(ReplicatedStorage.IceMagic.VFXLibrary) end)
		VFX = ok and m or false
	end
	local name = VFX and VFX.Config and VFX.Config.FXFolderName
	local f = name and workspace:FindFirstChild(name)
	if not f and name then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f or workspace
end
local rfT, rfOn = -10, false
--- Reduce Flashing (read once a second)
local function held()
	local now = os.clock()
	if now - rfT > 1 then
		rfT = now
		local S = settings()
		rfOn = (S and S.Get and S.Get("ReduceFlashing") == true) or (STUDIO and workspace:GetAttribute("StudioReduceFlashing") == true)
	end
	return rfOn
end
--- Graphics Quality: 2 HIGH, 1 MEDIUM, 0 LOW (CryoAurora's split)
local function detail()
	local S = settings()
	local d = (S and S.EffectDensity) or 1
	return d >= 0.9 and 2 or (d >= 0.6 and 1 or 0)
end
local function byDetail(t, dflt)
	if type(t) ~= "table" then return dflt end
	return t[3 - detail()] or dflt
end

local function near(c)
	for _, s in ipairs(identity()) do
		if math.abs(c.R - s.R) <= GUARD and math.abs(c.G - s.G) <= GUARD and math.abs(c.B - s.B) <= GUARD then return true end
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- the palette's own tables (once per palette): colours by Tone name, the flow's lookup, the guard
----------------------------------------------------------------------------------------------------
local function toLin(x) return x <= 0.04045 and x / 12.92 or ((x + 0.055) / 1.055) ^ 2.4 end
local function toSrgb(x) x = math.clamp(x, 0, 1) return x <= 0.0031308 and x * 12.92 or 1.055 * x ^ (1 / 2.4) - 0.055 end
local function oklab(c)
	local r, g, b = toLin(c.R), toLin(c.G), toLin(c.B)
	local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
	return { 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s }
end
local function fromOk(o)
	local l = (o[1] + 0.3963377774 * o[2] + 0.2158037573 * o[3]) ^ 3
	local m = (o[1] - 0.1055613458 * o[2] - 0.0638541728 * o[3]) ^ 3
	local s = (o[1] - 0.0894841775 * o[2] - 1.2914855480 * o[3]) ^ 3
	return Color3.new(toSrgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
		toSrgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
		toSrgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
end

local function luma(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end

local LUTN = 256                -- (R2A: 64 steps banded on screen once the field moves)
local prepared = setmetatable({}, { __mode = "k" })
local function prep(P)
	local X = prepared[P]
	if X then return X end
	X = {}
	prepared[P] = X
	local tone = P.Tone or {}
	local function col(v) return (type(v) == "string" and tone[v]) or (typeof(v) == "Color3" and v) or nil end
	local function list(names)
		local out = {}
		for _, v in ipairs(names or {}) do local c = col(v) if c then out[#out + 1] = c end end
		return out
	end
	local function set(names) local s = {} for _, n in ipairs(names or {}) do s[n] = true end return s end
	local bad = nil
	local function check(c, where) if c and near(c) then bad = bad or where end end
	-- GLOW
	if P.Glow then X.GlowSkip = set(P.Glow.Skip) X.NeonK = P.Glow.NeonK or 0.62 end
	-- MOTES
	if P.Motes then
		X.Mote = list(P.Motes.Colours)
		for i, c in ipairs(X.Mote) do check(c, "Motes " .. i) end
		if #X.Mote == 0 then X.Mote = nil end
	end
	-- FLOW: the stops in OKLab, LUTN steps (each step guarded); a normalised copy for the tint of a piece with no copy
	local F = P.Flow
	local function lutOf(stops, pos, where)
		local okl = {}
		for i, c in ipairs(stops) do okl[i] = oklab(c) end
		local out = {}
		for i = 0, LUTN - 1 do
			local x = i / (LUTN - 1)
			local j = 1
			while j < #stops - 1 and x > (pos and pos[j + 1] or j / (#stops - 1)) do j += 1 end
			local a = pos and pos[j] or (j - 1) / (#stops - 1)
			local b = pos and pos[j + 1] or j / (#stops - 1)
			local u = math.clamp((x - a) / math.max(1e-4, b - a), 0, 1)
			if not (F and F.Linear) then u = u * u * (3 - 2 * u) end
			local o1, o2 = okl[j], okl[j + 1]
			local c = fromOk({ o1[1] + (o2[1] - o1[1]) * u, o1[2] + (o2[2] - o1[2]) * u, o1[3] + (o2[3] - o1[3]) * u })
			check(c, where .. " step " .. i)
			out[i] = c
		end
		return out
	end
	if F then
		-- the curtains' own colours (Beams are not Neon: they take the rendered targets, Flow.Show, when given)
		local show = list(F.Show)
		if #show >= 2 then
			local ls = lutOf(show, F.Pos, "Flow.Show")
			X.LutS = {}
			for i = 0, LUTN - 1 do local c = ls[i] X.LutS[i] = { c.R, c.G, c.B } end
		end
		local stops, pos = list(F.Stops), F.Pos
		if #stops >= 2 then
			local ok = {}
			for i, c in ipairs(stops) do ok[i] = oklab(c) end
			local lut, lutN = {}, {}
			for i = 0, LUTN - 1 do
				local x = i / (LUTN - 1)
				local j = 1
				while j < #stops - 1 and x > (pos and pos[j + 1] or j / (#stops - 1)) do j += 1 end
				local a = pos and pos[j] or (j - 1) / (#stops - 1)
				local b = pos and pos[j + 1] or j / (#stops - 1)
				local u = math.clamp((x - a) / math.max(1e-4, b - a), 0, 1)
				if not F.Linear then u = u * u * (3 - 2 * u) end
				local o1, o2 = ok[j], ok[j + 1]
				local c = fromOk({ o1[1] + (o2[1] - o1[1]) * u, o1[2] + (o2[2] - o1[2]) * u, o1[3] + (o2[3] - o1[3]) * u })
				check(c, "Flow step " .. i)
				lut[i] = { c.R, c.G, c.B }
				-- a piece with no painted copy: the multiply that takes the wrap's body colour to this step (its vertices
				-- already wear the body), so it renders as the painted bodies do
				local bd = (P.Tone and P.Tone.Body) or Color3.new(0.5, 0.5, 0.5)
				local mix = F.TintMix or 0.9
				local function q(x, y) return 1 + (math.min(1, x / math.max(y, 0.05)) - 1) * mix end
				lutN[i] = Color3.new(q(c.R, bd.R), q(c.G, bd.G), q(c.B, bd.B))
			end
			X.Lut, X.LutN = lut, lutN
			X.Big = set(F.Big)
			X.Skip = set(F.Skip)
			X.Hue = F.Hues            -- (the palette's hue spans, for the off-palette share)
		end
	end
	-- CURTAINS / SPRAY
	if P.Curtains then X.CurtainOn = P.Curtains.On or {} end
	if P.Spray then X.SprayCol = list(P.Spray.Colours) for i, c in ipairs(X.SprayCol) do check(c, "Spray " .. i) end end
	if bad then
		warn("[AquaWrapLux] " .. tostring(P.Id) .. ": " .. bad .. " is within 12/255 of an Aqua identity colour - those levers are off")
		X.Lut, X.LutS, X.Mote, X.SprayCol, X.CurtainOn = nil, nil, nil, nil, nil
	end
	return X
end

----------------------------------------------------------------------------------------------------
-- the flow field: domain-warped noise in world space, one clock for everything (frozen under Reduce Flashing)
----------------------------------------------------------------------------------------------------
local clock = 0
local function dirOf(F)
	local d = F._dir
	if d then return d end
	local v = F.Dir or { 0.8, 0.3, 0.5 }
	local u = Vector3.new(v[1], v[2], v[3]).Unit
	local hz = Vector3.new(u.X, 0, u.Z)
	hz = hz.Magnitude > 1e-3 and hz.Unit or Vector3.xAxis
	d = { u.X, u.Y, u.Z, -hz.Z, hz.X }                 -- along the current (3D), across it (flat)
	F._dir = d
	return d
end
--- the field's still part at a world point (cached per painted vertex): the streaks laid along the current, where the
--- point sits along it, and the swell's phase offset there (its fronts bent)
local function fstat(F, x, y, z)
	local d = dirOf(F)
	local a = x * d[1] + y * d[2] + z * d[3]
	local c = x * d[4] + z * d[5]
	local wl = F.WarpL or 16
	local w = noise(a / (wl * 1.8), y / wl + 0.37, c / wl + 5.1)
	local po = (F.Bend or 0.6) * noise(c / (wl * 1.3) - 2.7, y / wl + 0.9, a / (wl * 2.2) + 1.9)
	return c / (F.Across or 10) + y / (F.Vert or 14) + (F.Warp or 0.9) * w, a, po
end
--- the swell: a wave running down the current at Speed studs/s, Wave studs long (-1 .. 1)
local function swell(F, a, po)
	return math.sin(TAU * ((a - (F.Speed or 5) * clock) / (F.Wave or 20) + po))
end
local function lutIdx(v)
	v -= math.floor(v)
	return math.floor(v * (LUTN - 1) + 0.5)
end
local function phase(F, x, y, z)
	local st, a, po = fstat(F, x, y, z)
	return lutIdx(st + (F.HueAmp or 0.035) * swell(F, a, po) - (F.Cycle or 0.015) * clock)
end
--- the colour index and the swell's light factor at a point (a piece with no painted copy: its centre)
local function fieldAt(F, x, y, z)
	local st, a, po = fstat(F, x, y, z)
	local wv = swell(F, a, po)
	return lutIdx(st + (F.HueAmp or 0.035) * wv - (F.Cycle or 0.015) * clock), 1 + (F.BrightAmp or 0.08) * wv
end

----------------------------------------------------------------------------------------------------
-- the cost meter (Studio: workspace attribute AquaLuxProf)
----------------------------------------------------------------------------------------------------
L._prof = {}
local function acc(k, d)
	local p = L._prof[k]
	if not p then p = { n = 0, sum = 0, max = 0 } L._prof[k] = p end
	p.n += 1 p.sum += d p.max = math.max(p.max, d)
end
local pubT = 0
local function publish()
	if not STUDIO then return end
	local now = os.clock()
	if now < pubT then return end
	pubT = now + 0.5
	local out = { Stats = L.Stats, Prof = {} }
	for k, p in pairs(L._prof) do
		out.Prof[k] = { ms = p.n > 0 and math.floor(p.sum / p.n * 1e5) / 100 or 0, maxms = math.floor(p.max * 1e5) / 100, n = p.n }
	end
	pcall(function() workspace:SetAttribute("AquaLuxProf", game:GetService("HttpService"):JSONEncode(out)) end)
end

----------------------------------------------------------------------------------------------------
-- FLOW painting: the wrap's OWN shared copy of a big body's mesh (AquaWrap's, one per mesh and wrap) is painted per
-- vertex -- no extra EditableMesh (the client's EditableMesh budget is the limit for Aqua wraps). Its vertices take the
-- field at the world points of the mesh's PRIMARY live piece (the oldest one showing); a second piece of the same mesh
-- in the same wrap at the same time shows the same colours (rare: one Twin Tide, one tank, one wave each). The arrays
-- (positions, the wrap's own colours) are read once per mesh, off the draw path, before the first paint.
----------------------------------------------------------------------------------------------------
local shared = setmetatable({}, { __mode = "k" })   -- [EditableMesh] = { Ids, U, Base, Sh, Fo, N, Cur, Prev } | true (reading)
local lastUse = 0

local function srcOf(p)
	local ok, mc = pcall(function() return p.MeshContent end)
	local o = ok and mc and mc.Object
	return (o and o:IsA("EditableMesh")) and o or nil
end

local function readShared(em, P, name)
	shared[em] = true
	task.defer(function()
		local c = { EM = em, Name = name, Ids = {}, U = {}, Base = {}, Sh = {}, Fo = {}, N = 0, Cur = 1 }
		local ok = pcall(function()
			local posOf, lo, hi = {}, Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, v in ipairs(em:GetVertices()) do
				local q = em:GetPosition(v)
				posOf[v] = q
				lo, hi = lo:Min(q), hi:Max(q)
			end
			local mid, ext = (lo + hi) / 2, hi - lo
			ext = Vector3.new(math.max(ext.X, 1e-4), math.max(ext.Y, 1e-4), math.max(ext.Z, 1e-4))
			local vOf = {}
			for _, f in ipairs(em:GetFaces()) do
				local vs, cs = em:GetFaceVertices(f), em:GetFaceColors(f)
				for i = 1, 3 do if cs[i] and not vOf[cs[i]] then vOf[cs[i]] = vs[i] end end
			end
			local bodyY = luma(P.Tone and P.Tone.Body or Color3.fromRGB(32, 64, 64))
			local F = P.Flow
			local n = 0
			for _, id in ipairs(em:GetColors()) do
				local v = vOf[id]
				if v then
					n += 1
					local col = em:GetColor(id)
					local y = luma(col)
					local _, sat = col:ToHSV()
					c.Ids[n] = id
					c.U[n] = (posOf[v] - mid) / ext
					c.Base[n] = col
					-- the shade (the mesh's own trough-to-crest structure), compressed: the render's contrast is steep
					c.Sh[n] = math.clamp(1 + (F.Shade or 0.35) * (y / math.max(bodyY, 0.02) - 1), 0.6, 1.3)
					-- the foam (pale, unsaturated) keeps the wrap's spray colour; the water takes the field
					c.Fo[n] = math.clamp((y - (F.FoamY or 0.62)) / 0.18, 0, 1) * math.clamp((0.3 - sat) / 0.2, 0, 1)
				end
			end
			c.N = n
			c.Prev = table.create(n, 0)
		end)
		if ok and c.N > 0 then
			shared[em] = c
			L.Stats.Copies += 1
			L.Stats.CopyVerts += c.N
		else
			shared[em] = false
			L.Stats.CopyFail += 1
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- the pieces: glow, pulse, flow
----------------------------------------------------------------------------------------------------
local items = {}          -- [part] = { P, X, Base, K, Flow, Big, Seq, Last, P0, CF0, SZ }
local hosts = {}          -- [part] = curtain host
local motes = {}          -- live motes and spray flecks
local stepConn
local step
local seq = 0

local warned = false
local function ensureStep()
	if not stepConn then
		stepConn = RunService.RenderStepped:Connect(function(dt)
			local ok, err = pcall(step, dt)
			if not ok and not warned then warned = true warn("[AquaWrapLux] " .. tostring(err)) end
		end)
	end
end

--- a fresh kit piece in wrap P (AquaWrap.Dress, after the wrap's own dressing). Pieces whose mesh AquaWrap recolours
--- ("water") and its tinted ones ("Tint": the Twin Tide flipbook frames, never copied) glow and take the flow.
local seenP = setmetatable({}, { __mode = "k" })
function L.Dress(p, kind, P)
	if not (typeof(p) == "Instance" and p:IsA("BasePart")) then return end
	seenP[P] = true
	local X = prep(P)
	local g = H.group(p.Name)
	if X.CurtainOn and X.CurtainOn[g] then L.Curtains(p, P, X.CurtainOn[g]) end
	local mode = H.modeOf(P, p.Name)
	if not (kind == "solid" or kind == "glass") or not (mode == "water" or mode == "Tint") then return end
	seq += 1
	L.Stats.Water += 1                                         -- (glow coverage: Glow / Water)
	local it = { P = P, X = X, Base = p.Color, Seq = seq }   -- (Seq: a strict age -- two walls born in one frame never swap)
	if mode == "water" and p:GetAttribute("AquaWrapId") ~= P.Id then
		-- a stand-in (this mesh's copy in the wrap is not built yet, or the client's EditableMesh budget refused it): the
		-- palette's own StandIn multiply over Default's blue vertices (a per-channel ratio turned their pale blue pink)
		it.Base = P.StandIn or Color3.new(0.8, 0.8, 0.8)
		it.Stand = true
	end
	if P.Glow and not X.GlowSkip[g] then
		p.Material, p.Reflectance = Enum.Material.Neon, 0
		it.K = X.NeonK
		L.Stats.Glow += 1
	end
	if X.Lut and not X.Skip[g] then
		it.Flow = true
		it.Big = (mode == "water" and not it.Stand and X.Big[g]) or nil
		L.Stats.Tinted += 1
	end
	if it.K or it.Flow then
		local k = it.K or 1
		p.Color = Color3.new(it.Base.R * k, it.Base.G * k, it.Base.B * k)
		it.Last = p.Color
		items[p] = it
		ensureStep()
	end
end

----------------------------------------------------------------------------------------------------
-- CURTAINS: windblown spray sheets off a rim (the piece's top edge, along its own X)
----------------------------------------------------------------------------------------------------
local function windAt(t)
	local gw = workspace.GlobalWind
	if gw.Magnitude > 0.5 then return Vector3.new(gw.X, 0, gw.Z).Unit end
	local a = 0.6 + 0.35 * math.sin(t * 0.021)          -- a slow-turning breeze when the place has no wind
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

function L.Curtains(p, P, n)
	local C = P.Curtains
	local mine = Players.LocalPlayer and W.Ctx and W.Ctx.Caster == Players.LocalPlayer.Character
	local S = settings()
	if detail() == 0 then n = math.ceil(n / 2) end
	if S and S.ThinEnemyVFX and not mine then n = math.ceil(n / 2) end
	local list = {}
	for i = 1, n do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = "LuxCurtain0", "LuxCurtain1"
		a0.Parent, a1.Parent = p, p
		local bm = Instance.new("Beam")
		bm.Name = "LuxCurtain"
		bm.Attachment0, bm.Attachment1 = a0, a1
		bm.FaceCamera, bm.Segments = true, 10
		bm.Texture, bm.TextureMode, bm.TextureLength, bm.TextureSpeed = SMOKE, Enum.TextureMode.Stretch, 1, C.Speed or 0.5
		bm.LightEmission, bm.LightInfluence, bm.Brightness = C.Emission or 0.5, C.Influence or 0.35, C.Brightness or 1.3
		local t0 = C.T or 0.55
		bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, math.min(1, t0 + 0.2)), NumberSequenceKeypoint.new(0.12, t0),
			NumberSequenceKeypoint.new(0.55, math.min(1, t0 + 0.22)), NumberSequenceKeypoint.new(1, 1) })
		bm.Width0, bm.Width1 = 0.1, 0.1
		bm.Parent = p
		list[i] = { A0 = a0, A1 = a1, B = bm, U = (i - 0.5) / n - 0.5, Ph = math.random() * 10, Up = 0 }
	end
	hosts[p] = { P = P, X = prep(P), List = list, N = n, Born = os.clock(), ColT = 0 }
	L.Stats.Curtains += n
	ensureStep()
end

local function stepCurtains(now, dt, still)
	for p, h in pairs(hosts) do
		if not p.Parent then
			hosts[p] = nil
		else
			local pos = p.Position
			if pos.Y > -5000 then
				local C = h.P.Curtains
				local vel = h.LastPos and (pos - h.LastPos) / math.max(dt, 1e-3) or Vector3.zero
				h.LastPos = pos
				if vel.Magnitude > 400 then vel = Vector3.zero end
				local back = Vector3.new(-vel.X, 0, -vel.Z)
				back = back.Magnitude > 1 and back.Unit * math.min(1, back.Magnitude / 60) or Vector3.zero
				local lean = (windAt(clock) * (C.Lean or 0.6) + back * (C.Back or 1.2))
				local sz = p.Size
				local Hh = (C.Height or 7) * math.clamp(sz.X / (C.RefX or sz.X), 0.3, 1.5)
				local grow = math.min(1, (now - h.Born) / 0.35)
				local cf = p.CFrame
				local w0 = sz.X / h.N * (C.WidthK or 1.1)
				for _, c in ipairs(h.List) do
					local base = Vector3.new(c.U * sz.X * 0.92, sz.Y * 0.45, 0)
					local sway = still and 0 or noise(clock * 0.35, c.Ph, 0.5) * (C.Sway or 1.4)
					local topW = (cf * base) + Vector3.new(0, Hh * grow, 0) + lean * Hh * grow + Vector3.new(sway, 0, sway * 0.6)
					c.A0.Position = base
					c.A1.Position = cf:PointToObjectSpace(topW)
					c.B.Width0, c.B.Width1 = w0, w0 * (C.Fan or 1.9)
					c.B.CurveSize0 = still and 0 or (C.Curl or 2) * noise(clock * 0.25, c.Ph, 2.5)
					c.B.CurveSize1 = still and 0 or -(C.Curl or 2) * 0.8 * noise(clock * 0.22, c.Ph, 4.5)
					c.B.TextureSpeed = still and 0 or (C.Speed or 0.5)
				end
				if now >= h.ColT and h.X.Lut then
					h.ColT = now + 0.15
					local F = h.P.Flow
					local kps = {}
					for k = 0, 2 do
						local q = (cf * Vector3.new(0, sz.Y * 0.45, 0)) + Vector3.new(0, Hh * k / 2, 0)
						local v = (h.X.LutS or h.X.Lut)[phase(F, q.X, q.Y, q.Z)]
						local lift = (C.Lift or 0.3) + k * (C.LiftUp or 0.2)   -- (spray: pale, the field's colour in it)
						kps[k + 1] = ColorSequenceKeypoint.new(k / 2, Color3.new(v[1] + (1 - v[1]) * lift, v[2] + (1 - v[2]) * lift, v[3] + (1 - v[3]) * lift))
					end
					local cs = ColorSequence.new(kps)
					for _, c in ipairs(h.List) do c.B.Color = cs end
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- MOTES and SPRAY: extra pieces counted against the Default pieces the same effect throws
----------------------------------------------------------------------------------------------------
-- the remainders carry from cast to cast per caster and effect (a Sidearm shot throws ~9 pieces: a per-call share would
-- never reach one extra), so the long-run share is exact
local accum = setmetatable({}, { __mode = "k" })
local MAX_MOTES = 110

local function kindStat(ctx)
	local k = tostring(ctx and ctx.P and ctx.P.Id or "?") .. ":" .. tostring((ctx and ctx.Kind) or "?")
	local s = L.Stats.ByKind[k]
	if not s then s = { Default = 0, Drift = 0, Motes = 0, Spray = 0, Density = 0 } L.Stats.ByKind[k] = s end
	return s
end

local function newBall(name, size, colour, neon)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Color = colour
	p.Size = Vector3.one * size
	return p
end

local function spawnMote(at, P, X, ctx)
	local M = P.Motes
	local s0 = (M.Size or 0.16) * (0.7 + 0.6 * math.random())
	local p = newBall("LuxMote", s0, X.Mote[1], true)
	local life = (M.Life or 2) * (0.75 + 0.5 * math.random())
	local a = math.random() * TAU
	local v = Vector3.new(math.cos(a), 0.4 + math.random() * 0.6, math.sin(a)) * ((M.Speed or 1.2) * (0.5 + math.random()))
	p.CFrame = CFrame.new(at + Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5) * (M.Spread or 1.4))
	p.Parent = fxFolder()
	motes[#motes + 1] = { Part = p, Kind = "mote", Pos = p.Position, V = v, Born = os.clock(), Life = life, S0 = s0,
		Cols = X.Mote, Ph = math.random() * 10, P = P }
	L.Stats.Motes += 1
	kindStat(ctx).Motes += 1
	W.Extra()
end

local function spawnSpray(at, P, X, ctx)
	local S = P.Spray
	local s0 = (S.Size or 0.22) * (0.7 + 0.6 * math.random())
	local cols = (X.SprayCol and #X.SprayCol > 0) and X.SprayCol or { WHITE }
	local p = newBall("LuxSpray", s0, cols[1], false)
	local life = (S.Life or 0.9) * (0.75 + 0.5 * math.random())
	local a = math.random() * TAU
	local v = Vector3.new(math.cos(a) * 3, 5 + math.random() * 6, math.sin(a) * 3)
	p.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0))
	p.Parent = fxFolder()
	motes[#motes + 1] = { Part = p, Kind = "spray", Pos = p.Position, V = v, Born = os.clock(), Life = life, S0 = s0, Cols = cols,
		Ph = math.random() * 10, P = P }
	L.Stats.Spray += 1
	kindStat(ctx).Spray += 1
	W.Extra()
end

--- one Default splash piece thrown at `at` in wrap P (AquaWrap.Piece; `due`: the wrap's Drift piece goes with it)
function L.Piece(at, P, ctx, due)
	local ks = kindStat(ctx)
	ks.Default += 1
	if due then ks.Drift += 1 end
	ks.Density = math.floor(W.Density(ctx and ctx.Caster) * 100) / 100
	if typeof(at) ~= "Vector3" or #motes >= MAX_MOTES then return end
	local X = prep(P)
	local who = (ctx and typeof(ctx.Caster) == "Instance") and ctx.Caster or L
	local byKind = accum[who]
	if not byKind then byKind = {} accum[who] = byKind end
	local kk = (ctx and ctx.Kind) or "?"
	local a = byKind[kk]
	if not a then a = { m = 0, s = 0 } byKind[kk] = a end
	local d = W.Density(ctx and ctx.Caster)
	seenP[P] = true
	if P.Motes and X.Mote then
		a.m += (P.Motes.Share or 0) * d
		if a.m >= 1 then a.m -= 1 spawnMote(at, P, X, ctx) end
	end
	if P.Spray then
		a.s += (P.Spray.Share or 0) * d
		if a.s >= 1 then a.s -= 1 spawnSpray(at, P, X, ctx) end
	end
	ensureStep()
end

local function stepMotes(now, dt, pulseS)
	for i = #motes, 1, -1 do
		local m = motes[i]
		local e = now - m.Born
		if e > m.Life or not m.Part.Parent then
			if m.Part.Parent then m.Part:Destroy() end
			table.remove(motes, i)
		else
			local k = e / m.Life
			local cols = m.Cols
			if m.Kind == "mote" then
				-- plankton: drifts, slows, wanders and rises a little; breathes with the body; colours over its life
				m.V *= math.max(0, 1 - 1.6 * dt)
				local wob = Vector3.new(math.sin(m.Ph + e * 2.1), 0, math.cos(m.Ph + e * 1.7)) * 0.35
				m.Pos += (m.V + wob + Vector3.new(0, (m.P.Motes.Rise or 0.3), 0)) * dt
				local s = m.S0 * (1 + 0.25 * pulseS) * math.max(0.02, 1 - math.clamp((k - 0.65) / 0.35, 0, 1))
				m.Part.Size = Vector3.one * math.max(0.02, s)
			else
				-- spray: thrown up, blown downwind, dragged, falling; shrinks away
				local wind = windAt(clock) * ((m.P.Spray.Wind or 14))
				m.V += (wind - m.V * (m.P.Spray.Drag or 1.4) + Vector3.new(0, -(m.P.Spray.Gravity or 22), 0)) * dt
				m.Pos += m.V * dt
				m.Part.Size = Vector3.one * math.max(0.02, m.S0 * (1 - math.clamp((k - 0.45) / 0.55, 0, 1)))
			end
			m.Part.CFrame = CFrame.new(m.Pos)
			local c = (#cols >= 3) and ((k < 0.5) and cols[1]:Lerp(cols[2], k * 2) or cols[2]:Lerp(cols[3], (k - 0.5) * 2))
				or (cols[2] and cols[1]:Lerp(cols[2], k) or cols[1])
			m.Part.Color = c
		end
	end
end

----------------------------------------------------------------------------------------------------
-- the one loop
----------------------------------------------------------------------------------------------------
local paintOrder, paintI = {}, 0
local sampleT, ring = 0, setmetatable({}, { __mode = "k" })
local offN, offTot = 0, 0

--- paint up to `budget` vertices of shared copy `c` from the field at its primary piece `p` (item `it`)
local function paint(c, it, p, budget)
	local X, F = it.X, it.P.Flow
	local em, lut = c.EM, X.Lut
	local n, cur = c.N, c.Cur
	-- the field points: each vertex where it stood when the primary piece was first placed (its frame then, at the
	-- template's full size), so the colours ride with the water as it moves, grows and spins, and change only with the clock
	if c.WPOwner ~= it or c.Gen ~= L._gen then
		c.WPOwner, c.Gen = it, L._gen
		if c.WP then table.clear(c.WP) table.clear(c.WA) table.clear(c.WC) table.clear(c.WY)
		else c.WP, c.WA, c.WC, c.WY = {}, {}, {}, {} end            -- (filled as they are painted: no spike on a new owner)
		c.PassStart, c.Done = c.Cur, 0                              -- (a whole pass for this primary ends back here)
	end
	local wp, wa, wc, wy = c.WP, c.WA, c.WC, c.WY
	local cf0, sz = it.CF0 or p.CFrame, it.SZ or p.Size
	local count = math.min(budget, n)
	local maxStep = 0
	local prev = c.Prev
	local countable = (c.Full or 0) >= 1                         -- (steps count once this primary has painted it all through)
	local hamp, bamp, slide = F.HueAmp or 0.035, F.BrightAmp or 0.08, (F.Cycle or 0.015) * clock
	local used, done = 0, 0                                      -- (a vertex whose field point is new costs 3: its noise)
	for _ = 1, count do
		local i = cur
		local st = wp[i]
		if not st then
			local w = cf0 * (c.U[i] * sz)
			st, wa[i], wc[i] = fstat(F, w.X, w.Y, w.Z)
			wp[i], wy[i] = st, w.Y
			used += 2
		end
		used += 1
		done += 1
		local wv = swell(F, wa[i], wc[i])
		local v = lut[lutIdx(st + hamp * wv - slide)]
		local k, f = c.Sh[i] * (1 + bamp * wv), c.Fo[i]
		local r, g, b = v[1] * k, v[2] * k, v[3] * k
		if f > 0 then
			local bc = c.Base[i]
			r, g, b = r + (bc.R - r) * f, g + (bc.G - g) * f, b + (bc.B - b) * f
		end
		r, g, b = math.min(r, 1), math.min(g, 1), math.min(b, 1)
		if STUDIO then
			local old = prev[i]
			if type(old) == "table" then
				if countable then                                      -- (a step only counts within one primary's own painting)
					local st = math.max(math.abs(r - old[1]), math.abs(g - old[2]), math.abs(b - old[3]))
					if st > maxStep then maxStep = st end
					if st * 100 > L.Stats.MaxStep and st > 0.1 then      -- (Studio: where the largest step was)
						L.Stats.MaxStepAt = { Mesh = c.Name or "?", I = i, Old = { old[1], old[2], old[3] }, New = { r, g, b },
							Full = c.Full, Seq = it.Seq, Clock = clock, Fo = f, Sh = k, Dt = os.clock() - (old[4] or 0) }
					end
				end
				old[4] = os.clock()
				old[1], old[2], old[3] = r, g, b
			else
				prev[i] = { r, g, b }
			end
		end
		em:SetColor(c.Ids[i], Color3.new(r, g, b))
		cur = cur % n + 1
		if used >= budget then break end
	end
	c.Done = (c.Done or 0) + done
	if c.Done >= n and c.Owner == it then                              -- (whole passes done for this primary, from its own start)
		c.Full = (c.Full or 0) + math.floor(c.Done / n)
		c.Done = c.Done % n
	end
	c.Cur = cur
	if STUDIO and countable and maxStep * 100 > L.Stats.MaxStep then L.Stats.MaxStep = math.floor(maxStep * 1000) / 10 end
	L.Stats.Painted += done
	return used
end

local live = {}           -- [shared copy] = its primary item and part this frame

local tuneN = nil
local function tune()                                    -- (Studio: LuxTune / LuxTuneN, live palette numbers)
	local tn = workspace:GetAttribute("LuxTuneN")
	if tn == tuneN then return end
	tuneN = tn
	local ok, t = pcall(function() return game:GetService("HttpService"):JSONDecode(workspace:GetAttribute("LuxTune") or "{}") end)
	if not (ok and type(t) == "table") then return end
	for P in pairs(seenP) do
		local o = t[P.Id]
		if type(o) == "table" then
			for sec, vals in pairs(o) do
				if type(P[sec]) == "table" and type(vals) == "table" then for k, v in pairs(vals) do P[sec][k] = v end end
			end
			if P.Flow then P.Flow._dir = nil end
			prepared[P] = nil
		end
	end
	for _, it in pairs(items) do it.X = prep(it.P) end
	for _, h in pairs(hosts) do h.X = prep(h.P) end
	L._gen += 1
	L.Stats.MaxStep, L.Stats.Max1s, L.Stats.OffPalette, L.Stats.MaxStepAt = 0, 0, 0, nil   -- (the meters restart)
	offN, offTot = 0, 0
	table.clear(L._prof)
	for k in pairs(ring) do ring[k] = nil end
end

step = function(dt)
	local t0 = os.clock()
	if STUDIO then pcall(tune) end
	local still = held()
	if not still then clock += dt end
	local now = os.clock()
	local any = false
	-- PULSE: one breath for every glow body (by the first live palette's Pulse)
	local pulseS = 0
	local amp, period = 0, 2.25
	for _, it in pairs(items) do
		local pu = it.P.Pulse
		if pu then amp, period = pu.Amp or 0.15, pu.Period or 2.25 end
		break
	end
	if not still then pulseS = math.sin(TAU * now / period) end
	local kNow = 1 + amp * pulseS
	-- the pieces
	table.clear(paintOrder)
	table.clear(live)
	local tPulse = os.clock()
	for p, it in pairs(items) do
		if not p.Parent or p.Color ~= it.Last then             -- (gone, or recoloured by its effect -- the jet's flash: let go)
			items[p] = nil
		else
			any = true
			local pos = p.Position
			if pos.Y > -5000 then
				if not it.P0 then
					it.P0, it.CF0 = pos, p.CFrame
					local ts = p:GetAttribute("TemplateSize")
					it.SZ = typeof(ts) == "Vector3" and ts or p.Size
				end
				local tint = WHITE
				if it.Flow then
					lastUse = now
					local c
					if it.Big and byDetail(it.P.Flow.Budget, 0) > 0 then           -- (LOW quality: the multiply only)
						local em = srcOf(p)
						c = em and shared[em]
						if em and c == nil then readShared(em, it.P, p.Name) end
					end
					if type(c) == "table" then
						-- the oldest piece showing is the one whose world points the copy is painted at
						local cur = live[c]
						if not cur or it.Seq < cur[1].Seq then live[c] = { it, p } end
					else
						local li, lk = fieldAt(it.P.Flow, it.P0.X, it.P0.Y, it.P0.Z)
						local tn = it.X.LutN[li]
						tint = Color3.new(tn.R * lk, tn.G * lk, tn.B * lk)
					end
				end
				local k = (it.K or 1) * (it.K and kNow or 1)
				local b = it.Base
				p.Color = Color3.new(math.min(1, b.R * k * tint.R), math.min(1, b.G * k * tint.G), math.min(1, b.B * k * tint.B))
				it.Last = p.Color
			end
		end
	end
	for c, pr in pairs(live) do
		if c.Owner ~= pr[1] then c.Owner, c.Full = pr[1], 0 end
		paintOrder[#paintOrder + 1] = c
	end
	acc("pieces", os.clock() - tPulse)
	-- FLOW: paint the shared copies in use under this frame's budget, round-robin
	if #paintOrder > 0 then
		local tf = os.clock()
		local P = paintOrder[1].Owner.P
		local budget = still and 0 or byDetail(P.Flow.Budget, 0)
		if still then
			for _, c in ipairs(paintOrder) do                      -- (held: painted once through, then still)
				if not c.HeldPainted then c.HeldPainted = true local pr = live[c] paint(c, pr[1], pr[2], c.N * 3) end
			end
		else
			local n = #paintOrder
			for _ = 1, n do
				if budget <= 0 then break end
				paintI = paintI % n + 1
				local c = paintOrder[paintI]
				local pr = live[c]
				c.HeldPainted = false
				budget -= paint(c, pr[1], pr[2], math.min(budget, c.N))
			end
		end
		acc("flow", os.clock() - tf)
		-- (Studio: the fastest 1 s colour change, sampled at 10 Hz on a few vertices of each painted copy, its own primary)
		if STUDIO and now >= sampleT then
			sampleT = now + 0.1
			for _, c in ipairs(paintOrder) do
				local it = c.Owner
				local r = ring[c]
				if not r or r.Owner ~= it or (c.Full or 0) < 1 then r = { Owner = it } ring[c] = r end   -- (from its first full pass on)
				local snap = {}
				for q = 1, 8 do
					local i = math.floor((q - 0.5) / 8 * c.N) + 1
					local ok, col = pcall(c.EM.GetColor, c.EM, c.Ids[i])
					if ok then
						snap[q] = col
						-- (off-palette: a coloured vertex whose hue sits outside the palette's hue spans; darks and greys pass)
						local hs = it.X.Hue
						local h, sat, val = col:ToHSV()
						if hs and sat > 0.2 and val > 0.12 then
							offTot += 1
							local inside = false
							for _, span in ipairs(hs) do if h * 360 >= span[1] and h * 360 <= span[2] then inside = true end end
							if not inside then offN += 1 end
							L.Stats.OffPalette = math.floor(offN / offTot * 1000) / 10
						end
					end
				end
				table.insert(r, 1, snap)
				if #r > 11 then
					local old = r[11]
					for q = 1, 8 do
						local a, b2 = snap[q], old[q]
						if a and b2 then
							local d = math.max(math.abs(a.R - b2.R), math.abs(a.G - b2.G), math.abs(a.B - b2.B)) * 100
							if d > L.Stats.Max1s then L.Stats.Max1s = math.floor(d * 10) / 10 end
						end
					end
				end
				r[12] = nil
			end
		end
	end
	-- CURTAINS, MOTES
	local tc = os.clock()
	if next(hosts) then any = true stepCurtains(now, dt, still) end
	acc("curtains", os.clock() - tc)
	local tm = os.clock()
	if #motes > 0 then any = true stepMotes(now, dt, pulseS) end
	acc("motes", os.clock() - tm)
	acc("total", os.clock() - t0)
	publish()
	if not any and stepConn then stepConn:Disconnect() stepConn = nil end
end

--- (Studio) the flow's colour at a world point now, and the share of painted colours outside the palette's hues
function L.Sample(P, pos)
	local X = prep(P)
	if not X.Lut then return nil end
	local v = X.Lut[phase(P.Flow, pos.X, pos.Y, pos.Z)]
	return Color3.new(v[1], v[2], v[3])
end

--- (Warm) nothing to build: the flow paints the wrap's own copies (kept for AquaWrap's hook)
function L.Warm(P, builtOf) end

return L
