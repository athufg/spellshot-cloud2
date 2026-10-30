--[[
	ScorpionKit  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ScorpionKit

	Toxin's SCORPION (2026-10-20; a RARE Element skin -- SkinCatalog's tier; first planned a tier higher, moved down when
	Witch's Brew took that slot). The forms; ScorpionFX draws them on the Default's beats through ToxinFX's skin hooks,
	gated on On().
	ONE FAMILY -- chitin plate and venom glass -- in three layers on every piece: a matte amber-black CHITIN shell, a
	translucent amber-green VENOM GLASS, and a thin venom-green GLOW kept to edges and seams only (Rare: never a
	self-lit body or core). The related modelled assets:
	  Segment    a tail plate: a rounded box, fuller at its base end so each overlaps the next (one grid mesh); its
	             joint seam a thin Neon ring. Two size tiers: the worn tail (1) and the Ultimate's sting (4.2).
	  Barb       the stinger's hooked spike (a swept, tapered, curling tube: one grid mesh). Reused thin and long as
	             Acid Rain's spines, and small as the dark barb inside the M1 gland.
	  Gland      the M1 droplet: two venom-glass halves (two grid meshes) on a glowing seam, a dark barb inside;
	             PlaceGland opens it along the seam (the crack).
	  Tail       Segment x8, a venom-glass bulb, the Barb; PlaceTail lays it along any curve (ScorpionFX poses it).
	  On(character)       its player is Toxin and SkinCatalog's ElementSkin_Toxin is "Scorpion"; Studio only: a body with
	                      StudioSkin = "Scorpion" stands in (never live). A true answer starts the build (Prepare).
	  Built               the meshes are ready (ScorpionFX draws nothing before: the Default draws)
	  Tier(density, thin) 1 / 2 / 3, the kits' shared rule
	  FlecksOn()          the Rare particle layer's own switch (chitin dust, venom droplets): ReplicatedStorage.IceMagic
	                      attribute ScorpionFlecks (absent or true: on; false: off)
	  Tex()               painted images (EditableImages): Sigil (the Ultimate's ring), Etch (corroded ground), Crack
	                      (the Corroded glow), Flake (chitin dust), Dot (droplets). White: tinted where used.
	  OnRelease(fn) / ReleaseNow()   (2026-10-26) the give-back: worn by nobody here and idle 10 s, it lets go of its meshes
	                      (MeshBudget's Optional; ReleaseNow skips the idle wait); OnRelease's fns empty the pools elsewhere
	Budget (the template, built once per client): 1,740 triangles in four meshes (measured).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")

local SkinCatalog = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))

local SK = {}
SK.Id = "Scorpion"
SK.Built = false
SK.Failed = false
SK.Tris = 0

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
-- the colours (the Element keeps its own olive gas: these are the skin's own pieces, in its key)
SK.Look = {
	Chitin = rgb(62, 43, 21),        -- (matte amber-black: kept above the grade's crush floor)
	ChitinEdge = rgb(104, 72, 32),   -- (a plate's lighter rim)
	Barb = rgb(40, 29, 15),
	Venom = rgb(172, 198, 58),       -- (the venom glass: translucent amber-green)
	VenomDeep = rgb(96, 116, 26),
	Seam = rgb(140, 175, 80),        -- (Neon: the glowing edges and seams -- nothing else glows. Toxin's own shipped
	                                 --  ToxinTuning Neon.Virulence: (150,205,40) clipped to #F8FF02 lime-yellow on screen)
	Dust = rgb(108, 82, 42),
	Etch = rgb(40, 42, 18),
}

function SK.Tier(density, thin)
	if thin then return 3 end
	if (density or 1) >= 0.9 then return 1 end
	return (density or 1) >= 0.6 and 2 or 3
end

local function folderAttr(name)
	local f = ReplicatedStorage:FindFirstChild("IceMagic")
	return f and f:GetAttribute(name)
end
function SK.FlecksOn() return folderAttr("ScorpionFlecks") ~= false end

----------------------------------------------------------------------------------------------------
-- MESHES: closed grid surfaces built once per client through MeshBudget (Essential, with retry), copied fixed-size.
----------------------------------------------------------------------------------------------------
local MeshBudget = nil
local function budget()
	if MeshBudget == nil then
		local m = script.Parent:FindFirstChild("MeshBudget")
		local ok, b = pcall(function() return m and require(m) end)
		MeshBudget = (ok and type(b) == "table") and b or false
	end
	return MeshBudget or nil
end
local function retry(make)
	for i = 1, 40 do
		local ok, m = pcall(make)
		if ok and m then return m end
		local b = budget()
		if b and i % 8 == 1 then b.MakeRoom() end
		task.wait(0.25)
	end
	error("EditableMesh budget: gave up", 0)
end

local keep = {}
local function sp(t, e) return (t < 0 and -1 or 1) * math.abs(t) ^ e end
-- a closed mesh from a surface P(u, v) (u: 0..1 end to end, v: 0..1 round; shared vertices, smooth normals from the
-- grid's own tangents, turned outward by a majority vote against the shape's centroid -- right for curled tubes too);
-- its points are centred on their bounds (a MeshPart centres its mesh). Returns { Part, Off (the bounds' centre, design
-- units), Size }
local function gridMesh(P, nu, nv)
	local pts = {}
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local sum, count = Vector3.zero, 0
	for i = 0, nu do
		pts[i] = {}
		for j = 0, nv - 1 do
			local p = P(i / nu, j / nv)
			pts[i][j] = p
			lo, hi = lo:Min(p), hi:Max(p)
			sum += p
			count += 1
		end
	end
	local centroid = sum / count
	local off = (lo + hi) / 2
	local nrm = {}
	local vote = 0
	for i = 0, nu do
		nrm[i] = {}
		for j = 0, nv - 1 do
			local du = pts[math.min(nu, i + 1)][j] - pts[math.max(0, i - 1)][j]
			local dv = pts[i][(j + 1) % nv] - pts[i][(j - 1) % nv]
			local n = du:Cross(dv)
			nrm[i][j] = n
			if n.Magnitude > 1e-7 then vote += (n:Dot(pts[i][j] - centroid) >= 0) and 1 or -1 end
		end
	end
	local flip = (vote < 0) and -1 or 1
	local em = retry(function() return AssetService:CreateEditableMesh() end)
	local okB, errB = pcall(function()
		local uv = nil
		pcall(function() uv = em:AddUV(Vector2.zero) end)
		local vid, nid, unit = {}, {}, {}
		for i = 0, nu do
			vid[i], nid[i], unit[i] = {}, {}, {}
			for j = 0, nv - 1 do
				vid[i][j] = em:AddVertex(pts[i][j] - off)
				local n = nrm[i][j] * flip
				if n.Magnitude < 1e-7 then                            -- (a pole: straight out from the centroid)
					n = pts[i][j] - centroid
					if n.Magnitude < 1e-7 then n = Vector3.yAxis end
				end
				unit[i][j] = n.Unit
				nid[i][j] = em:AddNormal(n.Unit)
			end
		end
		for i = 0, nu - 1 do
			for j = 0, nv - 1 do
				local j2 = (j + 1) % nv
				local quad = { { i, j }, { i, j2 }, { i + 1, j2 }, { i + 1, j } }
				for _, t in ipairs({ { 1, 2, 3 }, { 1, 3, 4 } }) do
					local a, b, c = quad[t[1]], quad[t[2]], quad[t[3]]
					local A, B, C = pts[a[1]][a[2]], pts[b[1]][b[2]], pts[c[1]][c[2]]
					local fn = (B - A):Cross(C - A)
					if fn.Magnitude > 1e-9 then
						local want = unit[a[1]][a[2]] + unit[b[1]][b[2]] + unit[c[1]][c[2]]
						if fn:Dot(want) < 0 then b, c = c, b end
						local f = em:AddTriangle(vid[a[1]][a[2]], vid[b[1]][b[2]], vid[c[1]][c[2]])
						em:SetFaceNormals(f, { nid[a[1]][a[2]], nid[b[1]][b[2]], nid[c[1]][c[2]] })
						if uv then pcall(em.SetFaceUVs, em, f, { uv, uv, uv }) end
						SK.Tris += 1
					end
				end
			end
		end
	end)
	if not okB then
		em:Destroy()
		error(errB, 0)
	end
	local okF, fixed = pcall(retry, function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
	end)
	em:Destroy()
	if not okF then error(fixed, 0) end
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), { CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise })
	end)
	if not ok then
		local ok2, mp2 = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(fixed)) end)
		if not ok2 then
			fixed:Destroy()
			error(mp2, 0)
		end
		mp = mp2
	end
	keep[#keep + 1] = fixed
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = true, false, false, false, false, true
	mp.Material, mp.Reflectance = Enum.Material.SmoothPlastic, 0
	return { Part = mp, Off = off, Size = hi - lo }
end

-- THE SEGMENT (design units; its length on Z, +Z toward the tail's base): a rounded box, fuller at its base end (it
-- overlaps the plate behind it), a low dorsal keel on +Y
local function segAt(u, v)
	local th, ph = -math.pi / 2 + u * math.pi, v * 2 * math.pi
	local ct = sp(math.cos(th), 0.55)
	local z = 0.5 * sp(math.sin(th), 0.55)
	local flare = 1 + 0.16 * (z / 0.5)
	local x = 0.5 * ct * sp(math.cos(ph), 0.42) * flare
	local y = 0.38 * ct * sp(math.sin(ph), 0.42) * flare
	if y > 0 then y += 0.07 * ct * math.max(0, math.sin(ph)) ^ 10 end
	return Vector3.new(x, y, z)
end
-- THE BARB (design units; its base disc at the origin, straight along +Z, then hooking round toward -Y): a swept tube
-- tapering to a point. Length ~0.9, base radius 0.16
local function barbCentre(s)
	if s <= 0.5 then return Vector3.new(0, 0, s / 0.5 * 0.45), Vector3.new(0, 0, 1) end
	local a = (s - 0.5) / 0.5 * math.rad(115)
	local R = 0.3
	return Vector3.new(0, -R * (1 - math.cos(a)), 0.45 + R * math.sin(a)), Vector3.new(0, -math.sin(a), math.cos(a))
end
local function barbAt(u, v)
	local ph = v * 2 * math.pi
	if u < 0.08 then                                              -- (the closed base)
		local r = 0.16 * (u / 0.08)
		return Vector3.new(r * math.cos(ph), r * math.sin(ph), 0)
	end
	local s = (u - 0.08) / 0.92
	local c, t = barbCentre(s)
	local r = 0.16 * (1 - s) ^ 0.85 + 0.002
	local n = Vector3.new(0, t.Z, -t.Y)                           -- (in the curl's plane, square to it)
	return c + (Vector3.xAxis * math.cos(ph) + n * math.sin(ph)) * r
end
-- THE GLAND's halves (design units; the seam at y = 0): the top a teardrop's pointed half, the bottom a rounder cup; each
-- closed across its cut (so a cracked half is never hollow)
local function glandAt(top)
	return function(u, v)
		local ph = v * 2 * math.pi
		local r, y
		if u < 0.85 then
			local th = (u / 0.85) * math.pi / 2
			local s, c = math.sin(th), math.cos(th)
			r = 0.36 * sp(s, 0.8)
			y = 0.5 * c
			if top then r *= (1 - 0.42 * c ^ 1.5) y = 0.64 * c end
		else
			r = 0.36 * (1 - (u - 0.85) / 0.15)
			y = 0
		end
		return Vector3.new(r * math.cos(ph), top and y or -y, r * math.sin(ph))
	end
end

local template = nil                    -- { Segment, Barb, GlandTop, GlandBottom = grid meshes }
local building = false
local usedAt = 0                        -- (2026-10-26) the last piece made or placed (a kit nobody wears lets go of its meshes)
local releaseHooks = {}                 -- (2026-10-26) the pools of this kit's pieces elsewhere (OnRelease): emptied with it
--- (2026-10-26) `fn()` runs when the kit lets go of its meshes (ScorpionFX: its worn tails go with them); never yields
function SK.OnRelease(fn) releaseHooks[#releaseHooks + 1] = fn end
function SK.Prepare()
	if SK.Built or building or not RunService:IsClient() then return end
	building = true
	local b = budget()
	if b then b.Essential(SK.Id, true) end
	task.spawn(function()
		SK.Tris = 0
		local ok, res = pcall(function()
			return { Segment = gridMesh(segAt, 12, 20), Barb = gridMesh(barbAt, 18, 12),
				GlandTop = gridMesh(glandAt(true), 12, 20), GlandBottom = gridMesh(glandAt(false), 12, 20) }
		end)
		if ok then
			template = res
			pcall(SK.BuildTex)
			SK.Built = true
		else
			SK.Failed = true
			warn("[ScorpionKit] the meshes did not build (" .. tostring(res) .. "); the Default draws")
			for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
			table.clear(keep)
		end
		building = false
		if b then b.Essential(SK.Id, false) end
	end)
end

----------------------------------------------------------------------------------------------------
-- PAINTED TEXTURES (EditableImages, painted once per client, white: tinted where used)
----------------------------------------------------------------------------------------------------
local function smooth01(e0, e1, x) local t = math.clamp((x - e0) / (e1 - e0), 0, 1) return t * t * (3 - 2 * t) end
local function paint(w, h, fn)
	local im = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	local buf = buffer.create(w * h * 4)
	local px = 2 / w
	for y = 0, h - 1 do
		local v = (y + 0.5) / h * 2 - 1
		for x = 0, w - 1 do
			local u = (x + 0.5) / w * 2 - 1
			local a = math.clamp(fn(u, v, px), 0, 1)
			local o = (y * w + x) * 4
			buffer.writeu8(buf, o, 255)
			buffer.writeu8(buf, o + 1, 255)
			buffer.writeu8(buf, o + 2, 255)
			buffer.writeu8(buf, o + 3, math.floor(a * 255 + 0.5))
		end
		if y % 48 == 47 then task.wait() end
	end
	im:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf)
	return im
end
local function cover(sd, px, glow, reach)
	local c = math.clamp(0.5 - sd / px, 0, 1)
	if glow and sd > 0 then c = math.max(c, glow * math.exp(-sd / reach)) end
	return c
end
local function segDist(x, y, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	local t = math.clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0, 1)
	local qx, qy = ax + dx * t - x, ay + dy * t - y
	return math.sqrt(qx * qx + qy * qy)
end
local function ringSD(u, v, r, w) return math.abs(math.sqrt(u * u + v * v) - r) - w end

local TEX = nil
function SK.Tex() return TEX or nil end
function SK.BuildTex()
	if TEX ~= nil or not RunService:IsClient() then return end
	TEX = false
	local ok, res = pcall(function()
		local t = {}
		-- THE SIGIL: an outer double ring, a ring of twelve plates (the tail's segments), eight barbs hooking inward, an inner
		-- ring and a four-barbed centre -- drawn as glowing lines only
		t.Sigil = paint(256, 256, function(u, v, px)
			local r, th = math.sqrt(u * u + v * v), math.atan2(v, u)
			local sd = math.min(ringSD(u, v, 0.94, 0.016), ringSD(u, v, 0.875, 0.007), ringSD(u, v, 0.42, 0.012))
			-- the plates: a ring broken every 30 degrees
			local seg = (th / (2 * math.pi) * 12) % 1
			if seg > 0.06 and seg < 0.94 then sd = math.min(sd, ringSD(u, v, 0.72, 0.03)) end
			-- eight barbs: a hooked spike from the outer ring inward
			for i = 0, 7 do
				local a = i / 8 * 2 * math.pi + math.pi / 8
				local ca, sa = math.cos(a), math.sin(a)
				local bx, by = ca * 0.86, sa * 0.86
				local tx, ty = ca * 0.6 + -sa * 0.06, sa * 0.6 + ca * 0.06
				local d = segDist(u, v, bx, by, tx, ty)
				local k = math.clamp(((u - bx) * (tx - bx) + (v - by) * (ty - by)) / 0.0712, 0, 1)
				sd = math.min(sd, d - 0.03 * (1 - k) - 0.004)
			end
			-- the centre: four barbs out from a small ring
			sd = math.min(sd, ringSD(u, v, 0.12, 0.012))
			for i = 0, 3 do
				local a = i / 4 * 2 * math.pi
				local ca, sa = math.cos(a), math.sin(a)
				local d = segDist(u, v, ca * 0.14, sa * 0.14, ca * 0.34 - sa * 0.05, sa * 0.34 + ca * 0.05)
				sd = math.min(sd, d - 0.018)
			end
			return cover(sd, px, 0.28, 0.025) * (1 - smooth01(0.97, 1.0, r))
		end)
		-- THE ETCH: corroded ground -- pitted, blotchy, laced with fine cracks, fading out at its rim
		t.Etch = paint(256, 256, function(u, v)
			local r = math.sqrt(u * u + v * v)
			local n1 = math.noise(u * 4.1, v * 4.1, 0.37)
			local n2 = math.noise(u * 11.3, v * 11.3, 1.91)
			local pits = smooth01(-0.05, 0.25, n1 + 0.45 * n2)
			local crack = math.exp(-math.abs(math.noise(u * 6.7, v * 6.7, 3.3)) / 0.025)
			return math.max(pits * 0.85, crack * 0.9) * (1 - smooth01(0.55, 1.0, r))
		end)
		-- THE CRACK: a network of thin glowing cracks (the Corroded glow on a struck body)
		t.Crack = paint(128, 128, function(u, v)
			local a = math.exp(-math.abs(math.noise(u * 3.2, v * 3.2, 7.7)) / 0.03)
			local b = math.exp(-math.abs(math.noise(u * 6.1, v * 6.1, 2.2)) / 0.025) * 0.6
			return math.max(a, b)
		end)
		-- THE FLAKE: a chip of chitin (an irregular five-sided shard)
		t.Flake = paint(32, 32, function(u, v, px)
			local pts = { { 0.0, -0.9 }, { 0.75, -0.25 }, { 0.5, 0.75 }, { -0.35, 0.85 }, { -0.85, 0.05 } }
			local d, inside = math.huge, false
			for i = 1, #pts do
				local a, b = pts[i], pts[i % #pts + 1]
				d = math.min(d, segDist(u, v, a[1], a[2], b[1], b[2]))
				if ((a[2] > v) ~= (b[2] > v)) and (u < (b[1] - a[1]) * (v - a[2]) / (b[2] - a[2]) + a[1]) then inside = not inside end
			end
			return cover(inside and -d or d, px)
		end)
		t.Dot = paint(32, 32, function(u, v) return 1 - smooth01(0.15, 1, math.sqrt(u * u + v * v)) end)
		local out = { Images = t }
		for k2, im in pairs(t) do out[k2] = Content.fromObject(im) end
		return out
	end)
	if ok then TEX = res else warn("[ScorpionKit] painted textures failed (" .. tostring(res) .. ")") end
end

-- (2026-10-26) THE SHOWCASE CONVENTION: a client-only model no player owns, with the attribute ShowcaseSkin = "<SkinId>"
-- (the Loadout Altar's dummies, the pedestal's held M1), wears that skin -- live and in Studio. Every such model asked
-- about (On) or seen entering the workspace (below) is kept here wherever it sits (the showcases parent theirs in their
-- own folders), so the build starts for it and ScorpionFX's manager finds it until it leaves the workspace.
local showcase = {}
--- whether `m` is a showcase stand-in wearing Scorpion (one wearing any skin is kept)
function SK.Showcase(m)
	local id = typeof(m) == "Instance" and m:GetAttribute("ShowcaseSkin")
	if type(id) ~= "string" or Players:GetPlayerFromCharacter(m) then return false end
	-- (2026-10-26) pruned on insert (strong keys): a stand-in that left the workspace goes when the next new one is kept
	if not showcase[m] then
		for k in pairs(showcase) do if not k:IsDescendantOf(workspace) then showcase[k] = nil end end
		showcase[m] = true
	end
	return id == SK.Id
end
--- the showcase stand-ins in the workspace wearing Scorpion now
function SK.Showcased()
	local out = {}
	for m in pairs(showcase) do
		if not m:IsDescendantOf(workspace) then
			showcase[m] = nil
		elseif m:GetAttribute("ShowcaseSkin") == SK.Id then
			out[#out + 1] = m
		end
	end
	return out
end

function SK.On(character)
	if typeof(character) ~= "Instance" then return false end
	local on
	if RunService:IsStudio() and character:GetAttribute("StudioSkin") == SK.Id then
		on = true
	elseif SK.Showcase(character) then                             -- (2026-10-26) a showcase stand-in, live too
		on = true
	else
		local plr = Players:GetPlayerFromCharacter(character)
		on = plr ~= nil and plr:GetAttribute("Element") == "Toxin"           -- (a borrowed Toxin Technique: the Default)
			and SkinCatalog.ElementSkin(plr, "Toxin") == SK.Id
	end
	if on and not SK.Failed then SK.Prepare() end
	return on
end
-- (2026-10-26) a showcase stand-in (ShowcaseSkin, live and in Studio) starts the build too, wherever in the workspace it is
if RunService:IsClient() then
	workspace.DescendantAdded:Connect(function(m)
		if m:IsA("Model") then task.defer(function() if m.Parent and SK.Showcase(m) then SK.On(m) end end) end
	end)
end

-- (2026-10-26) THE GIVE-BACK (FrostbladeKit's, for MeshBudget): a built kit nobody here wears right now -- no player is
-- Toxin in this skin (On's own rule; a wearer between bodies, dead or respawning, counts too), no Studio stand-in where
-- ScorpionFX's manager looks, no showcase stand-in -- and that made or placed no piece for 10 s lets go of every mesh (the
-- four templates and their fixed meshes), so another skin or wrap that someone does wear can have the budget. Built goes
-- false first, so whatever asks from now on draws the Default; ScorpionFX drops its worn tails with it (OnRelease). The
-- next On() that is true builds it again (Prepare). The painted textures (EditableImages, not meshes) stay.
local function wornByPlayer(plr)
	if plr.Character and SK.On(plr.Character) then return true end
	local ok, id = pcall(SkinCatalog.ElementSkin, plr, "Toxin")
	return ok and id == SK.Id and plr:GetAttribute("Element") == "Toxin"
end
local function releaseKit()
	if building or not SK.Built or os.clock() - usedAt < 10 then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if wornByPlayer(plr) then return end
	end
	if RunService:IsStudio() then
		local tg = workspace:FindFirstChild("TrainingGround")
		local dm = tg and tg:FindFirstChild("Dummies")
		for _, list in ipairs({ workspace:GetChildren(), dm and dm:GetChildren() or {} }) do
			for _, m in ipairs(list) do
				if m:IsA("Model") and m:GetAttribute("StudioSkin") == SK.Id then return end
			end
		end
	end
	if #SK.Showcased() > 0 then return end
	SK.Built = false
	for _, fn in ipairs(releaseHooks) do pcall(fn) end
	for _, t in pairs(template or {}) do pcall(function() t.Part:Destroy() end) end
	for _, m in ipairs(keep) do pcall(function() m:Destroy() end) end
	template = nil
	table.clear(keep)
end
--- (2026-10-26) the same let-go without the 10 s idle wait: the Altar showcase calls it on a swap, once the piece that
--- showed this skin is gone (still nothing if a player wears it, a stand-in still shows it, or it is building)
function SK.ReleaseNow()
	usedAt = 0
	releaseKit()
end
if RunService:IsClient() then
	task.spawn(function()
		-- (registered once MeshBudget is there: the lazy getter would otherwise remember it missing for good)
		if script.Parent:WaitForChild("MeshBudget", 10) then
			local b = budget()
			if b then b.Optional(releaseKit) end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- PIECES. Every piece's parts are anchored and placed by a Place function (the caller moves them each frame).
----------------------------------------------------------------------------------------------------
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end
local function sphere(p) local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Sphere m.Parent = p return m end
local function cylinder(p) local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Cylinder m.Parent = p return m end
local function meshCopy(t, name, parent)
	local q = t.Part:Clone()
	q.Name = name
	q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow, q.Massless = true, false, false, false, false, true
	q.Parent = parent
	return q
end
-- a glowing seam ring (a thin Neon disc: only its rim shows, round the joint it sits in)
local function seamRing(parent)
	local s = part({ Name = "Seam", Material = Enum.Material.Neon, Color = SK.Look.Seam, Size = Vector3.new(0.03, 0.3, 0.3) }, parent)
	cylinder(s)
	return s
end

--- THE TAIL at `scale` (1: the worn tail, ~4.3 studs laid out): eight chitin plates on glowing joint seams, a venom-glass
--- bulb and the hooked barb. { Model, Segs = { { Part, Seam, W } }, Bulb, BulbSeam, Barb, Parts, S }; nil until built.
local SEG_W = { 1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.71, 0.67 }
SK.TailWidth = 0.56                                               -- (the base plate's width at scale 1, studs)
SK.Overlap = 1.06                                                 -- (each plate's length over its share: a waist shows at each joint)
function SK.Tail(scale, parent)
	if not (template and template.Segment) then return nil end
	usedAt = os.clock()                                           -- (2026-10-26)
	local L = SK.Look
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "ScorpionTail"
	local segs, parts = {}, {}
	for i, w in ipairs(SEG_W) do
		local seg = meshCopy(template.Segment, "Segment", model)
		seg.Color, seg.Reflectance = (i % 2 == 0) and L.Chitin or L.Chitin:Lerp(L.ChitinEdge, 0.18), 0.03
		local seam = seamRing(model)
		segs[i] = { Part = seg, Seam = seam, W = w }
		table.insert(parts, seg)
		table.insert(parts, seam)
	end
	local bulb = part({ Name = "Bulb", Color = L.Venom, Transparency = 0.22, Reflectance = 0.12 }, model)
	sphere(bulb)
	local bulbSeam = seamRing(model)
	local barb = meshCopy(template.Barb, "Barb", model)
	barb.Color = L.Barb
	table.insert(parts, bulb)
	table.insert(parts, bulbSeam)
	table.insert(parts, barb)
	if parent then model.Parent = parent end
	-- (2026-10-26) T: the templates it was cut from (their Off / Size), kept with it -- a tail still drawn when the kit
	-- lets go places on (its meshes gone) instead of erroring on a nil template
	return { Model = model, Segs = segs, Bulb = bulb, BulbSeam = bulbSeam, Barb = barb, Parts = parts, S = s, T = template }
end

--- Lays `tail` along `curve` (s 0..1 -> a world point, base to tip): the plates share the first 78% of its length
--- (each stretched to its share, a little overlap), then the bulb and the barb. `side` (a world vector, roughly square
--- to the curve's bend) sets the plates' roll: their keel faces side x tangent (the outside of an arch). Writes nothing
--- itself: returns the parts and their CFrames, for one workspace:BulkMoveTo.
local SAMPLES = 40
function SK.PlaceTail(tail, curve, side, outParts, outCFs)
	usedAt = os.clock()                                           -- (2026-10-26)
	local tpl = tail.T or template                                -- (2026-10-26) its own templates (Tail)
	local s = tail.S
	local pts, cum = {}, {}
	cum[0] = 0
	for i = 0, SAMPLES do pts[i] = curve(i / SAMPLES) end
	for i = 1, SAMPLES do cum[i] = cum[i - 1] + (pts[i] - pts[i - 1]).Magnitude end
	local total = math.max(1e-3, cum[SAMPLES])
	local function at(f)                                          -- (point and tangent at arc fraction f)
		local d = math.clamp(f, 0, 1) * total
		local i = 1
		while i < SAMPLES and cum[i] < d do i += 1 end
		local a, b = pts[i - 1], pts[i]
		local seg = math.max(1e-6, cum[i] - cum[i - 1])
		local k = math.clamp((d - cum[i - 1]) / seg, 0, 1)
		local tan = b - a
		return a:Lerp(b, k), (tan.Magnitude > 1e-6) and tan.Unit or Vector3.yAxis
	end
	local function frame(pos, tan)
		local up = side:Cross(tan)
		if up.Magnitude < 1e-3 then up = Vector3.yAxis:Cross(tan) end
		if up.Magnitude < 1e-3 then up = Vector3.xAxis end
		return CFrame.lookAt(pos, pos + tan, up.Unit)               -- (-Z along the tail, toward its tip; +Y the keel)
	end
	local n = #tail.Segs
	local plates = 0.78
	local TS = tpl.Segment
	local w0 = SK.TailWidth * s
	for i, sg in ipairs(tail.Segs) do
		local f0, f1 = (i - 1) / n * plates, i / n * plates
		local pos, tan = at((f0 + f1) / 2)
		local len = (f1 - f0) * total
		local wid = w0 * sg.W
		local sz = Vector3.new(wid, wid * TS.Size.Y / TS.Size.X, len * SK.Overlap)
		sg.Part.Size = sz
		outParts[#outParts + 1], outCFs[#outCFs + 1] = sg.Part, frame(pos, tan)
		local jp, jt = at(f0)                                    -- (the joint's waist: the seam glows round it)
		local d = wid * 0.84
		sg.Seam.Size = Vector3.new(0.06 * s, d, d * 0.8)
		outParts[#outParts + 1], outCFs[#outCFs + 1] = sg.Seam, CFrame.fromMatrix(jp, jt, side:Cross(jt).Magnitude > 1e-3 and side:Cross(jt).Unit or Vector3.yAxis)
	end
	-- the bulb (venom glass), its seam, then the barb hooking out of it
	local bpos, btan = at(plates + 0.055)
	local bw = w0 * 0.78
	tail.Bulb.Size = Vector3.new(bw, bw * 0.86, (0.1 * total) * 1.05)
	outParts[#outParts + 1], outCFs[#outCFs + 1] = tail.Bulb, frame(bpos, btan)
	local spos, stan = at(plates + 0.105)
	tail.BulbSeam.Size = Vector3.new(0.03 * s, bw * 0.62, bw * 0.55)
	outParts[#outParts + 1], outCFs[#outCFs + 1] = tail.BulbSeam,
		CFrame.fromMatrix(spos, stan, side:Cross(stan).Magnitude > 1e-3 and side:Cross(stan).Unit or Vector3.yAxis)
	local TB = tpl.Barb
	local blen = (1 - plates - 0.1) * total                      -- (the barb's share of the curve)
	local k = math.max(0.05, blen / 0.85)                         -- (its design length is ~0.85)
	tail.Barb.Size = TB.Size * k * Vector3.new(bw / (0.32 * k) * 0.55, bw / (0.32 * k) * 0.55, 1)
	local base = frame(spos, stan) * CFrame.Angles(0, math.pi, 0)  -- (the barb's design +Z along the tail, its hook toward -Y: the belly)
	local sc = tail.Barb.Size / TB.Size
	outParts[#outParts + 1], outCFs[#outCFs + 1] = tail.Barb, base * CFrame.new(TB.Off * sc)
	return total
end

--- Where a placed tail's barb point lands: `barbCF` is the barb's CFrame as PlaceTail laid it (its last part). Returns the
--- world point of the tip (the end of barbCentre's curl, scaled with the barb).
local BARB_TIP = barbCentre(1)
function SK.BarbTip(tail, barbCF)
	local TB = (tail.T or template).Barb                         -- (2026-10-26) its own templates (Tail)
	return barbCF * ((BARB_TIP - TB.Off) * (tail.Barb.Size / TB.Size))
end

--- A lone BARB (Acid Rain's spine: thin and long; the gland's dark heart: small). { Part, Seam? }
function SK.Barb(length, thick, parent, withSeam)
	if not (template and template.Barb) then return nil end
	usedAt = os.clock()                                           -- (2026-10-26)
	local TB = template.Barb
	local b = meshCopy(TB, "Barb", parent)
	b.Color = SK.Look.Barb
	local k = length / 0.85
	b.Size = TB.Size * k * Vector3.new(thick, thick, 1)
	local seam = withSeam and seamRing(parent) or nil
	-- (2026-10-26) T: its template (Off / Size), kept with it -- a spine still falling when the kit lets go places on
	return { Part = b, Seam = seam, K = Vector3.new(k * thick, k * thick, k), T = TB }
end
--- Where a lone barb's part goes for its base at `baseCF` (+Z out along the barb, its hook toward -Y).
function SK.BarbCF(barb, baseCF)
	usedAt = os.clock()                                           -- (2026-10-26)
	return baseCF * CFrame.new((barb.T or template.Barb).Off * barb.K)
end

--- THE GLAND (the M1 droplet): two venom-glass halves on a glowing seam, a small dark barb inside. { Model, Top, Bottom,
--- Seam, Heart, Parts }; nil until built.
function SK.Gland(parent)
	if not (template and template.GlandTop) then return nil end
	usedAt = os.clock()                                           -- (2026-10-26)
	local L = SK.Look
	local model = Instance.new("Model")
	model.Name = "ScorpionGland"
	local top = meshCopy(template.GlandTop, "Top", model)
	local bottom = meshCopy(template.GlandBottom, "Bottom", model)
	for _, h in ipairs({ top, bottom }) do h.Color, h.Transparency, h.Reflectance = L.Venom, 0.3, 0.14 end
	local seam = seamRing(model)
	local heart = SK.Barb(0.5, 1.0, model, false)
	if parent then model.Parent = parent end
	-- (2026-10-26) T: the templates it was cut from, kept with it (a gland still resting when the kit lets go places on)
	return { Model = model, Top = top, Bottom = bottom, Seam = seam, Heart = heart.Part, HeartBarb = heart,
		Parts = { top, bottom, seam, heart.Part }, T = template }
end
--- Lays the gland at `cf` (its long axis on cf's Y, the pointed half up), `len` long; `open` 0..1 parts the halves along
--- the seam (the crack), `fade` 0..1 fades it. Returns parts and CFrames for a BulkMoveTo.
function SK.PlaceGland(g, cf, len, open, fade, outParts, outCFs)
	usedAt = os.clock()                                           -- (2026-10-26)
	local tpl = g.T or template                                   -- (2026-10-26) its own templates (Gland)
	local k = len / 1.14                                          -- (its design length: 0.64 + 0.5)
	local TT, TBm = tpl.GlandTop, tpl.GlandBottom
	g.Top.Size, g.Bottom.Size = TT.Size * k, TBm.Size * k
	local hinge = 0.36 * k
	local o = math.clamp(open or 0, 0, 1)
	local topCF = cf * CFrame.new(hinge, 0, 0) * CFrame.Angles(0, 0, math.rad(100) * o) * CFrame.new(-hinge, 0, 0)
		* CFrame.new(0, 0.18 * k * o, 0)
	local botCF = cf * CFrame.new(-hinge, 0, 0) * CFrame.Angles(0, 0, math.rad(-38) * o) * CFrame.new(hinge, 0, 0)
	outParts[#outParts + 1], outCFs[#outCFs + 1] = g.Top, topCF * CFrame.new(TT.Off * k)
	outParts[#outParts + 1], outCFs[#outCFs + 1] = g.Bottom, botCF * CFrame.new(TBm.Off * k)
	g.Seam.Size = Vector3.new(0.03 * k, 0.75 * k, 0.75 * k)
	outParts[#outParts + 1], outCFs[#outCFs + 1] = g.Seam, cf * CFrame.Angles(0, 0, math.pi / 2)
	local hb = g.HeartBarb
	local hk = len * 0.45 / 0.85
	hb.K = Vector3.new(hk, hk, hk)
	g.Heart.Size = tpl.Barb.Size * hk
	outParts[#outParts + 1], outCFs[#outCFs + 1] = g.Heart,
		SK.BarbCF(hb, cf * CFrame.new(0, -0.18 * k, 0) * CFrame.Angles(-math.pi / 2, 0, 0))   -- (its +Z up the gland)
	local f = math.clamp(fade or 0, 0, 1)
	g.Top.Transparency, g.Bottom.Transparency = 0.3 + 0.7 * f, 0.3 + 0.7 * f
	g.Seam.Transparency = math.max(o, f)
	g.Heart.Transparency = f
end

--- A venom-glass PELLET (Acid Rain's shot) with its seam: { Part, Seam }.
function SK.Pellet(parent)
	local p = part({ Name = "Pellet", Color = SK.Look.Venom, Transparency = 0.2, Reflectance = 0.12, Size = Vector3.new(0.32, 0.32, 0.44) }, parent)
	sphere(p)
	local s = seamRing(parent)
	s.Size = Vector3.new(0.03, 0.29, 0.29)
	return { Part = p, Seam = s }
end

return SK
