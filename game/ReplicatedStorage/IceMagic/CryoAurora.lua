--[[
	CryoAurora  (ModuleScript)  ->  ReplicatedStorage/IceMagic/CryoAurora

	The Mythic wrap's (Aurora) own pieces, used by CryoWrap only while an Aurora caster draws. v8 (2026-10-17): the flow
	lives INSIDE the crystals; the floor is a calm base that sets them off; the sky light is slim and faint.

	  CRYSTAL COPIES   The Default crystals (the Flash Freeze spikes, the Mirror Cage's floor crystals, the M1 shard's
	                   body) are SpecialMesh pieces: one colour each. For Aurora the kit builders ask KitCopy for a
	                   MeshPart wearing a FixedSize EditableMesh copy of the same mesh, re-cut into LV height levels (a
	                   level's vertices share one colour, so a frame's paint is LV + 1 colours), in KX variants, each with
	                   its own flow: pockets of mint, emerald, aqua, cyan and pale white-green drifting along the crystal
	                   (mostly up, now and then back) at a slow speed that wanders, soft-edged, cross-fading slowly; a
	                   twinkle travels up inside now and then; a thin white-hot edge only at the tip. A piece takes a
	                   variant by its place (neighbours differ); its own Color (which multiplies the vertex colours)
	                   follows a slow wave of light that wanders through the zone in world space (A.FieldTint), so
	                   neighbours are loosely alike and no two are in step. Built one at a time in the background (the
	                   first cast draws the stepped fallback meanwhile; then the wrap drops its pools so the next cast
	                   takes them); released once nobody has worn the wrap for a minute.
	  SHATTER SLABS    Clean frosted ice: a pale aurora-tinted Ice copy, its top a soft pale, its thin sides lit.
	  CAGE PLATES      A thin bright edge round each face (CryoWrap insets a ring), a faint flowing inner glow.
	  FLOOR            A calm base laid over the zone's own disc (FF_Sheet / CryoDisc), one of three looks (A.FLOORS):
	                   (a) clear frosted ice, (b) dark green-teal glass, (c) faint frost with an aurora ring at the rim.
	                   Lit materials, no glow: the colour is only the crystals' light bleeding in near the rim and faint
	                   slow veils under the surface.
	  SKY LIGHT        Curtains (slim, faint Beams round the rim), halos behind the crystal ring, a light low haze, a few
	                   tiny sparkles; through VFXLibrary.Emitter (Beams gated here like emitter()).
	Everything moves on one clock (A.Advance): integrated with dt every frame, still under Reduce Flashing (no twinkles);
	Graphics Quality LOW paints at half rate without twinkles.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local A = { Stats = { Copies = 0, Failed = 0, Verts = 0, Ids = 0, Released = 0 } }
local W                                       -- CryoWrap (A.Init)
local buildField                              -- (the floor: below)
local levelsOf                                -- (a copy's level ids: below)
local copies = {}                             -- [key] = copy | true (building) | false (failed: the stepped fallback)
local desired = setmetatable({}, { __mode = "k" })   -- [part] = the Color it is held to
local pending = {}                            -- [palette] = copies became ready since the wrap last looked
local lastUse, conn = 0, nil
local LV = 5                                  -- a crystal copy's height levels: its colour is sampled at LV + 1 heights
local KX = 1                                  -- (v9: every crystal gets its own copy; the shared one is its source)
local CELLS, cellList, cellOf = {}, {}, setmetatable({}, { __mode = "k" })   -- (v9) the crystals' cell copies; [part] = its cell
local CELL = 4                                -- a cell's size (studs): crystals of one shape inside it share a copy
local VOID = Color3.fromRGB(6, 44, 32)        -- the field's dark voids: deep green-teal, never indigo
local HOLD = Color3.new(0.9, 0.9, 0.9)        -- a crystal's own Color (it multiplies the vertex colours)
local TAU = 2 * math.pi
local noise = math.noise
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local GLOW = "rbxasset://textures/particles/explosion01_implosion_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GREY = Color3.new(0.64, 0.64, 0.64)     -- (a crystal's Color until the wave sets it: Neon blooms, held below white)
local BLACK = Color3.new(0, 0, 0)
local SLAB_COL = Color3.fromRGB(190, 236, 208)                 -- the shatter slabs: pale aurora-tinted frosted ice
local SLAB_IN, SLAB_EDGE = Color3.new(0.84, 0.9, 0.87), Color3.new(1, 1, 1)
local TUNE = { g0 = 0.6, g1 = 0.32, l0 = 0.74, l1 = 0.55 }    -- (the crystals' brightness: the wave's range, the pockets' light)

function A.Init(w) W = w end

local function settingsMod()
	local ok, s = pcall(function() return require(ReplicatedStorage.Spellshot.SpellshotSettings) end)
	return ok and s or nil
end
local rfT, rfOn = -10, false
local function hold()
	local now = os.clock()
	if now - rfT > 1 then
		local s = settingsMod()
		rfT = now
		rfOn = (s and s.Get and s.Get("ReduceFlashing") == true) or (RunService:IsStudio() and workspace:GetAttribute("StudioReduceFlashing") == true)
	end
	return rfOn
end

----------------------------------------------------------------------------------------------------
-- the clock: a slow drift whose DIRECTION wanders (noise over time), integrated with dt once a frame. The wave of light
-- through the crystals, the floor's veils and the ring move with it: no loop, no rotation, no steps.
----------------------------------------------------------------------------------------------------
local FLD = { t = 0, last = nil, off = { Vector2.zero, Vector2.zero, Vector2.zero, Vector2.zero }, detail = 2, dT = 0, dt = 0,
	frame = 0, mask = false, sn = 0, fn = 0 }
local LAYER = { { 0.5, 0.040, 11.3 }, { 1.9, 0.058, 37.1 }, { 2.5, 0.064, 71.9 }, { 0.9, 0.043, 5.7 } }   -- studs/s, wander, seed
function A.Advance()
	local now = os.clock()
	if FLD.last and now - FLD.last < 0.002 then return end           -- (once a frame, however many samples)
	local dt = FLD.last and math.min(0.1, now - FLD.last) or 0
	FLD.last = now
	FLD.frame += 1
	FLD.dt = 0
	if now > FLD.dT then                                    -- (Graphics Quality, read once a second)
		FLD.dT = now + 1
		local st = settingsMod()
		local d = st and tonumber(st.EffectDensity) or 1
		FLD.detail = d >= 0.9 and 2 or (d >= 0.6 and 1 or 0)               -- (HIGH+ / MEDIUM / LOW)
	end
	FLD.mask = RunService:IsStudio() and workspace:GetAttribute("AuroraMask") == true   -- (Studio: the test stage's mask)
	if RunService:IsStudio() and now > (FLD.tuneT or 0) then             -- (Studio: live tuning, AuroraTune JSON)
		FLD.tuneT = now + 1
		local js = workspace:GetAttribute("AuroraTune")
		if type(js) == "string" and js ~= FLD.tuneJs then
			FLD.tuneJs = js
			local ok, t = pcall(function() return game:GetService("HttpService"):JSONDecode(js) end)
			if ok and type(t) == "table" then
				for path, v in pairs(t) do
					local a, b, c = string.match(path, "^(%w+)%.(%w+)%.?(%w*)$")
					local tab = a == "TUNE" and TUNE or (a == "FLOORS" and A.FLOORS) or nil
					if tab and c ~= "" then tab = tab[b] b = c end
					if type(v) == "table" then v = Color3.fromRGB(v[1], v[2], v[3]) end
					if type(tab) == "table" then tab[b] = v end
				end
			end
		end
	end
	if hold() then return end                               -- (Reduce Flashing: everything stands still)
	FLD.t += dt
	FLD.dt = dt
	for i, L in ipairs(LAYER) do
		local th = TAU * 1.6 * noise(FLD.t * L[2], L[3], 0.37)
		FLD.off[i] += Vector2.new(math.cos(th), math.sin(th)) * (L[1] * dt)
	end
end
--- the wave of light at world (x, z), 0..1: crystals' brightness and the floor's bleed (neighbours loosely alike)
local function waveAt(x, z)
	local o = FLD.off[1]
	return math.clamp(0.5 + 1.4 * noise((x + o.X) / 9, (z + o.Y) / 9, FLD.t * 0.05), 0, 1)
end
--- the pocket hue at world (x, z): a saturated middle of the flow (emerald .. aqua .. cyan)
local function hueAt(P, x, z)
	local o = FLD.off[1]
	local q = math.clamp(0.5 + 1.3 * noise((x + o.X * 0.6) / 16 + 3.1, (z + o.Y * 0.6) / 16 + 7.7, FLD.t * 0.04), 0, 1)
	return P._lut[math.floor((0.22 + 0.5 * q) * 48 + 0.5)]
end
--- (v9) THE CRYSTALS' FIELD at world (x, y, z): one continuous domain-warped noise field, two octaves, its features drifting
--- with the wandering offset (0.8 studs/s, direction wandering) and slowly up the height axis. Dark voids (deep
--- green-teal) and bright wisps (mint .. cyan, the brightest toward pale white-green); `tip`: the thin white-hot edge
local function crystalCol(P, x, y, z, tip)
	local t, o1, o4 = FLD.t, FLD.off[1], FLD.off[4]
	local wx, wz = (x + o4.X) / 15, (z + o4.Y) / 15
	local qx = x + 5 * noise(wx, y / 15, wz + t * 0.013)                    -- (the warp: shapes stretch and fold)
	local qz = z + 5 * noise(wx + 7.3, y / 15, wz - t * 0.012)
	local ax, az = (qx + o1.X) / 8, (qz + o1.Y) / 8
	local v = noise(ax, y / 6 - t * 0.028, az) + 0.35 * noise(ax * 2.3 + 4.1, y / 2.6 + t * 0.037, az * 2.3 - 2.7)
	local L = math.clamp((v + 0.3) / 0.7, 0, 1)
	L = L * L * (3 - 2 * L)
	local q = math.clamp(0.5 + 1.2 * noise(ax * 0.6 + 3.1, y / 9 + t * 0.019, az * 0.6 + 7.7), 0, 1)
	local col = P._lut[math.floor((0.08 + 0.8 * q) * 48 + 0.5)]
	if L > 0.82 then col = col:Lerp(P.Highlight, (L - 0.82) * 2.2) end
	col = VOID:Lerp(col, 0.12 + 0.88 * L)
	if tip then col = col:Lerp(P.Highlight, 0.55) end
	return col
end
--- (v7) the cloud-and-pocket field at world (x, z): r, g, b -- the aurora ring (floor c), and the particles' and
--- lights' colours (A.Sample)
local PT = { 7, 11, 13, 17 }                                -- the pockets' time scales (s): primes, never in step
local POFF = { { 3.1, 7.7 }, { 19.4, 2.2 }, { 8.8, 23.5 }, { 31.3, 13.9 } }
local PCOL                                                  -- (from the palette: emerald, aqua, cyan, mint)
local function fieldReady(P)
	if not PCOL then local st = P.Flow.Stops PCOL = { st[2], st[3], st[4], st[1] } end
end
local function fieldAt(P, x, z)
	local t, o = FLD.t, FLD.off
	local o4, o1 = o[4], o[1]
	local wx, wz = (x + o4.X) / 18, (z + o4.Y) / 18
	local qx = x + 12 * noise(wx, wz, t * 0.031)            -- (the warp: shapes stretch and fold)
	local qz = z + 12 * noise(wx + 17.3, wz - 9.1, t * 0.029)
	local cx, cz = (qx + o1.X) / 14, (qz + o1.Y) / 14
	local c = math.clamp(0.5 + 1.1 * noise(cx, cz, t * 0.023) + 0.5 * noise(cx * 2.1 + 3.7, cz * 2.1 - 1.9, t * 0.037), 0, 1)
	local px, pz = (qx + o1.X * 0.6) / 16, (qz + o1.Y * 0.6) / 16
	local e = PCOL[1]
	local r, g, b, ws = e.R * 0.15, e.G * 0.15, e.B * 0.15, 0.15
	for k = 1, 4 do
		local w = noise(px + POFF[k][1], pz + POFF[k][2], t / PT[k]) * 2 + 0.25
		if w > 0 then
			w *= w
			local col = PCOL[k]
			r, g, b, ws = r + col.R * w, g + col.G * w, b + col.B * w, ws + w
		end
	end
	local B = (0.45 + 0.4 * c) / ws
	return r * B, g * B, b * B
end
--- (the cost meter: ms a frame, per part of the work -- read by the test stage in Studio)
A._prof = {}
A._FLD = FLD
function A._acc(k, d)
	local p = A._prof[k]
	if not p then p = { n = 0, sum = 0, max = 0 } A._prof[k] = p end
	p.n += 1 p.sum += d p.max = math.max(p.max, d)
	if RunService:IsStudio() then
		local now = os.clock()
		if now > (A._pubT or 0) then
			A._pubT = now + 0.5
			workspace:SetAttribute("AuroraProf", game:GetService("HttpService"):JSONEncode({ prof = A._prof, stats = A.Stats }))
		end
	end
end

----------------------------------------------------------------------------------------------------
-- the crystal copies: the flow lives inside the crystals
----------------------------------------------------------------------------------------------------
local function lvl(h) return math.clamp(math.floor(h * LV + 0.5), 0, LV) end

--- variant v's colour at height h (0 base .. 1 tip) at clock t
local function flowCol(P, v, h, t)
	local lut = P._lut
	local u = h * 1.2 - v.Ph
	local q = math.clamp(0.5 + 1.5 * noise(u * 1.3, v.Seed, t * 0.06), 0, 1)                -- (the pocket's colour)
	local col = lut and lut[math.floor((0.06 + 0.84 * q) * 48 + 0.5)] or P.Main
	local L = (TUNE.l0 + TUNE.l1 * noise(u * 2.1 + 5.3, v.Seed + 9.1, t * 0.08)) * (0.72 + 0.28 * h)   -- (pockets of light)
	local w = 0
	if v.TwOn then                                                                          -- (a twinkle, travelling up)
		local d = (h - v.TwH) / 0.05                                                       -- (soft: a glint, not a white band)
		local k = math.exp(-d * d)
		L += 0.22 * k
		w = 0.25 * k
	end
	if h > 0.9 then w = math.max(w, (h - 0.9) * 8.5) end                                   -- (the white-hot tip: the last tenth)
	if L > 1 then w = math.max(w, math.min(0.4, (L - 1) * 1.2)) L = 1 end
	L = math.max(0.28, L)
	if w > 0 then col = col:Lerp(P.Highlight, math.min(0.9, w)) end
	return Color3.new(col.R * L, col.G * L, col.B * L)
end
--- a variant's drift: its phase moves at a speed that wanders (heights a second: mostly up, sometimes back); its
--- twinkle comes every few seconds (none when `twinkles` is off)
local function moveVariant(v, dt, now, twinkles)
	v.Ph += 0.16 * (0.45 + 1.5 * noise(FLD.t * 0.045, v.Seed, 1.7)) * dt
	if v.TwOn then
		v.TwH += dt * 0.6
		if v.TwH > 1.15 or not twinkles then v.TwOn = false v.TwNext = now + 2.5 + 5 * math.random() end
	elseif twinkles and now > v.TwNext then
		v.TwOn, v.TwH = true, -0.1
	end
end
local function paintLevels(P, v, t)
	local em, lev, lum = v.EM, v.Lev, v.Lum
	for L = 0, LV do
		local ids = lev[L]
		if ids[1] then
			local col = flowCol(P, v, L / LV, t)
			for _, id in ipairs(ids) do em:SetColor(id, col) end
			if lum then lum[L] = 0.3 * col.R + 0.59 * col.G + 0.11 * col.B end
		end
	end
end
--- a cage plate: a faint flowing inner glow, a thin bright edge
local function paintPlate(P, v, t)
	local em = v.EM
	local c = flowCol(P, v, 0.45, t)
	c = Color3.new(c.R * 0.34, c.G * 0.34, c.B * 0.34)
	for _, id in ipairs(v.In) do em:SetColor(id, c) end
	if not v.EdgeDone then
		local e = P.Highlight:Lerp(P.Main, 0.3)
		for _, id in ipairs(v.Edge) do em:SetColor(id, e) end
		v.EdgeDone = true
	end
end

--- (v9) a CELL: every crystal of one shape inside one CELL x CELL square of ground shares one FixedSize copy, its LV + 1
--- levels painted from the field at the cell's middle at the levels' real heights -- so neighbours match and the field's
--- voids and wisps slide up and down inside the crystals. Copies are capped by Graphics Quality (the EditableMesh memory
--- budget: ~600 copies on a desktop, fewer on a phone); the least recently shown cell gives its copy up first
local function paintCell(P, e, low)
	local cols, em, H, G = e.Cols, e.EM, 3, (e.G < 1e9 and e.G or 0)          -- (a fixed 3-stud span: a growing crystal does not stretch it)
	for L = 0, LV do
		if not low or L % 2 == 0 or L == LV then
			local h = e.Flip and 1 - L / LV or L / LV
			cols[L] = crystalCol(P, e.X, G + h * H, e.Z, L == LV)
		end
	end
	if low then for L = 1, LV - 1, 2 do cols[L] = cols[L - 1]:Lerp(cols[L + 1], 0.5) end end
	for L = 0, LV do local col = cols[L] for _, id in ipairs(e.Lev[L]) do em:SetColor(id, col) end end
end
local cellQ, cellBusy = {}, false
--- the cell `k` (its copy made in the background) for the crystal `p` of copy `c`; nil until it is ready
local function cellFor(p, c, k, x, z)
	local e = CELLS[k]
	if e then return e.Ready and e or nil end
	local cap = FLD.detail >= 2 and 400 or (FLD.detail == 1 and 200 or 0)
	if #cellList >= cap then                                                -- (full: the stalest cell gives way)
		local now, old, oi = os.clock(), nil, nil
		for i, o in ipairs(cellList) do if now - o.Used > 5 and (not old or o.Used < old.Used) then old, oi = o, i end end
		if not old then return nil end
		for q in pairs(old.Parts) do
			if cellOf[q] == old.K then
				cellOf[q] = nil
				pcall(function() local sz = q.Size q:ApplyMesh(old.Src) q.Size = sz end)
			end
		end
		pcall(function() old.EM:Destroy() old.Holder:Destroy() end)
		CELLS[old.K] = nil
		table.remove(cellList, oi)
	end
	e = { K = k, X = x, Z = z, G = math.huge, H = 0.5, Used = os.clock(), Parts = setmetatable({}, { __mode = "k" }), Cols = {},
		Flip = c.Flip, Src = c.V[1].Holder }
	CELLS[k] = e
	cellList[#cellList + 1] = e
	cellQ[#cellQ + 1] = { E = e, C = c }
	if not cellBusy then
		cellBusy = true
		task.spawn(function()
			while cellQ[1] do
				local j = table.remove(cellQ, 1)
				local ok = pcall(function()
					local em = AssetService:CreateEditableMeshAsync(Content.fromObject(j.C.V[1].EM), { FixedSize = true })
					assert(em, "budget")
					j.E.Lev = levelsOf(em, j.C.hOf)
					j.E.Holder = AssetService:CreateMeshPartAsync(Content.fromObject(em))
					j.E.EM = em
					if A.P and A.P._lut then paintCell(A.P, j.E, false) end
					j.E.Ready = true
					A.Stats.Cells = (A.Stats.Cells or 0) + 1
				end)
				if not ok then CELLS[j.E.K] = nil table.remove(cellList, table.find(cellList, j.E) or #cellList + 1) A.Stats.CellFail = (A.Stats.CellFail or 0) + 1 end
				task.wait()
			end
			cellBusy = false
		end)
	end
	return nil
end

--- every frame while an Aurora effect is alive (A.HotUntil): the crystals (their own copies) and the plates are painted
local function step()
	local now = os.clock()
	if now > (A.HotUntil or 0) then return end
	A.Advance()
	local P = A.P
	if not (P and P._lut) then return end
	local still = hold()
	local dt, q = FLD.t - (A._stepT or FLD.t), FLD.detail                       -- (the clock's own time: frozen when held)
	A._stepT = FLD.t
	FLD.sn += 1
	local paintNow = q > 0 or FLD.sn % 2 == 0                             -- (LOW: half rate, no twinkles)
	local t = FLD.t
	-- the crystals' cells: each every `rate` frames (HIGH 2, MEDIUM 3, LOW 4 with half the samples) while a crystal in it
	-- has shown in the last half second; the field moves well under a level a step, so no step shows. Held: once, then still
	local rate = q >= 2 and 2 or (q == 1 and 3 or 4)
	for i, e in ipairs(cellList) do
		if e.Ready and now - e.Used < 0.5 and (not e.Painted or (i + FLD.sn) % rate == 0) and not (still and e.Held) then
			paintCell(P, e, q == 0)
			e.Held, e.Painted = still, true
		end
	end
	for _, c in pairs(copies) do
		if type(c) == "table" and c.Kind == "plate" then
			for _, v in ipairs(c.V) do
				if still then
					if v.TwOn then v.TwOn, v.Held = false, false end
				else
					moveVariant(v, dt, now, q > 0 and c.Kind == "crystal")
				end
				if paintNow and not (still and v.Held) then
					paintPlate(P, v, t)
				end
				v.Held = still
			end
		end
	end
	A._acc("crystals", os.clock() - now)
end
local function ensureStep()
	if not conn then conn = RunService.RenderStepped:Connect(step) end
end

-- one build at a time (the resizable EditableMesh budget is small)
local queue, working = {}, false
local function enqueue(job, front)
	if front then table.insert(queue, 1, job) else queue[#queue + 1] = job end
	if working then return end
	working = true
	task.spawn(function()
		while queue[1] do
			local j, done = table.remove(queue, 1), false
			task.spawn(function()                                              -- (a job that never returns is left behind)
				local ok, err = pcall(j)
				if not ok then A.Stats.LastError = tostring(err) end
				done = true
			end)
			local t0 = os.clock()
			while not done and os.clock() - t0 < 20 do task.wait() end
			if not done then A.Stats.TimedOut = (A.Stats.TimedOut or 0) + 1 end
			task.wait()
		end
		working = false
	end)
end
--- a resizable EditableMesh (of `content`, or empty), waiting out a full budget; nil if it never comes
local function resizable(content)
	for _ = 1, content and 4 or 30 do
		local ok, e = pcall(function()
			if content then return AssetService:CreateEditableMeshAsync(content) end
			return AssetService:CreateEditableMesh()
		end)
		if ok and e then return e end
		task.wait(1)
	end
	return nil
end
--- a convex polygon cut by the plane p[axis] == c: the part at or below, the part at or above
local function split(poly, axis, c)
	local below, above = {}, {}
	local n = #poly
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		local da, db = a[axis] - c, b[axis] - c
		if da <= 0 then below[#below + 1] = a end
		if da >= 0 then above[#above + 1] = a end
		if (da < 0 and db > 0) or (da > 0 and db < 0) then
			local m = a:Lerp(b, da / (da - db))
			below[#below + 1] = m
			above[#above + 1] = m
		end
	end
	return below, above
end
--- `src` re-cut along `axis` into LV levels (new vertices on every level plane), every vertex wearing its level's one
--- colour id: a resizable mesh and its height function, or nil
local function recut(src, axis, flip)
	local pos, lo, hi = {}, math.huge, -math.huge
	for _, v in ipairs(src:GetVertices()) do
		local p = src:GetPosition(v)
		pos[v] = p
		lo, hi = math.min(lo, p[axis]), math.max(hi, p[axis])
	end
	local span = math.max(1e-4, hi - lo)
	local function hOf(p) local h = (p[axis] - lo) / span return flip and 1 - h or h end
	local em = resizable(nil)
	if not em then return nil end
	local ok = pcall(function()
		local lev = {}
		for L = 0, LV do lev[L] = em:AddColor(Color3.new(1, 1, 1), 1) end
		local function put(poly)
			local n = #poly
			if n < 3 then return end
			local nv = (poly[2] - poly[1]):Cross(poly[n] - poly[1])
			local ids, cs = {}, {}
			for i, p in ipairs(poly) do ids[i] = em:AddVertex(p) cs[i] = lev[lvl(hOf(p))] end
			local nid = em:AddNormal(nv.Magnitude > 1e-10 and nv.Unit or Vector3.yAxis)
			for i = 2, n - 1 do
				pcall(function()
					local f = em:AddTriangle(ids[1], ids[i], ids[i + 1])
					em:SetFaceColors(f, { cs[1], cs[i], cs[i + 1] })
					em:SetFaceNormals(f, { nid, nid, nid })
				end)
			end
		end
		for _, f in ipairs(src:GetFaces()) do
			local vs = src:GetFaceVertices(f)
			local poly = { pos[vs[1]], pos[vs[2]], pos[vs[3]] }
			for L = 1, LV - 1 do                                          -- (each level plane in turn: the part below goes out)
				local below
				below, poly = split(poly, axis, lo + span * L / LV)
				put(below)
				if #poly < 3 then break end
			end
			put(poly)
		end
	end)
	if not ok then em:Destroy() return nil end
	return em, hOf
end
--- a copy's colour ids by level (read back: a copy may number them anew)
levelsOf = function(em, hOf)
	local lev, seen, n = {}, {}, 0
	for L = 0, LV do lev[L] = {} end
	for _, f in ipairs(em:GetFaces()) do
		local vs, cs = em:GetFaceVertices(f), em:GetFaceColors(f)
		for i = 1, 3 do
			local id = cs[i]
			if id and not seen[id] then
				seen[id] = true
				n += 1
				table.insert(lev[lvl(hOf(em:GetPosition(vs[i])))], id)
			end
		end
	end
	return lev, n
end

local function buildCrystal(P, key, content, opts)
	copies[key] = true
	enqueue(function()
		local src, em
		local ok = pcall(function()
			A.Stats.Stage = "crystal src " .. key
			src = resizable(content)
			assert(src, "no mesh")
			A.Stats.Stage = "crystal recut " .. key
			local hOf
			em, hOf = recut(src, opts.Axis or "Y", opts.Flip)
			src:Destroy() src = nil
			assert(em, "recut")
			local c = { Kind = "crystal", V = {} }
			A.Stats.Stage = "crystal variants " .. key
			for k = 1, opts.K or KX do
				local fixed = AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
				if not fixed then break end
				local lev, n = levelsOf(fixed, hOf)
				local ok2, holder = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end)
				if not (ok2 and holder) then fixed:Destroy() break end
				c.V[k] = { EM = fixed, Holder = holder, Lev = lev, Seed = math.random() * 200, Ph = math.random() * 3,
					TwNext = os.clock() + math.random() * 5 }
				A.Stats.Verts += #fixed:GetVertices()
				A.Stats.Ids += n
			end
			em:Destroy() em = nil
			assert(c.V[1], "no variant")
			c.hOf, c.Flip = hOf, opts.Flip
			for _, v in ipairs(c.V) do
				for L = 0, LV do
					local g = L == LV and 1 or 0.4 + 0.6 * L / LV
					for _, id in ipairs(v.Lev[L]) do v.EM:SetColor(id, Color3.new(g, g, g)) end
				end
			end
			copies[key] = c
			A.Stats.Copies += #c.V
			pending[P] = true
		end)
		if not ok then
			if src then src:Destroy() end
			if em then em:Destroy() end
			copies[key] = false
			A.Stats.Failed += 1
		end
	end, true)
end
local function buildSlab(P, key, content)
	copies[key] = true
	task.spawn(function()                                                     -- (FixedSize only: no queue)
		local ok = pcall(function()
			A.Stats.Stage = "slab " .. key
			local em = AssetService:CreateEditableMeshAsync(content, { FixedSize = true })
			assert(em, "no mesh")
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, v in ipairs(em:GetVertices()) do local p = em:GetPosition(v) lo, hi = lo:Min(p), hi:Max(p) end
			local s = hi - lo
			local thin = (s.X <= s.Y and s.X <= s.Z) and "X" or (s.Y <= s.Z and "Y" or "Z")   -- (the slab's thickness)
			local cap, side = {}, {}
			pcall(function()                                                      -- (a FixedSize mesh may refuse new colours: plain then)
				for _, f in ipairs(em:GetFaces()) do
					local vs, cs = em:GetFaceVertices(f), em:GetFaceColors(f)
					if #cs == 0 then
						cs = {}
						for i = 1, 3 do cs[i] = em:AddColor(Color3.new(1, 1, 1), 1) end
						em:SetFaceColors(f, cs)
					end
					local p0, p1, p2 = em:GetPosition(vs[1]), em:GetPosition(vs[2]), em:GetPosition(vs[3])
					local n = (p1 - p0):Cross(p2 - p0)
					local isCap = n.Magnitude < 1e-10 or math.abs(n.Unit[thin]) > 0.6
					for i = 1, 3 do if isCap then cap[cs[i]] = true else side[cs[i]] = true end end
				end
				for id in pairs(cap) do em:SetColor(id, SLAB_IN) end                    -- (the top: a soft pale)
				for id in pairs(side) do if not cap[id] then em:SetColor(id, SLAB_EDGE) end end   -- (the thin sides: lit)
			end)
			local holder = AssetService:CreateMeshPartAsync(Content.fromObject(em))
			copies[key] = { Kind = "slab", V = { { EM = em, Holder = holder } } }
			A.Stats.Copies += 1
			pending[P] = true
		end)
		if not ok then copies[key] = false A.Stats.Failed += 1 end
	end)
end

--- `p` holds `mat` and `col` (an effect re-dressing its pieces is overruled)
local function lockColour(p, mat, col, also)
	p.Material = mat
	p.Color = col
	desired[p] = p.Color                                                     -- (as stored: 8 bits a channel)
	p:GetPropertyChangedSignal("Color"):Connect(function()
		local d = desired[p]
		if d and p.Color ~= d then
			p.Color = d
			desired[p] = p.Color
		end
	end)
	p:GetPropertyChangedSignal("Material"):Connect(function()
		if p.Material ~= mat and p.Material ~= also then p.Material = mat end
	end)
end
--- the Color a crystal or plate is held to (the wave, every other frame)
function A.SetTint(p, c)
	desired[p] = nil
	p.Color = c
	desired[p] = p.Color
end

local CRYSTAL = { "Crystal", "IS_Cluster", "Spike", "FF_Slab_" }
local function isCrystal(name)
	if string.find(name, "Crack", 1, true) or string.find(name, "Chunk", 1, true) then return false end
	for _, k in ipairs(CRYSTAL) do if string.find(name, k, 1, true) then return true end end
	return false
end
local function buildFor(P, template)
	local key, content = template.MeshId, Content.fromUri(template.MeshId)
	if string.find(template.Name, "FF_Slab_", 1, true) then buildSlab(P, key, content)
	else buildCrystal(P, key, content, { Flip = template.Name == "IS_Cluster" }) end
end

--- a kit piece for `template` as a copy (Aurora only), or nil (not a crystal, still building, or failed: the caller
--- draws its own SpecialMesh piece, which the flow colours piece by piece)
function A.KitCopy(P, template)
	if not (P and P.Grad and typeof(template) == "Instance" and template:IsA("MeshPart") and isCrystal(template.Name)) then return nil end
	A.P, lastUse = P, os.clock()
	ensureStep()
	local key = template.MeshId
	local c = copies[key]
	if c == nil then buildFor(P, template) return nil end
	if type(c) ~= "table" then return nil end
	c.Live = os.clock()
	local p = c.V[1].Holder:Clone()
	p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = template.Name, true, false, false, false, false, true
	p.Size, p.Transparency, p.Reflectance = template.Size, 1, 0
	if c.Kind == "slab" then
		p:SetAttribute("AuroraSlab", true)
		lockColour(p, Enum.Material.Ice, SLAB_COL)
	else
		p:SetAttribute("AuroraGrad", true)
		p:SetAttribute("AuroraKey", key)
		p:SetAttribute("AuroraVar", 1)
		lockColour(p, Enum.Material.Neon, HOLD, Enum.Material.Snow)          -- (a collar the kit cools to snow stays snow)
	end
	return p
end

--- CryoFX's take(): a copy for a crystal of the Mirror Cage (never pooled there: no CryoKit, give() drops it)
function A.KitTake(P, name, style, dress, template)
	if not (P and P.Grad and type(name) == "string" and isCrystal(name) and template) then return nil end
	local t = template(name)
	local p = t and A.KitCopy(P, t)
	if not p then return nil end
	p.LocalTransparencyModifier = 0
	pcall(dress, p, style or "Body")
	return p
end

--- `p` (a crystal copy) wears a variant picked by its place (neighbours differ; `frac` is not used since v8)
function A.Assign(p, frac)
	local key = p:GetAttribute("AuroraKey")
	local c = key and copies[key]
	if type(c) ~= "table" or not c.V or #c.V < 2 then return end
	local q = p.Position
	local k = math.floor(q.X * 1.37 + q.Z * 2.91) % #c.V + 1
	if p:GetAttribute("AuroraVar") == k then return end
	local sz = p.Size
	if pcall(p.ApplyMesh, p, c.V[k].Holder) then p:SetAttribute("AuroraVar", k) end
	if p.Size ~= sz then p.Size = sz end
end

--- a cage plate (CryoWrap's plates[var]: its second, paintable copy G / GMesh, its inner part grey) as a copy, or nil
function A.PlateCopy(P, var, t)
	if not (P and P.Grad and type(t) == "table" and t.G and t.GMesh) then return nil end
	local key = "plate:" .. tostring(var)
	local c = copies[key]
	if c == nil then
		local em, inn, edge, seen = t.GMesh, t._auIn or {}, t._auEdge or {}, {}
		local ok = t._auIn ~= nil or pcall(function()
			for _, f in ipairs(em:GetFaces()) do
				for _, id in ipairs(em:GetFaceColors(f)) do
					if not seen[id] then
						seen[id] = true
						local col = em:GetColor(id)
						if col and col.R < 0.9 then inn[#inn + 1] = id else edge[#edge + 1] = id end
					end
				end
			end
		end)
		if not ok then copies[key] = false return nil end
		t._auIn, t._auEdge = inn, edge
		c = { Kind = "plate", Owned = true, V = { { EM = em, Holder = t.G, In = inn, Edge = edge, Seed = math.random() * 200,
			Ph = math.random() * 3, TwNext = math.huge } } }
		copies[key] = c
		ensureStep()
	end
	if type(c) ~= "table" then return nil end
	local T = t.T
	local p = c.V[1].Holder:Clone()
	p.Size, p.CFrame = T.Size, T.CFrame
	p.Name = T.Name
	p:SetAttribute("AuroraGrad", true)
	lockColour(p, Enum.Material.Neon, GREY)
	return p
end

--- warm every copy up before the first cast needs it (the wrap's first palette lookup)
function A.Prepare(P)
	if not (P and P.Grad) or A.Prepared == P then return end
	A.Prepared, A.P, lastUse = P, P, os.clock()
	ensureStep()
	local root = ReplicatedStorage:FindFirstChild("IceMagicMeshes")
	if not root then return end
	buildField()
	local FAM = { FlashFreeze = true, IcicleShard = true, CryoKit = true }
	for _, m in ipairs(root:GetDescendants()) do
		if m:IsA("MeshPart") and m.Parent and FAM[m.Parent.Name] and isCrystal(m.Name) and copies[m.MeshId] == nil
			and not string.find(m.Name, "FF_Slab_", 1, true) then buildFor(P, m) end
	end
	for _, m in ipairs(root:GetDescendants()) do                                -- (then the slabs)
		if m:IsA("MeshPart") and m.Parent and FAM[m.Parent.Name] and copies[m.MeshId] == nil and string.find(m.Name, "FF_Slab_", 1, true) then
			buildFor(P, m)
		end
	end
end

--- copies became ready since the last look: the wrap drops its pooled looks so the next cast takes them
function A.TakePending(P)
	if pending[P] then pending[P] = nil return true end
	return false
end

--- every copy goes (no Aurora caster for a while); the wrap drops its pools
local function release()
	for k, c in pairs(copies) do
		if type(c) == "table" and not c.Owned then                                -- (plates: CryoWrap's)
			pcall(function() for _, v in ipairs(c.V) do v.Holder:Destroy() v.EM:Destroy() end end)
		end
		copies[k] = nil
	end
	for _, e in ipairs(cellList) do pcall(function() e.EM:Destroy() e.Holder:Destroy() end) end
	table.clear(cellList) table.clear(CELLS)
	A.Prepared = nil
	A.Stats.Released += 1
	if conn then conn:Disconnect() conn = nil end
	if W and A.P and W._dropPools then W._dropPools(A.P) end
end
--- anyone (a player, or a Studio stand-in) still wearing the wrap the copies are for: they stay
local function wearing()
	local id = A.P and A.P.Id
	if not id then return false end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("ElementWrap_Cryo") == id then return true end
	end
	local st = RunService:IsStudio() and workspace:FindFirstChild("WrapStage")
	if st then for _, m in ipairs(st:GetChildren()) do if m:GetAttribute("WrapStudio") == id then return true end end end
	return false
end
task.spawn(function()
	while true do
		task.wait(15)
		if next(copies) and os.clock() - lastUse > 60 and not wearing() then release() end   -- (only once nobody wears it)
	end
end)
--- an Aurora effect is alive: the copies move for the next while
function A.Touch()
	lastUse = os.clock()
	A.HotUntil = lastUse + 12
	ensureStep()
end

----------------------------------------------------------------------------------------------------
-- the sky light: haze, curtains, halos, glints, sparkles (faint: the crystals are the brightest thing)
----------------------------------------------------------------------------------------------------
local function host(name, cf, size)
	local h = Instance.new("Part")
	h.Name, h.Anchored, h.CanCollide, h.CanQuery, h.CanTouch, h.Transparency = name, true, false, false, false, 1
	h.Size, h.CFrame = size, cf
	h.Parent = (W.FXName and workspace:FindFirstChild(W.FXName)) or workspace
	return h
end

--- the low haze: a very faint glow 1-2 studs over the floor, drifting slowly (over a disc of radius R at g, `life` s)
function A.Patches(P, g, R, n, life)
	local V = W._VFX
	if not (V and V.Emitter and n and n > 0) then return end
	local st = P.Flow.Stops
	local h = host("AuroraHaze_" .. P.Id, CFrame.new(g + Vector3.new(0, 0.8, 0)), Vector3.new(1.5 * R, 1, 1.5 * R))
	local e = V.Emitter(h, {
		Texture = SMOKE, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, st[2]), ColorSequenceKeypoint.new(0.5, st[3]),
			ColorSequenceKeypoint.new(1, st[4]) }), LightEmission = 1, LightInfluence = 0,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, R * 0.3), NumberSequenceKeypoint.new(1, R * 0.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.95),
			NumberSequenceKeypoint.new(0.7, 0.955), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2.5, 3.5), Speed = NumberRange.new(0.1, 0.4), SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-10, 10), Rate = n, LockedToPart = false,
	})
	task.delay(life * 0.75, function() if e then e.Rate = 0 end end)
	task.delay(life + 4, function() h:Destroy() end)
end

--- the curtains: slim, faint ribbons round radius R at g for `life` s (a soft veil, a body and two thin rays each), a
--- defined base fading to a clear top, coloured from the field at their foot, folding and swaying with noise (neighbours
--- apart). Beams are not particles: gated here like emitter() (density, Reduce Enemy VFX); still under Reduce Flashing.
function A.Curtains(P, g, R, life, caster)
	local C = P.Curtains
	local s = settingsMod()
	local mine = Players.LocalPlayer and caster == Players.LocalPlayer.Character
	local n = C.Ribbons or 6
	if s and (s.EffectDensity or 1) < 0.6 then n = math.ceil(n / 2) end
	if s and s.ThinEnemyVFX and not mine then n = math.ceil(n / 2) end
	local h = host("AuroraCurtains_" .. P.Id, CFrame.new(g), Vector3.new(0.2, 0.2, 0.2))
	local items = {}
	local a0 = math.random() * math.pi * 2
	local function kpT(t)
		-- (clear below ~5 studs: nothing round the rim hides a player more than Default)
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.36, t),
			NumberSequenceKeypoint.new(0.6, t + (1 - t) * 0.4), NumberSequenceKeypoint.new(1, 1) })
	end
	for i = 1, n do
		local ang = a0 + (i - 1) * (2 * math.pi / n) + (math.random() - 0.5) * 0.4
		local tang = Vector3.new(-math.sin(ang), 0, math.cos(ang))
		local base = Vector3.new(math.cos(ang) * R, 0, math.sin(ang) * R)
		local pairs_ = {}
		local function pair(off)
			local b0, b1 = Instance.new("Attachment"), Instance.new("Attachment")
			b0.Position, b1.Position = base + tang * off, base + tang * off + Vector3.new(0, C.Height, 0)
			b0.Axis, b1.Axis = tang, tang
			b0.Parent, b1.Parent = h, h
			pairs_[#pairs_ + 1] = { B0 = b0, B1 = b1, Off = off }
			return b0, b1
		end
		local function ribbon(b0, b1, width, t, tex, bright)
			local bm = Instance.new("Beam")
			bm.Attachment0, bm.Attachment1, bm.FaceCamera, bm.Segments = b0, b1, true, 16
			bm.Texture, bm.TextureMode, bm.TextureLength, bm.TextureSpeed = tex, Enum.TextureMode.Stretch, 1, 0.15
			bm.Width0, bm.Width1, bm.LightEmission, bm.LightInfluence, bm.Brightness = width, width * 1.3, 1, 0, bright
			bm.Transparency = kpT(t)
			bm.Color = P._flowCS
			bm.Parent = h
			return bm
		end
		local c0, c1 = pair(0)
		local r0, r1 = pair(C.Width * 0.28)
		local q0, q1 = pair(-C.Width * 0.22)
		local beams = {
			ribbon(c0, c1, C.Width, math.min(1, C.T + 0.3), SMOKE, 0.9),              -- the soft veil
			ribbon(c0, c1, C.Width * 0.4, C.T, GLOW, 1.2),                           -- the body
			ribbon(r0, r1, C.Width * 0.1, C.T + 0.1, GLOW, 0.8),                      -- thin vertical rays
			ribbon(q0, q1, C.Width * 0.08, C.T + 0.16, GLOW, 0.7),
		}
		items[#items + 1] = { Base = base, Pairs = pairs_, Ph = i * 0.9 + math.random() * 0.3, Beams = beams }
	end
	A.Touch()
	local t0 = os.clock()
	local c
	c = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local age = now - t0
		if age > life or not h.Parent then c:Disconnect() if h.Parent then h:Destroy() end return end
		A.Advance()
		local still = hold()
		local up = math.min(1, age / 0.6) * (age > life - 1 and (life - age) or 1)          -- (rise in, sink out)
		local nt = FLD.t
		for _, it in ipairs(items) do
			local sway = still and 0 or noise(nt * 0.13, it.Ph, 0.5) * 2.8
			local fold0 = still and 0 or 5 * noise(nt * 0.17, it.Ph, 2.5)              -- (the folds: neighbours apart)
			local fold1 = still and 0 or -4 * noise(nt * 0.15, it.Ph, 4.5)
			for _, pr in ipairs(it.Pairs) do
				pr.B1.Position = pr.B0.Position + Vector3.new(sway, C.Height * math.max(0.05, up), sway * 0.6)
			end
			for _, bm in ipairs(it.Beams) do bm.CurveSize0, bm.CurveSize1, bm.TextureSpeed = fold0, fold1, still and 0 or 0.15 end
			local kps = {}
			local wb = g + it.Base
			for k = 0, 4 do
				local col = A.Sample(wb.X + k * 2.5, wb.Z - k * 1.5, 0)
				if k == 0 then col = col:Lerp(P.Highlight, 0.3) end                      -- (the lit lower edge)
				kps[k + 1] = ColorSequenceKeypoint.new(k / 4, col)
			end
			local cs = ColorSequence.new(kps)
			for _, bm in ipairs(it.Beams) do bm.Color = cs end
		end
		A._acc("curtains", os.clock() - now)
	end)
	-- starlight on the curtains (none under Reduce Flashing)
	local V = W._VFX
	if V and V.Emitter and not hold() then
		local th = host("AuroraStars_" .. P.Id, CFrame.new(g + Vector3.new(0, C.Height * 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(C.Height * 0.8, 2 * R, 2 * R))
		local e = V.Emitter(th, {
			Texture = SPARKLE, Color = P._twinkleCS, LightEmission = 1, LightInfluence = 0,
			Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.1), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0, 0.2),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60), Rate = C.Stars, LockedToPart = false,
		})
		task.delay(life * 0.8, function() if e then e.Rate = 0 end end)
		task.delay(life + 1, function() th:Destroy() end)
	end
	return n
end

--- soft halo glows along a zone's crystal ring (radius R at g): faint, behind the crystals
function A.Halos(P, g, R, life)
	local V = W._VFX
	if not (V and V.Emitter) then return end
	local st = P.Flow.Stops
	local h = host("AuroraHalos_" .. P.Id, CFrame.new(g + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.4, 2 * R, 2 * R))
	local e = V.Emitter(h, {
		Texture = GLOW, Color = ColorSequence.new(st[2], st[4]), LightEmission = 1, LightInfluence = 0,
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(0.4, 2.6), NumberSequenceKeypoint.new(1, 3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.8),
			NumberSequenceKeypoint.new(0.7, 0.86), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(0, 0.2), Rate = 6, LockedToPart = false, ZOffset = 0.3,
	})
	task.delay(life * 0.8, function() if e then e.Rate = 0 end end)
	task.delay(life + 2, function() h:Destroy() end)
end

--- the shatter: each slab, as it appears, throws a small white-green glint (none under Reduce Flashing)
function A.WatchShards(P, ctx, life)
	local fx = W.FXName and workspace:FindFirstChild(W.FXName)
	local V = W._VFX
	if not (fx and ctx and V and V.Emitter) then return end
	local gh = host("AuroraGlints_" .. P.Id, CFrame.new(ctx.O), Vector3.new(0.3, 0.3, 0.3))
	local e = V.Emitter(gh, {
		Texture = SPARKLE, Color = ColorSequence.new(P.Highlight, P.Flow.Stops[4]), LightEmission = 1, LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.1), Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(0, 0.4),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), Rate = 0, LockedToPart = false,
	})
	task.spawn(function()
		task.wait(0.2)
		local slabs = {}
		for _, d in ipairs(fx:GetDescendants()) do
			if d:IsA("BasePart") and string.find(d.Name, "FF_Slab_", 1, true) then slabs[#slabs + 1] = d end
		end
		local seen, t0 = {}, os.clock()
		while os.clock() - t0 < life and gh.Parent do
			local quiet = hold()
			for _, d in ipairs(slabs) do
				if not seen[d] and d.Parent and d.Transparency < 1 then
					local v = d.Position - ctx.O
					if Vector3.new(v.X, 0, v.Z).Magnitude < ctx.R * 1.4 then
						seen[d] = true
						if e and not quiet then gh.Position = d.Position e:Emit(1) end
					end
				end
			end
			task.wait(0.05)
		end
		task.wait(1)
		gh:Destroy()
	end)
end

--- a few tiny sparkles over a floor, twinkling in place (none under Reduce Flashing)
function A.Stars(P, g, R, life)
	if hold() then return end
	local V = W._VFX
	if not (V and V.Emitter) then return end
	local k = NumberSequenceKeypoint.new
	local h = host("AuroraFloorStars_" .. P.Id, CFrame.new(g + Vector3.new(0, 1.5, 0)), Vector3.new(2.3 * R, 2.8, 2.3 * R))
	local e = V.Emitter(h, {
		Texture = SPARKLE, Color = ColorSequence.new(P.Highlight, P.Flow.Stops[5]), LightEmission = 1, LightInfluence = 0,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = NumberSequence.new({ k(0, 0), k(0.15, 0.18), k(0.3, 0.05), k(0.5, 0.22), k(0.7, 0.04), k(0.85, 0.16), k(1, 0) }),
		Transparency = NumberSequence.new(0.1), Lifetime = NumberRange.new(1.6, 3.2), Speed = NumberRange.new(0.05, 0.2),
		SpreadAngle = Vector2.new(180, 180), Drag = 0.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
		Rate = math.clamp(R * 0.18, 2, 5), LockedToPart = false, ZOffset = 0.4,
	})
	task.delay(life * 0.85, function() if e then e.Rate = 0 end end)
	task.delay(life + 4, function() h:Destroy() end)
end

----------------------------------------------------------------------------------------------------
-- the FLOOR: a calm base laid over the zone's own disc (FF_Sheet / CryoDisc) -- two flat polar meshes (the core disc
-- and its rim ring), a colour per vertex, shared by every zone, following the disc's size and life. Lit materials (no
-- glow); the colour only the crystals' light bleeding in near the rim (with the wave of light) and faint slow veils.
----------------------------------------------------------------------------------------------------
A.FLOORS = {
	a = { Name = "Clear frosted ice", Mat = Enum.Material.Ice, CoreT = 0.42, RimT = 0.42, Base = Color3.fromRGB(172, 214, 194),
		Veil = 0.16, Bleed = 0.32, BleedK = 1, Disc = Color3.fromRGB(214, 240, 230) },
	b = { Name = "Dark glass", Mat = Enum.Material.Glass, CoreT = 0.22, RimT = 0.22, Base = Color3.fromRGB(10, 76, 46),
		Veil = 0.1, Bleed = 0.55, BleedK = 0.75, Dark = true, Disc = Color3.fromRGB(16, 88, 56) },
	c = { Name = "Open floor, aurora ring", Mat = Enum.Material.Ice, CoreT = 0.62, RimT = 0.3, Base = Color3.fromRGB(200, 238, 214),
		Veil = 0.06, Bleed = 0.12, BleedK = 1, Ring = true, RingMat = Enum.Material.Neon, RingK = 0.62, Disc = Color3.fromRGB(214, 240, 230) },
}
local function floorOpt(P)
	local k = RunService:IsStudio() and workspace:GetAttribute("AuroraFloor")
	return A.FLOORS[k] or A.FLOORS[P and P.Floor or "a"] or A.FLOORS.a
end
--- the colour the zone's own disc art wears under the floor (CryoWrap's flow: the disc decals)
function A.DiscColour(P) return floorOpt(P).Disc end

local field = nil                       -- { Core = { EM, Holder, Pts }, Rim = { ... } } | false
local FK = 0.84                         -- the floor's share of the disc's square
buildField = function()
	if field ~= nil then return end
	field = false
	task.spawn(function()
		local function make(lo, hi)
			local em = resizable(nil)
			if not em then return nil end
			local RINGS, SEG = (hi - lo) > 0.2 and 12 or 4, 72                      -- (rings: a smooth round edge, no stair)
			local ok = pcall(function()
				local col, uvs = {}, {}
				local up = em:AddNormal(Vector3.yAxis)
				local function cid(x) local id = col[x] if not id then id = em:AddColor(Color3.new(1, 1, 1), 1) col[x] = id end return id end
				local function uid(x)
					local id = uvs[x]
					if not id then local p = em:GetPosition(x) id = em:AddUV(Vector2.new(p.X * 6, p.Z * 6)) uvs[x] = id end   -- (the material's grain)
					return id
				end
				local function tri(x, y, z)                                       -- (both windings: drawn from either side)
					for _, o in ipairs({ { x, y, z }, { x, z, y } }) do
						local f = em:AddTriangle(o[1], o[2], o[3])
						em:SetFaceColors(f, { cid(o[1]), cid(o[2]), cid(o[3]) })
						em:SetFaceNormals(f, { up, up, up })
						pcall(em.SetFaceUVs, em, f, { uid(o[1]), uid(o[2]), uid(o[3]) })
					end
				end
				local ring = {}
				for r = 0, RINGS do
					ring[r] = {}
					local rr = lo + (hi - lo) * r / RINGS
					for i = 0, SEG - 1 do
						local th = 2 * math.pi * i / SEG
						ring[r][i] = (rr > 0 or i == 0) and em:AddVertex(Vector3.new(math.cos(th) * rr, 0, math.sin(th) * rr)) or ring[r][0]
					end
				end
				for r = 0, RINGS - 1 do
					for i = 0, SEG - 1 do
						local j = (i + 1) % SEG
						if lo + (hi - lo) * r / RINGS > 0 then tri(ring[r][i], ring[r][j], ring[r + 1][j]) end
						tri(ring[r][i], ring[r + 1][j], ring[r + 1][i])
					end
				end
				-- (a vertex at the corners of the square keeps the part's size the disc's, whichever ring this is)
				for _, cn in ipairs({ Vector3.new(-0.5, 0.01, -0.5), Vector3.new(0.5, 0.01, 0.5) }) do    -- (two specks, painted clear)
					local d = Vector3.new(cn.X > 0 and -0.002 or 0.002, 0, 0)
					local e1, e2, e3 = em:AddVertex(cn), em:AddVertex(cn + d), em:AddVertex(cn + Vector3.new(0, 0, d.X))
					for _, o in ipairs({ { e1, e2, e3 }, { e1, e3, e2 } }) do
						local f = em:AddTriangle(o[1], o[2], o[3])
						em:SetFaceColors(f, { cid(o[1]), cid(o[2]), cid(o[3]) })
					end
				end
			end)
			if not ok then em:Destroy() return nil end
			local fixed = AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
			em:Destroy()
			if not fixed then return nil end
			local pts, seen = {}, {}
			for _, f in ipairs(fixed:GetFaces()) do
				local vs, cs = fixed:GetFaceVertices(f), fixed:GetFaceColors(f)
				for i = 1, 3 do
					local id = cs[i]
					if id and not seen[id] then
						seen[id] = true
						local p = fixed:GetPosition(vs[i])
						pts[#pts + 1] = { id, p.X, p.Z, p.Y > 0.005, 2 * math.sqrt(p.X * p.X + p.Z * p.Z) }   -- (r: 1 at the edge)
					end
				end
			end
			local ok2, holder = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end)
			if not (ok2 and holder) then fixed:Destroy() return nil end
			return { EM = fixed, Holder = holder, Pts = pts }
		end
		local core = make(0, 0.4)
		local rim = core and make(0.4, 0.5)
		if not (core and rim) then return end
		field = { Core = core, Rim = rim }
		A.Stats.FieldVerts = #core.Pts + #rim.Pts
	end)
end

--- the floor's colour at world (wx, wz), r (0 centre .. 1 edge) of the look `opt`
local function floorCol(P, opt, wx, wz, r, ring)
	if ring and opt.Ring then                                                  -- (c: the ring carries the slow colour)
		local fr, fg, fb = fieldAt(P, wx, wz)
		local k = opt.RingK
		return Color3.new(fr * k, fg * k, fb * k)
	end
	local base = opt.Base
	local c = base
	if opt.Veil > 0 then                                                       -- (faint slow veils under the surface)
		local o = FLD.off[4]
		local veil = noise((wx + o.X) / 11, (wz + o.Y) / 11, FLD.t * 0.03)
		local hue = hueAt(P, wx * 0.7, wz * 0.7)
		if opt.Dark then hue = hue:Lerp(base, 0.55) end
		c = c:Lerp(hue, math.clamp(opt.Veil * (0.5 + veil * 1.6), 0, opt.Veil))
	end
	local e = math.clamp((r - 0.55) / 0.43, 0, 1)                             -- (near the rim: the crystals' light)
	if e > 0 then
		e = e * e * (3 - 2 * e) * opt.Bleed * (0.35 + 0.65 * waveAt(wx, wz))
		local h = hueAt(P, wx, wz)
		local k = opt.BleedK
		c = c:Lerp(Color3.new(h.R * k, h.G * k, h.B * k), e)
	end
	return c
end
local function paintFloor(P, m, opt, cx, cz, sx, sz, ring, part, parts)
	local em = m.EM
	for i, q in ipairs(m.Pts) do
		if i % parts == part then
			if q[4] then em:SetColor(q[1], BLACK)
			else em:SetColor(q[1], floorCol(P, opt, cx + q[2] * sx, cz + q[3] * sz, q[5], ring)) end
		end
	end
end

local fields, taken, fieldConn = {}, setmetatable({}, { __mode = "k" }), nil
local function fieldStep()
	local now, any, P, last = os.clock(), false, A.P, nil
	for rec, f in pairs(fields) do
		local sh, face = f.Sheet, f.Face
		local on = face.Parent and face.Transparency < 0.99
		if not (sh.Parent and sh:IsDescendantOf(workspace) and face.Parent) or (now - f.T0 > 1.5 and not on) or now - f.T0 > f.Life then
			rec.Core:Destroy() rec.Rim:Destroy()
			fields[rec], taken[sh] = nil, nil
		else
			any = true
			local cf = CFrame.new(sh.Position + Vector3.new(0, 0.035, 0))
			local size = Vector3.new(math.max(0.1, sh.Size.X * FK), 0.05, math.max(0.1, sh.Size.Z * FK))
			local o = f.Opt
			f.Full = math.min(f.Full or 1, face.Transparency)
			local k = on and math.clamp((1 - face.Transparency) / math.max(0.01, 1 - f.Full), 0, 1) or 0
			rec.Core.CFrame, rec.Core.Size, rec.Core.Transparency = cf, size, 1 - (1 - o.CoreT) * k
			rec.Rim.CFrame, rec.Rim.Size, rec.Rim.Transparency = cf, size, 1 - (1 - o.RimT) * k
			if not last or f.T0 > last.T0 then last = { T0 = f.T0, C = cf.Position, S = size, Opt = o } end
		end
	end
	if any and field and P and P._lut and last then
		A.Advance()
		fieldReady(P)
		local still = hold()
		if not (still and field.Held == last.Opt) then
			-- (slow by nature: each vertex every other frame, LOW every fourth; held: once)
			local parts = still and 1 or (FLD.detail == 0 and 4 or 2)
			FLD.fn += 1
			local part = still and 0 or FLD.fn % parts
			paintFloor(P, field.Core, last.Opt, last.C.X, last.C.Z, last.S.X, last.S.Z, false, part, parts)
			paintFloor(P, field.Rim, last.Opt, last.C.X, last.C.Z, last.S.X, last.S.Z, true, part, parts)
		end
		field.Held = still and last.Opt or nil
	end
	A._acc("floor", os.clock() - now)
	if not any and fieldConn then fieldConn:Disconnect() fieldConn = nil end
end

--- lay the floor over the zone disc near ctx (found within 3 s of the cast, its face showing), for at most `life` s
function A.Field(P, ctx, life)
	if not (field and ctx) then return end
	local fx = W.FXName and workspace:FindFirstChild(W.FXName)
	if not fx then return end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 3 do
			local best, bd
			for _, d in ipairs(fx:GetDescendants()) do
				if d:IsA("Decal") and d.Name == "Face" then
					local sh = d.Parent
					if sh and sh:IsA("BasePart") and (sh.Name == "FF_Sheet" or sh.Name == "CryoDisc") and not taken[sh] and d.Transparency < 0.99 then
						local v = sh.Position - ctx.O
						local dist = Vector3.new(v.X, 0, v.Z).Magnitude
						if dist < math.max(4, ctx.R * 0.5) and (not bd or dist < bd) then best, bd = d, dist end
					end
				end
			end
			if best then
				local sh = best.Parent
				local o = floorOpt(P)
				local rec = {}
				for _, k in ipairs({ "Core", "Rim" }) do
					local part = field[k].Holder:Clone()
					part.Name = "AuroraField" .. k .. "_" .. P.Id
					part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow, part.Massless = true, false, false, false, false, true
					part.Material = (k == "Rim" and o.RingMat) or o.Mat
					part.Color, part.Reflectance, part.Transparency = Color3.new(1, 1, 1), 0, 1
					part.Parent = fx
					rec[k] = part
				end
				fields[rec] = { Sheet = sh, Face = best, T0 = os.clock(), Life = life or 12, Opt = o }
				taken[sh] = rec
				A.Touch()
				if not fieldConn then fieldConn = RunService.RenderStepped:Connect(fieldStep) end
				return
			end
			task.wait(0.1)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- samples for CryoWrap's flow loop
----------------------------------------------------------------------------------------------------
--- the field's colour at a world point (particles, trails, beams, lights, the storm's swirl layers)
function A.Sample(x, z, y)
	A.Advance()
	local P = A.P
	if not P then return Color3.new(1, 1, 1) end
	fieldReady(P)
	local r, g, b = fieldAt(P, x + 0.3 * (y or 0), z - 0.2 * (y or 0))
	return Color3.new(r, g, b)
end
--- a crystal or cage plate (CryoWrap's flow, every other frame): its brightness on the wave of light where it stands
--- (the hue flows inside it, in its mesh); the shatter slabs keep their frosted look
local keyOf, cellKeyOf = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
function A.FieldTint(p)
	local key = keyOf[p]
	if key == nil then key = p:GetAttribute("AuroraKey") or false keyOf[p] = key end
	local lc = key and copies[key]
	if type(lc) == "table" then lc.Live = os.clock() end
	A.Advance()
	local want = FLD.mask and BLACK or HOLD                                   -- (Studio: the test stage's crystal mask)
	local c = type(lc) == "table" and lc.Kind == "crystal" and lc.hOf and lc or nil
	local q = p.Position
	if c and A.P and A.P._lut then
		local cx, cz = math.floor(q.X / CELL), math.floor(q.Z / CELL)
		local ck = cellKeyOf[p]                                                  -- (its key, made once per cell it stands in)
		if not (ck and ck[1] == cx and ck[2] == cz) then ck = { cx, cz, key .. "|" .. cx .. "|" .. cz } cellKeyOf[p] = ck end
		local k = ck[3]
		local e = cellFor(p, c, k, (cx + 0.5) * CELL, (cz + 0.5) * CELL)
		if e then
			if os.clock() - e.Used > 0.25 then paintCell(A.P, e, false) end      -- (back in use: fresh before it shows)
			e.Used = os.clock()
			e.Parts[p] = true
			e.G = math.min(e.G, q.Y - p.Size.Y / 2)
			e.H = math.max(e.H, p.Size.Y)
			if cellOf[p] ~= k then                                                -- (into its cell: the copy already wears the field)
				cellOf[p] = k
				pcall(function() local sz = p.Size p:ApplyMesh(e.Holder) p.Size = sz end)
			end
		elseif cellOf[p] then
			local o = CELLS[cellOf[p]]
			if o then o.Used = os.clock() end
		end
		if not (FLD.mask or cellOf[p]) then want = crystalCol(A.P, q.X, q.Y, q.Z, false) end   -- (no cell yet: the field at its middle)
	end
	if desired[p] ~= want then A.SetTint(p, want) end
end

----------------------------------------------------------------------------------------------------
-- Studio only: the test stage's probe -- the crystal flow's own autocorrelation (30 s, every variant level painted) and
-- the wave of light's angular velocity round a ring (AuroraProbeFlow = Vector3(x, radius, z) -> AuroraProbeFlowOut)
----------------------------------------------------------------------------------------------------
if RunService:IsStudio() then
	workspace:GetAttributeChangedSignal("AuroraProbeFlow"):Connect(function()
		local c = workspace:GetAttribute("AuroraProbeFlow")
		if typeof(c) ~= "Vector3" or not A.P then return end
		task.spawn(function()
			local vs = {}
			for _, cp in pairs(copies) do
				if type(cp) == "table" and cp.Kind == "crystal" then
					for _, v in ipairs(cp.V) do if #vs < 30 then v.Lum = {} vs[#vs + 1] = v end end
				end
			end
			local F, ring, N, M = {}, {}, 300, 72
			for k = 1, N do
				A.HotUntil = math.max(A.HotUntil or 0, os.clock() + 2)            -- (keep them moving while it looks)
				local f = {}
				for _, v in ipairs(vs) do for L = 0, LV do f[#f + 1] = v.Lum[L] or 0 end end
				F[k] = f
				local w = {}
				for i = 0, M - 1 do local a = i / M * TAU local cc = crystalCol(A.P, c.X + c.Y * math.cos(a), 1.5, c.Z + c.Y * math.sin(a), false) w[i + 1] = 0.3 * cc.R + 0.59 * cc.G + 0.11 * cc.B end
				ring[k] = w
				task.wait(0.1)
			end
			for _, v in ipairs(vs) do v.Lum = nil end
			local D = #F[1]
			local m = {}
			for q = 1, D do local a = 0 for k = 1, N do a += F[k][q] end m[q] = a / N end
			for k = 1, N do local f, a = F[k], 0 for q = 1, D do f[q] -= m[q] a += f[q] * f[q] end a = math.sqrt(a) + 1e-9 for q = 1, D do f[q] /= a end end
			local ac = {}
			for L = 1, 150 do
				local a = 0
				for k = 1, N - L do local x, y = F[k], F[k + L] local d = 0 for q = 1, D do d += x[q] * y[q] end a += d end
				ac[L] = math.floor(1000 * a / (N - L) + 0.5) / 1000
				if L % 10 == 0 then task.wait() end
			end
			-- the ring: the best shift (with a parabola through its neighbours) between looks 1 s apart -> degrees a second
			local om = {}
			for k = 1, N - 10, 5 do
				local x, y = ring[k], ring[k + 10]
				local mx, my = 0, 0
				for i = 1, M do mx += x[i] my += y[i] end
				mx, my = mx / M, my / M
				local best, bs, sc = -math.huge, 0, {}
				for s = -20, 20 do
					local d = 0
					for i = 1, M do d += (x[i] - mx) * (y[(i - 1 + s) % M + 1] - my) end
					sc[s] = d
					if d > best then best, bs = d, s end
				end
				local fs = bs
				if sc[bs - 1] and sc[bs + 1] then
					local den = sc[bs - 1] - 2 * sc[bs] + sc[bs + 1]
					if den < 0 then fs = bs + 0.5 * (sc[bs - 1] - sc[bs + 1]) / den end
				end
				om[#om + 1] = fs * (360 / M)
			end
			local sum, abs = 0, 0
			for _, v in ipairs(om) do sum += v abs += math.abs(v) end
			workspace:SetAttribute("AuroraProbeFlowOut", game:GetService("HttpService"):JSONEncode({ ac = ac, n = #vs,
				omega_mean_deg_s = sum / math.max(1, #om), omega_abs_deg_s = abs / math.max(1, #om), omega = om }))
		end)
	end)
end

-- Studio only (v9): the crystals' painted colours themselves, 12 s at every frame (AuroraProbeCrystals = Vector3 centre)
if RunService:IsStudio() then
	workspace:GetAttributeChangedSignal("AuroraProbeCrystals"):Connect(function()
		local c = workspace:GetAttribute("AuroraProbeCrystals")
		if typeof(c) ~= "Vector3" or not A.P then return end
		task.spawn(function()
			local P, es = A.P, {}
			for _, e in ipairs(cellList) do
				if #es < 48 and e.Ready and os.clock() - e.Used < 1 and (Vector3.new(e.X, c.Y, e.Z) - c).Magnitude < 30 then
					e.P = { Position = Vector3.new(e.X, e.G + e.H / 2, e.Z) }
					es[#es + 1] = e
				end
			end
			local T, REC, OFF = {}, {}, {}
			for k = 1, #es do REC[k] = {} end
			local t0 = os.clock()
			while os.clock() - t0 < 12 do
				T[#T + 1] = os.clock() - t0
				OFF[#OFF + 1] = FLD.off[1]
				for k, e in ipairs(es) do
					local f = { Use = os.clock() - e.Used < 0.3 }
					for L = 0, LV do local q = e.Cols[L] or VOID f[#f + 1] = q end
					REC[k][#T] = f
				end
				RunService.RenderStepped:Wait()
			end
			local N = #T
			local function d(a, b) return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2) end
			local D = d(VOID, P.Highlight)
			local function mean(f) local r, g, b = 0, 0, 0 for _, q in ipairs(f) do r += q.R g += q.G b += q.B end return Color3.new(r / #f, g / #f, b / #f) end
			local function lum(q) return 0.3 * q.R + 0.59 * q.G + 0.11 * q.B end
			local function at(tt) local j = 1 for i = 1, N do if T[i] <= tt then j = i end end return j end
			local M = {}
			for k = 1, #es do M[k] = {} for i = 1, N do M[k][i] = mean(REC[k][i]) end end
			-- slowness: the fastest 1 s change of a crystal's mean colour; the median time to move one palette step (D / 4)
			local fast, cross, J1, jj = 0, {}, {}, 1
			for i = 1, N do while jj < N and T[jj + 1] <= T[i] + 1 do jj += 1 end J1[i] = jj end
			for k = 1, #es do
				if k % 8 == 0 then task.wait() end
				for i = 1, N do
					local j = J1[i]
					if T[j] - T[i] > 0.95 and REC[k][i].Use and REC[k][j].Use then fast = math.max(fast, d(M[k][i], M[k][j]) / D) end
				end
				for i = 1, N, 15 do
					if REC[k][i].Use then for j = i + 1, N do if not REC[k][j].Use then break end if d(M[k][i], M[k][j]) >= D / 4 then cross[#cross + 1] = T[j] - T[i] break end end end
				end
			end
			table.sort(cross)
			-- smoothness: the largest frame-to-frame change of any level
			local jump = 0
			for k = 1, #es do for i = 2, N do local a, b = REC[k][i - 1], REC[k][i] if a.Use and b.Use then for L = 1, #a do jump = math.max(jump, d(a[L], b[L]) / D) end end end end
			-- gradient: distinct (nearest palette stop, brightness quarter) classes inside a crystal, >= 3 passes
			local stops = { VOID }
			for u = 0, 4 do stops[#stops + 1] = P._lut[math.floor((0.08 + 0.2 * u) * 48 + 0.5)] end
			stops[#stops + 1] = P.Highlight
			local pass, tot = 0, 0
			for k = 1, #es do
				for i = 1, N, 15 do
					local seen, n = {}, 0
					for _, q in ipairs(REC[k][i]) do
						local best, bi = math.huge, 0
						for si, st in ipairs(stops) do local dd = d(q, st) if dd < best then best, bi = dd, si end end
						local key = bi * 10 + math.min(3, math.floor(lum(q) * 4))
						if not seen[key] then seen[key] = true n += 1 end
					end
					tot += 1 if n >= 3 then pass += 1 end
				end
			end
			-- continuity: correlation of crystals' mean-brightness series, neighbours (< 3 studs) vs far (> 15 studs)
			local Ls = {}
			for k = 1, #es do
				local a, s2 = {}, 0
				for i = 1, N do a[i] = lum(M[k][i]) s2 += a[i] end
				for i = 1, N do a[i] -= s2 / N end
				Ls[k] = a
			end
			local function corr(a, b) local x, y, z = 0, 0, 0 for i = 1, N do x += a[i] * b[i] y += a[i] ^ 2 z += b[i] ^ 2 end return x / math.sqrt(y * z + 1e-12) end
			local nearS, nearN, farS, farN = 0, 0, 0, 0
			for a = 1, #es do for b = a + 1, #es do
				local dist = (es[a].P.Position - es[b].P.Position).Magnitude
				if dist < 3 then nearS += corr(Ls[a], Ls[b]) nearN += 1 elseif dist > 15 then farS += corr(Ls[a], Ls[b]) farN += 1 end
			end end
			-- the drift's heading over 1 s steps: its largest wander inside any 10 s
			local hd, prev = {}, nil
			for s0 = 0, 11 do
				local i, j = at(s0), at(s0 + 1)
				local v = OFF[j] - OFF[i]
				local h = math.deg(math.atan2(v.Y, v.X))
				if prev then while h - prev > 180 do h -= 360 end while h - prev < -180 do h += 360 end end
				hd[#hd + 1] = h prev = h
			end
			local wander = 0
			for a = 1, #hd do for b = a, math.min(#hd, a + 10) do wander = math.max(wander, math.abs(hd[b] - hd[a])) end end
			workspace:SetAttribute("AuroraProbeCrystalsOut", game:GetService("HttpService"):JSONEncode({
				crystals = #es, frames = N, fastest_1s_pct_of_range = math.floor(fast * 1000 + 0.5) / 10,
				median_cross_s = cross[math.max(1, math.floor(#cross / 2))] or -1, crossings = #cross,
				max_frame_jump_pct = math.floor(jump * 1000 + 0.5) / 10, gradient_pass_pct = math.floor(1000 * pass / math.max(1, tot) + 0.5) / 10,
				corr_neighbours = nearN > 0 and math.floor(1000 * nearS / nearN + 0.5) / 1000 or -9, pairs_near = nearN,
				corr_far = farN > 0 and math.floor(1000 * farS / farN + 0.5) / 1000 or -9, pairs_far = farN,
				drift_heading_wander_10s_deg = math.floor(wander + 0.5) }))
		end)
	end)
end

return A
